#!/bin/bash

rm canary_backend.tf
rm ci_backend.tf
rm canary_divergences.tf
rm ci_divergences.tf
rm .terraform.lock.hcl
rm terraform.tfvars

gcloud storage cp gs://zipline-canary-vars/terraform.tfvars .
gcloud storage cp gs://zipline-canary-vars/canary_backend.tf .
gcloud storage cp gs://zipline-canary-vars/canary_divergences.tf .
gcloud storage cp gs://zipline-canary-vars/.terraform.lock.hcl .