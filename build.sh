#!/bin/bash

if [[ -z "$IMAGE_TAG" ]]; then
  IMAGE_TAG=$(git rev-parse HEAD)
fi

docker build \
  --platform linux/amd64 \
  -t ghcr.io/alexhall/equinix-metal-demo:latest \
  -t ghcr.io/alexhall/equinix-metal-demo:$IMAGE_TAG \
  app

docker push ghcr.io/alexhall/equinix-metal-demo:latest
docker push ghcr.io/alexhall/equinix-metal-demo:$IMAGE_TAG
