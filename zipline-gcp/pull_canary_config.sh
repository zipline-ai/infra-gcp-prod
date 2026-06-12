#!/bin/bash
set -e

## For Internal Use Only

rm -f canary_backend.tf
rm -f ci_backend.tf
rm -f demo_backend.tf
rm -f canary_divergences.tf
rm -f ci_divergences.tf
rm -f demo_divergences.tf
rm -f .terraform.lock.hcl
rm -f terraform.tfvars
rm -rf .terraform

gcloud storage cp gs://zipline-canary-vars/terraform.tfvars .
gcloud storage cp gs://zipline-canary-vars/canary_backend.tf .
gcloud storage cp gs://zipline-canary-vars/canary_divergences.tf .
gcloud storage cp gs://zipline-canary-vars/.terraform.lock.hcl .