#!/bin/sh

MD="curl -s http://169.254.169.254/latest/meta-data/"
AWS_REGION=`$MD/placement/availability-zone | head -c -1`
AVAILABILITY_ZONE=`$MD/placement/availability-zone`
INSTANCE_ID=`${MD}/instance-id`
INSTANCE_TYPE=`${MD}/instance-type`
SECURITY_GROUPS=`${MD}/security-groups | tr '\n' ','`

# It appears it takes a while for the hostname to incorporate the node name.
while [ "x$NODE" = "x" ] || [ "$NODE" = "null" ]; do
  sleep 1
  HOSTNAME=`hostname`
  echo "[$(date)] Hostname: $HOSTNAME"
  NODE=`curl  -s -f \
        --cert   /etc/kubernetes/ssl/worker.pem \
        --key    /etc/kubernetes/ssl/worker-key.pem \
        --cacert /etc/kubernetes/ssl/ca.pem  \
        https://${KUBERNETES_SERVICE_HOST}/api/v1/namespaces/kube-system/pods/${HOSTNAME} | jq -r '.spec.nodeName'
  `
done

echo "[$(date)] Node: $NODE"

INSTANCE_DETAILS=`aws --region "$AWS_REGION" ec2 describe-instances --instance-id "$INSTANCE_ID"`

SUBNET_ID=`echo $INSTANCE_DETAILS | jq -r '.Reservations[].Instances[].NetworkInterfaces[].SubnetId'`
INSTANCE_PROFILE_ARN=`echo $INSTANCE_DETAILS | jq -r '.Reservations[].Instances[].IamInstanceProfile.Arn'`
INSTANCE_PROFILE_ID=`echo $INSTANCE_DETAILS | jq -r '.Reservations[].Instances[].IamInstanceProfile.Id'`
# TAGS_LABELS=`echo $INSTANCE_DETAILS | jq -r '.Reservations[].Instances[].Tags | map("\"aws/tags/\(.Key)\":\"\(.Value)\"") | join(",")'`

cat >> labels.json <<EOF
{
  "metadata": {
    "labels": {
      "aws/region":               "${AVAILABILITY_ZONE}",
      "aws/az":                   "${AVAILABILITY_ZONE}",
      "aws/instance/id":          "${INSTANCE_ID}",
      "aws/instance/type":        "${INSTANCE_TYPE}",
      "aws/subnet/id":            "${SUBNET_ID}",
      "aws/instance_profile/arn": "${INSTANCE_PROFILE_ARN}",
      "aws/instance_profile/id":  "${INSTANCE_PROFILE_ID}"
    },
    "annotations": {
      "aws.node.kubernetes.io/sgs":  "${SECURITY_GROUPS}"
    } 
  } 
}
EOF

cat labels.json

curl -v -s \
      --cert   /etc/kubernetes/ssl/worker.pem \
      --key    /etc/kubernetes/ssl/worker-key.pem \
      --cacert /etc/kubernetes/ssl/ca.pem  \
      --request PATCH \
      -H "Content-Type: application/strategic-merge-patch+json" \
      -d @labels.json \
      https://${KUBERNETES_SERVICE_HOST}/api/v1/nodes/${NODE}

vi