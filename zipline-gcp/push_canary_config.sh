#!/bin/bash
set -e

## For Internal Use Only

gcloud storage cp ./canary_backend.tf gs://zipline-canary-vars/canary_backend.tf
gcloud storage cp ./canary_divergences.tf gs://zipline-canary-vars/canary_divergences.tf
gcloud storage cp  ./terraform.tfvars gs://zipline-canary-vars/terraform.tfvars
gcloud storage cp ./.terraform.lock.hcl gs://zipline-canary-vars/.terraform.lock.hcl