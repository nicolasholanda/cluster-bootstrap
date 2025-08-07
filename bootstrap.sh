#!/bin/bash
set -e

# Step 1: Generate kubeconfig for Jenkins bootstrap admin
cd k8s-resources
bash generate-kubeconfig.sh
cd ..

# Step 2: Start Jenkins bootstrap instance
cd jenkins

echo "Starting Jenkins bootstrap container..."
docker compose up -d

# Step 4: Show Jenkins URL
JENKINS_PORT=8081
JENKINS_URL="http://localhost:${JENKINS_PORT}"
echo "Jenkins is starting at: ${JENKINS_URL}"

echo "Bootstrap complete. You can now access Jenkins and run the bootstrap pipeline."

