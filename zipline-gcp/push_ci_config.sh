#!/bin/bash

gcloud storage cp  ./terraform.tfvars gs://zipline-ci-vars/terraform.tfvars
gcloud storage cp ./ci_backend.tf gs://zipline-ci-vars/ci_backend.tf
gcloud storage cp ./ci_divergences.tf gs://zipline-ci-vars/ci_divergences.tf
gcloud storage cp ./.terraform.lock.hcl gs://zipline-ci-vars/.terraform.lock.hcl