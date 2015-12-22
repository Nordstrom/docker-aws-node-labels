#!/bin/sh

MD="curl -s http://169.254.169.254/latest/meta-data/"
AWS_REGION=`$MD/placement/availability-zone | head -c -1`
AVAILABILITY_ZONE=`$MD/placement/availability-zone`
INSTANCE_ID=`${MD}/instance-id`
INSTANCE_TYPE=`${MD}/instance-type`
SECURITY_GROUPS=`${MD}/security-groups | tr '\n' ','`

JQ_VERSION=`jq --version`
echo "[$(date)] jq-version: $JQ_VERSION"


# It appears it takes a while for the hostname to incorporate the node name.
TIMEOUT=300 # In seconds
COUNTER=0
while [ "x$NODE" = "x" ] || [ "$NODE" = "null" ]; do
  HOSTNAME=`hostname`
  echo "[$(date)] Hostname: $HOSTNAME"
  NODE=`curl  -s -f \
        --cert   /etc/kubernetes/ssl/worker.pem \
        --key    /etc/kubernetes/ssl/worker-key.pem \
        --cacert /etc/kubernetes/ssl/ca.pem  \
        https://${KUBERNETES_SERVICE_HOST}/api/v1/namespaces/kube-system/pods/${HOSTNAME} | jq -r '.spec.nodeName'
  `
  echo "[$(date)] Node: $NODE"

  sleep 1
  COUNTER=$((COUNTER + 1))

  if [ $COUNTER -ge $TIMEOUT ]; then
    echo "[$(date)] Failed to get Node!"
    exit 1
  fi
done

echo "[$(date)] Node: $NODE"

INSTANCE_DETAILS=`aws --region "$AWS_REGION" ec2 describe-instances --instance-id "$INSTANCE_ID"`

SUBNET_ID=`echo $INSTANCE_DETAILS | jq -r '.Reservations[].Instances[].NetworkInterfaces[].SubnetId'`
INSTANCE_PROFILE_ARN=`echo $INSTANCE_DETAILS | jq -r '.Reservations[].Instances[].IamInstanceProfile.Arn'`
INSTANCE_PROFILE_ID=`echo $INSTANCE_DETAILS | jq -r '.Reservations[].Instances[].IamInstanceProfile.Id'`
TAGS_LABELS=`echo $INSTANCE_DETAILS | jq -r '.Reservations[].Instances[].Tags | map("\"aws.amazon.com/tags-\(.Key)\"%\"\(.Value)\"") | join(",\n")' | tr ":" "-" | tr "%" ":"`

curl  -s \
      --cert   /etc/kubernetes/ssl/worker.pem \
      --key    /etc/kubernetes/ssl/worker-key.pem \
      --cacert /etc/kubernetes/ssl/ca.pem  \
      --request PATCH \
      -H "Content-Type: application/strategic-merge-patch+json" \
      -d @- \
      https://${KUBERNETES_SERVICE_HOST}/api/v1/nodes/${NODE} <<EOF
{
  "metadata": {
    "labels": {
      "aws.amazon.com/region":               "${AVAILABILITY_ZONE}",
      "aws.amazon.com/az":                   "${AVAILABILITY_ZONE}",
      "aws.amazon.com/instance-id":          "${INSTANCE_ID}",
      "aws.amazon.com/instance-type":        "${INSTANCE_TYPE}",
      "aws.amazon.com/subnet-id":            "${SUBNET_ID}"
    },
    "annotations": {
      "aws.node.kubernetes.io/sgs":  "${SECURITY_GROUPS}"
    } 
  } 
}
EOF
