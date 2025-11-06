#!/bin/bash
set -euxo pipefail

function print_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo "Options:"
    echo "  --artifact_prefix <gcs_bucket>      Specify the gcs bucket to upload artifacts to e.g. \"gs://ck-zipline-artifacts\""
    echo "  --version <version>                 Specify the version you want to run"
    echo "  -h, --help  Show this help message"
}

if [ $# -ne 4 ]; then
    print_usage
    exit 1
fi

while [[ $# -gt 0 ]]; do
    case $1 in
        --artifact_prefix)
            if [[ -z $2 ]]; then
                echo "Error: --artifact_prefix requires a value"
                print_usage
                exit 1
            fi
            ARTIFACT_PREFIX="$2"
            shift 2
            ;;
        -h|--help)
            print_usage
            exit 0
            ;;
        --version)
            if [[ -z $2 ]]; then
                echo "Error: --version requires a value"
                print_usage
                exit 1
            fi
            VERSION="$2"
            shift 2
            ;;
        *)
            echo "Unknown option: $1"
            print_usage
            exit 1
            ;;
    esac
done

# Login to artifactory
jf c add --url https://ziplineai.jfrog.io ziplineai --overwrite

# Download jars from artifactory
jf rt dl "jars/$VERSION/*" ./jars/

# Download wheels from artifactory
jf rt dl "wheels/$VERSION/*" ./wheels/

# Download dataproc initialization scripts from artifactory
jf rt dl "scripts/*" ./scripts/

echo "Beginning Upload To GCS"

# Upload jars to GCS
gcloud storage cp ./jars/$VERSION/* ${ARTIFACT_PREFIX%/}/release/$VERSION/jars/
gcloud storage cp ./jars/$VERSION/* ${ARTIFACT_PREFIX%/}/release/latest/jars/

# Upload wheel to GCS
gcloud storage cp ./wheels/$VERSION/* ${ARTIFACT_PREFIX%/}/release/$VERSION/wheels/

# Upload scripts to GCS
gcloud storage cp ./scripts/* ${ARTIFACT_PREFIX%/}/scripts/

# Cleanup
trap 'rm -rf ./jars ./wheels ./scripts' EXIT