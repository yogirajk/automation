#!/bin/bash

# Patch the OpenShift Image Registry configuration
oc patch configs.imageregistry.operator.openshift.io/cluster --patch '{"spec":{"defaultRoute":true}}' --type=merge

echo "OpenShift Image Registry configuration patched to enable the default route."

