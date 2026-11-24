#!/usr/bin/env bash
# Siembra cargas multiparte incompletas en el bucket del laboratorio.
# Nunca se completan: ocupan espacio, cobran y no aparecen en la lista de objetos.
set -euo pipefail
BUCKET=$(terraform -chdir="$(dirname "$0")/../terraform" output -raw bucket)
for i in 1 2 3; do
  aws s3api create-multipart-upload --bucket "$BUCKET" --key "uploads/video-$i.mp4" --query UploadId --output text
done
echo "Listo: 3 cargas multiparte incompletas en $BUCKET"
