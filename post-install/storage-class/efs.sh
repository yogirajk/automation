#!/bin/bash

# Prompt user for ConfigMap details
read -p "Enter ConfigMap name: " configmap_name
read -p "Enter Namespace name: " namespace_name
read -p "Enter File System ID: " file_system_id
read -p "Enter AWS Region: " aws_region
read -p "Enter Provisioner Name: " provisioner_name
read -p "Enter DNS Name for EFS: " dns_name

# Create ConfigMap
cat <<EOF | oc apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: $configmap_name
  namespace: $namespace_name
data:
  file.system.id: "$file_system_id"
  aws.region: "$aws_region"
  provisionerName: "$provisioner_name"
  dns.name: "$dns_name"
EOF

# Create Role
cat <<EOF | oc apply -f -
kind: Role
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  namespace: $namespace_name
  name: leader-locking-efs-provisioner
rules:
- apiGroups: [""]
  resources: ["endpoints"]
  verbs: ["get", "create", "update", "delete", "patch"]
EOF

# Create ClusterRole
cat <<EOF | oc apply -f -
kind: ClusterRole
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: efs-provisioner-runner
rules:
  - apiGroups: [""]
    resources: ["persistentvolumes"]
    verbs: ["get", "list", "watch", "create", "delete"]
  - apiGroups: [""]
    resources: ["persistentvolumeclaims"]
    verbs: ["get", "list", "watch", "update"]
  - apiGroups: ["storage.k8s.io"]
    resources: ["storageclasses"]
    verbs: ["get", "list", "watch"]
  - apiGroups: [""]
    resources: ["events"]
    verbs: ["create", "update", "patch"]
  - apiGroups: ["security.openshift.io"]
    resources: ["securitycontextconstraints"]
    verbs: ["use"]
    resourceNames: ["hostmount-anyuid"]
EOF

# Create ClusterRoleBinding
cat <<EOF | oc apply -f -
kind: ClusterRoleBinding
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: run-efs-provisioner
subjects:
  - kind: ServiceAccount
    name: efs-provisioner
    namespace: $namespace_name
roleRef:
  kind: ClusterRole
  name: efs-provisioner-runner
  apiGroup: rbac.authorization.k8s.io
EOF

# Create RoleBinding
cat <<EOF | oc apply -f -
kind: RoleBinding
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: leader-locking-efs-provisioner
  namespace: $namespace_name
subjects:
- kind: ServiceAccount
  name: efs-provisioner
  namespace: $namespace_name
roleRef:
  kind: Role
  name: leader-locking-efs-provisioner
  apiGroup: rbac.authorization.k8s.io
EOF

# Create ServiceAccount
oc create sa efs-provisioner -n $namespace_name

# Prompt user for EFS Provisioner Deployment details
read -p "Enter EFS Provisioner Deployment name: " deployment_name
read -p "Enter number of replicas: " replicas

# Create EFS Provisioner Deployment
cat <<EOF | oc apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: $deployment_name
  namespace: $namespace_name
spec:
  replicas: $replicas
  selector:
    matchLabels:
      app: efs-provisioner
  template:
    metadata:
      labels:
        app: efs-provisioner
    spec:
      nodeSelector:
        node-role.kubernetes.io/infra: ''
      serviceAccountName: efs-provisioner
      containers:
        - name: efs-provisioner
          image: quay.io/external_storage/efs-provisioner:latest
          env:
            - name: FILE_SYSTEM_ID
              valueFrom:
                configMapKeyRef:
                  name: $configmap_name
                  key: file.system.id
            - name: AWS_REGION
              valueFrom:
                configMapKeyRef:
                  name: $configmap_name
                  key: aws.region
            - name: PROVISIONER_NAME
              valueFrom:
                configMapKeyRef:
                  name: $configmap_name
                  key: provisionerName
            - name: DNS_NAME
              valueFrom:
                configMapKeyRef:
                  name: $configmap_name
                  key: dns.name
          resources: {}
          volumeMounts:
            - name: pvs-volume
              mountPath: /persistentvolumes
          imagePullPolicy: Always
      serviceAccount: efs-provisioner
      volumes:
        - name: pvs-volume
          nfs:
            server: $dns_name
            path: /
EOF

# Prompt user for StorageClass details
read -p "Enter StorageClass name: " storageclass_name

# Create StorageClass
cat <<EOF | oc apply -f -
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: $storageclass_name
provisioner: $provisioner_name
parameters:
  gidAllocate: 'true'
  gidMax: '2147483647'
  gidMin: '2048'
reclaimPolicy: Delete
volumeBindingMode: Immediate
EOF

