#!/bin/bash
set -e

rm -f canary_backend.tf
rm -f ci_backend.tf
rm -f demo_backend.tf
rm -f canary_divergences.tf
rm -f ci_divergences.tf
rm -f demo_divergences.tf
rm -f .terraform.lock.hcl
rm -f terraform.tfvars
rm -rf .terraform

gcloud storage cp gs://zipline-ci-vars/terraform.tfvars .
gcloud storage cp gs://zipline-ci-vars/ci_backend.tf .
gcloud storage cp gs://zipline-ci-vars/ci_divergences.tf .
gcloud storage cp gs://zipline-ci-vars/.terraform.lock.hcl .