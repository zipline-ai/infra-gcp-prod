#!/bin/bash
set -euo pipefail

## For Internal Use Only

cd "$(dirname "$0")"

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

declare -a FILES=(
  "canary_backend.tf"
  "canary_divergences.tf"
  "terraform.tfvars"
)

DIFFS_FOUND=0

for FILE in "${FILES[@]}"; do
  LOCAL_FILE="./$FILE"
  CLOUD_FILE="gs://zipline-canary-vars/$FILE"
  CLOUD_COPY="$TMP_DIR/$FILE"

  echo "Comparing $LOCAL_FILE to $CLOUD_FILE"

  if [[ ! -f "$LOCAL_FILE" ]]; then
    echo "Local file not found: $LOCAL_FILE"
    DIFFS_FOUND=1
    echo
    continue
  fi

  gcloud storage cp "$CLOUD_FILE" "$CLOUD_COPY"

  if ! diff -u --label "$LOCAL_FILE" --label "$CLOUD_FILE" "$LOCAL_FILE" "$CLOUD_COPY"; then
    DIFFS_FOUND=1
  else
    echo "No differences found."
  fi

  echo
done

exit "$DIFFS_FOUND"
