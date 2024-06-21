#!/bin/bash

# Install k3d
echo "Installing k3d..."
curl -s https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash

# Install kubectl
echo "Installing kubectl..."
if ! command -v kubectl &> /dev/null; then
    echo "kubectl not found, installing..."
    if [[ -x "$(command -v apt-get)" ]]; then
        sudo apt-get update
        sudo apt-get install -y kubectl
    elif [[ -x "$(command -v dnf)" ]]; then
        sudo dnf install -y kubectl
    else
        echo "Could not determine package manager to install kubectl. Please install it manually."
        exit 1
    fi
fi

# Check kubectl version
kubectl version --client

# Create SSL certificate and private key
echo "Generating SSL certificate and private key..."
mkdir -p /tmp/k3dvol

openssl genrsa -out /tmp/k3dvol/server.key 2048
openssl req -new -key /tmp/k3dvol/server.key -out /tmp/k3dvol/server.csr \
    -subj "/CN=kubernetes.default.svc/O=example"
openssl x509 -req -days 3650 -in /tmp/k3dvol/server.csr -signkey /tmp/k3dvol/server.key -out /tmp/k3dvol/server.crt

# Create K3D cluster
echo "Creating K3D cluster..."
k3d cluster create fits-cluster -v /tmp/k3dvol:/tmp/k3dvol -p 80:80 --servers 1 --agents 2

# Check if cluster nodes are ready before proceeding
echo "Waiting for cluster nodes to be ready..."
NODES_READY=false
for i in {1..30}; do  # Check up to 30 times with a 10-second interval
    if kubectl get nodes | grep -q "Ready"; then
        NODES_READY=true
        break
    fi
    sleep 10
done

if [ "$NODES_READY" = false ]; then
    echo "Cluster nodes did not become ready within expected time."
    exit 1
fi

# Create namespace
echo "Creating namespace 'keycloak'..."
kubectl create namespace keycloak

# Apply Kubernetes resources
echo "Applying Kubernetes resources..."
kubectl apply -f deployment.yaml -n keycloak
kubectl apply -f service.yaml -n keycloak

# Check deployments and services
echo "Checking deployments and services..."
kubectl get deployments -n keycloak
kubectl get services -n keycloak

# Print cluster information
echo "Cluster information:"
kubectl cluster-info

# Print nodes
echo "Cluster nodes:"
kubectl get nodes
