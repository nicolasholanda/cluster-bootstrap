#!/bin/bash
set -e

SA_NAME=jenkins-bootstrap-admin
NAMESPACE=kube-system

# Apply the service account and cluster role binding YAMLs
kubectl apply -f serviceaccount.yaml
kubectl apply -f clusterrolebinding.yaml

kubectl apply -f secret.yaml

# Get the current context
CONTEXT=$(kubectl config view -o jsonpath='{.clusters[0].name}')

# Wait for the service account token to be created
sleep 5
SECRET_NAME=$(kubectl get secret -n $NAMESPACE | grep $SA_NAME | awk '{print $1}')

if [ -z "$SECRET_NAME" ]; then
    echo "Error: Service account token secret not found."
    exit 1
fi

# Get the token
TOKEN=$(kubectl get secret $SECRET_NAME -n $NAMESPACE -o jsonpath='{.data.token}' | base64 --decode | tr -d '\n')

# Get the CA cert
CA_CERT=$(kubectl get secret $SECRET_NAME -n $NAMESPACE -o jsonpath='{.data.ca\.crt}')

# Get the API server endpoint
APISERVER=$(kubectl config view -o jsonpath='{.clusters[0].cluster.server}')

# Write kubeconfig file
cat > ${SA_NAME}.kubeconfig <<EOF
apiVersion: v1
kind: Config
clusters:
- name: ${CONTEXT}
  cluster:
    certificate-authority-data: ${CA_CERT}
    server: ${APISERVER}
users:
- name: ${SA_NAME}
  user:
    token: ${TOKEN}
contexts:
- name: ${SA_NAME}@${CONTEXT}
  context:
    cluster: ${CONTEXT}
    user: ${SA_NAME}
    namespace: ${NAMESPACE}
current-context: ${SA_NAME}@${CONTEXT}
EOF

echo "Kubeconfig file generated: ${SA_NAME}.kubeconfig"
