#!/bin/bash

# Prompt the user for necessary details
read -p "Enter AWS S3 Bucket name: " aws_bucket
read -p "Enter AWS S3 Access Key ID: " aws_access_key_id
read -p "Enter AWS S3 Secret Access Key: " aws_secret_access_key
read -p "Enter AWS S3 Region: " aws_region

# Create secret for AWS S3
oc create secret generic image-registry-private-configuration-user \
    --from-literal=REGISTRY_STORAGE_S3_ACCESSKEY="$aws_access_key_id" \
    --from-literal=REGISTRY_STORAGE_S3_SECRETKEY="$aws_secret_access_key"

# Patch the OpenShift Image Registry storage with S3
oc patch configs.imageregistry.operator.openshift.io/cluster \
    --patch '{"spec":{"storage":{"s3":{"bucket":"'$aws_bucket'", "region":"'$aws_region'", "encrypt":true}}}}' \
    --type=merge

echo "OpenShift Image Registry storage patched with S3."
