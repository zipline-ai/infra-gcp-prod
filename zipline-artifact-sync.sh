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

# Upload wheel to GCS
gcloud storage cp ./wheels/$VERSION/* ${ARTIFACT_PREFIX%/}/release/$VERSION/wheels/

# Upload scripts to GCS
gcloud storage cp ./scripts/* ${ARTIFACT_PREFIX%/}/scripts/

# Copy Flink's Spark expr eval dependency jars
SPARK_LIBS_SRC="gs://zipline-spark-libs/spark-3.5.3/libs"
SPARK_LIBS_JARS=(
    "commons-collections4-4.4.jar"
    "commons-compiler-3.1.9.jar"
    "janino-3.1.9.jar"
    "json4s-ast_2.12-3.7.0-M11.jar"
    "json4s-core_2.12-3.7.0-M11.jar"
    "kryo-shaded-4.0.2.jar"
    "metrics-core-4.2.19.jar"
    "metrics-json-4.2.19.jar"
    "spark-catalyst_2.12-3.5.3.jar"
    "spark-common-utils_2.12-3.5.3.jar"
    "spark-core_2.12-3.5.3.jar"
    "spark-kvstore_2.12-3.5.3.jar"
    "spark-launcher_2.12-3.5.3.jar"
    "spark-hive_2.12-3.5.3.jar"
    "spark-network-common_2.12-3.5.3.jar"
    "spark-network-shuffle_2.12-3.5.3.jar"
    "spark-sql-api_2.12-3.5.3.jar"
    "spark-sql_2.12-3.5.3.jar"
    "spark-unsafe_2.12-3.5.3.jar"
    "xbean-asm9-shaded-4.23.jar"
)
SPARK_LIBS_DST="${ARTIFACT_PREFIX%/}/spark-3.5.3/libs"
for jar in "${SPARK_LIBS_JARS[@]}"; do
    gcloud storage cp "${SPARK_LIBS_SRC}/${jar}" "${SPARK_LIBS_DST}/${jar}"
done

# Summary
JARS_DST="${ARTIFACT_PREFIX%/}/release/$VERSION/jars/"
WHEELS_DST="${ARTIFACT_PREFIX%/}/release/$VERSION/wheels/"
echo ""
echo "=========================================="
echo "Artifact sync complete. Summary:"
echo "  Jars:             $JARS_DST"
echo "  Wheel:            $WHEELS_DST"
echo "  Flink extra jars: $SPARK_LIBS_DST"
echo ""
echo "Make sure FLINK_JARS_URI in your teams.py points to: $SPARK_LIBS_DST"
echo "=========================================="

# Cleanup
trap 'rm -rf ./jars ./wheels ./scripts' EXIT