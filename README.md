# Infrastructure

Configuration to initialize Zipline infrastructure.

## Zipline on GCP Steps

## Initialize Artifacts
### Prerequisites
* Install gcloud sdk if you don't already have it: https://cloud.google.com/sdk/docs/install
* Create a gcs bucket for storing artifacts
* Install the jfrog cli:  https://jfrog.com/getcli/
* Login to gcloud: ``` gcloud auth application-default login ```

### Steps

* Run the artifact sync script with the bucket you created for storing artifacts: ``` ./zipline-artifact-sync.sh --version 0.4.9 --artifact_prefix "gs://<CUSTOMER_BUCKET>"```
    * This will copy the artifacts from Zipline's jfrog repo to your gcs bucket.
    * Select "Save and continue"
    * Select "Web Login" and follow prompts
* Install the zipline cli providing your artifacts bucket again ```./zipline-cli-install.sh --version 0.4.9 --artifact_prefix gs://<CUSTOMER_BUCKET>```
    * Confirm the installation by running ```zipline```. If the command is not found, you may need to create a virtual environment and install the zipline cli there.
    * This script will be used when you want to upgrade or downgrade the cli version in the future.
* The next step will create a directory for your zipline repo. This only needs to be done once. Use `cd` to navigate to the parent directory where you want it stored.
* Run the following command to create the zipline repo: ```zipline admin init --cloud gcp```

## Initialize Infrastructure

Initialize to gcloud and select the project you want to use
* ``` gcloud init ```
* ``` gcloud auth application-default login ```

Enter the zipline-gcp directory and initialize the infrastructure
* ``` cd zipline-gcp ```
* Edit variables.tf setting: 
  * customer_name variable to a unique name for your deployment
  * Fill in the project_id for your gcp project
  * Fill in the region you want to deploy the infrastructure to
  * Fill in the zone for bigtable
  * For artifact_prefix add the bucket you created for storing zipline artifacts e.g. gs://zipline-ck-artifacts
  * For zipline_version, set the version of zipline you are deploying. This should match a version available in docker hub.
  * For personnel_email, add a google groups email to give manual access to the resources to team members
  * For user_email, add a google groups email to give end user access to the services
  * If you want the frontend to be secured, add a custom domain you own to "zipline_ui_domain" and set up the appropriate DNS records to point to the static IPs created for the frontend services.
  * You can also set custom domains for the orchestration hub by adding it to "hub_domain". This is required if you need ingress to cloud run to be internal only.
  * If you want to restrict access to the services to certain IPs, you can add them to the "allowed_ips" variable. If you set this, you must also set "hub_domain" and "zipline_ui_domain" to custom domains you own.
* ``` terraform init ```
* ``` terraform apply ```

### Next

`zipline admin init` command would have created a new directory called `zipline` within your current working directory.

Within that is a README with further instructions for creating and running Zipline features.
