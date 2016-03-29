#!/bin/sh

if [ "$1" = "-t" ]; then
  # timeout after passed time and let the pod restart.
  # There is a chicken and egg issue with running this on the
  # api servers.  This forces the pod to die if this pod beats the
  # api servers from coming up.  Second run succeeds.

  echo "[$(date)] $0 starting with timeout of $2"

  timeout $2 $0 notimeout
else
  echo "[$(date)] $0 started without timeout"

  MD="curl -s http://169.254.169.254/latest/meta-data/"
  INSTANCE_ID=`${MD}/instance-id`

  JQ_VERSION=`jq --version`
  echo "[$(date)] jq-version: $JQ_VERSION"

  # Works only as a kubernetes injected Pod
  TOKEN=`cat /var/run/secrets/kubernetes.io/serviceaccount/token`

  # It appears it takes a while for the hostname to incorporate the node name.
  while [ "x$NODE" = "x" ] || [ "$NODE" = "null" ]; do
    HOSTNAME=`hostname`
    echo "[$(date)] Hostname: $HOSTNAME"
    NODE=`curl  -s -f \
          --cacert /var/run/secrets/kubernetes.io/serviceaccount/ca.crt  \
          -H "Authorization: Bearer $TOKEN" \
          https://${KUBERNETES_SERVICE_HOST}/api/v1/namespaces/kube-system/pods/${HOSTNAME} | jq -r '.spec.nodeName'
    `
    echo "[$(date)] Node: $NODE"

    sleep 1
  done

  echo "[$(date)] Node: $NODE"

  INSTANCE_DETAILS=`aws --region "$AWS_REGION" ec2 describe-instances --instance-id "$INSTANCE_ID"`

  SUBNET_ID=`echo $INSTANCE_DETAILS | jq -r '.Reservations[].Instances[].NetworkInterfaces[].SubnetId'`

  curl  -s \
        --cacert /var/run/secrets/kubernetes.io/serviceaccount/ca.crt  \
        --request PATCH \
        -H "Authorization: Bearer $TOKEN" \
        -H "Content-Type: application/strategic-merge-patch+json" \
        -d @- \
        https://${KUBERNETES_SERVICE_HOST}/api/v1/nodes/${NODE} <<EOF
{
  "metadata": {
    "labels": {
      "aws.amazon.com/instance-id": "${INSTANCE_ID}",
      "aws.amazon.com/subnet-id": "${SUBNET_ID}"
    }
  } 
}
EOF
fi
