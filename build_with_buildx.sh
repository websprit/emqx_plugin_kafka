#!/bin/bash
set -e

OUT_DIR="${OUT_DIR:-dist}"
PLATFORM="${PLATFORM:-linux/amd64}"

mkdir -p "$OUT_DIR"

docker buildx build \
  --platform "$PLATFORM" \
  --target artifact \
  --output "type=local,dest=$OUT_DIR" \
  .

echo "Build complete. Exported artifacts:"
ls -l "$OUT_DIR"/*.tar.gz
