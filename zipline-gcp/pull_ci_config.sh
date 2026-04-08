#!/bin/bash

rm canary_backend.tf
rm ci_backend.tf
rm canary_divergences.tf
rm ci_divergences.tf
rm .terraform.lock.hcl
rm terraform.tfvars
rm -rf .terraform

gcloud storage cp gs://zipline-ci-vars/terraform.tfvars .
gcloud storage cp gs://zipline-ci-vars/ci_backend.tf .
gcloud storage cp gs://zipline-ci-vars/ci_divergences.tf .
gcloud storage cp gs://zipline-ci-vars/.terraform.lock.hcl .