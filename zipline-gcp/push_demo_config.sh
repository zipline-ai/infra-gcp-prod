#!/bin/bash

gcloud storage cp  ./terraform.tfvars gs://zipline-demo-vars/terraform.tfvars
gcloud storage cp ./demo_backend.tf gs://zipline-demo-vars/demo_backend.tf
gcloud storage cp ./demo_divergences.tf gs://zipline-demo-vars/demo_divergences.tf
gcloud storage cp ./.terraform.lock.hcl gs://zipline-demo-vars/.terraform.lock.hcl