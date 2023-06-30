#!/bin/bash

if [[ -z "$IMAGE_TAG" ]]; then
  IMAGE_TAG=$(git rev-parse LATEST)
fi

if [[ -z "$EQX_METAL_SERVER_IP" ]]; then
  echo "Must set EQX_METAL_SERVER_IP env-var"
  exit 1
fi

if [[ -z "$DEPLOY_SSH_PRIVATE_KEY" ]]; then
  echo "Must set DEPLOY_SSH_PRIVATE_KEY env-var"
  exit 1
fi

TEMP_SSH_FILE=/tmp/id_deploy

echo "$DEPLOY_SSH_PRIVATE_KEY" > $TEMP_SSH_FILE
chmod 600 $TEMP_SSH_FILE

trap "rm -f $TEMP_SSH_FILE" 0

ssh -i $TEMP_SSH_FILE -T root@$EQX_METAL_SERVER_IP <<EOF
docker pull ghcr.io/alexhall/equinix-metal-demo:$IMAGE_TAG
IMAGES=\$(docker ps -aq)
if [[ -n "\$IMAGES" ]]; then docker rm -f \$IMAGES; fi
docker run -dit --name equinix-metal-demo-app -p 80:80 ghcr.io/alexhall/equinix-metal-demo:$IMAGE_TAG
EOF
