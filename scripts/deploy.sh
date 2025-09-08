#!/bin/bash
set -euo pipefail

mkdir -p /opt/ryedr
IMAGE_URI=$(cat /opt/ryedr/image_uri.txt)
APP_NAME=ryedr
CONTAINER_NAME=ryedr-app

echo "Deploying $IMAGE_URI"
docker pull "$IMAGE_URI"

if docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
  docker rm -f "$CONTAINER_NAME" || true
fi

# Bind EFS if mounted
MOUNT_DIR="/mnt/efs"
EFS_ARGS=()
if mountpoint -q "$MOUNT_DIR"; then
  EFS_ARGS=( -v "$MOUNT_DIR:/data" )
fi

docker run -d --restart=always \
  --name "$CONTAINER_NAME" \
  -p 80:80 \
  "${EFS_ARGS[@]}" \
  "$IMAGE_URI"

echo "Deployment done"

