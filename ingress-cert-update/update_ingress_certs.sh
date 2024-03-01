#!/bin/bash

# Prompt the user for necessary details
read -p "Enter the path to the root CA certificate file (ca-bundle.crt): " root_ca_path
read -p "Enter the name for the ConfigMap to store the root CA certificate: " configmap_name
read -p "Enter the name for the TLS secret: " tls_secret_name

# Create ConfigMap for custom CA
oc create configmap $configmap_name --from-file=ca-bundle.crt=$root_ca_path -n openshift-config

# Patch proxy/cluster to use custom CA
oc patch proxy/cluster --type=merge --patch='{"spec":{"trustedCA":{"name":"'$configmap_name'"}}}' 

# Prompt user for TLS certificate and key files
read -p "Enter the path to the TLS certificate file (tls.crt): " tls_cert_path
read -p "Enter the path to the TLS key file (tls.key): " tls_key_path

# Create TLS secret
oc create secret tls $tls_secret_name --cert=$tls_cert_path --key=$tls_key_path -n openshift-ingress

# Patch ingresscontroller.operator to use the default certificate
oc patch ingresscontroller.operator default --type=merge -p '{"spec":{"defaultCertificate": {"name": "'$tls_secret_name'"}}}' -n openshift-ingress-operator

echo "Default router certificates in Openshift updated successfully."

