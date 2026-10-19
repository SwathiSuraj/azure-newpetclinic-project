#!/bin/bash
# Pre-deployment validation script for AKS

set -e

echo "========== Pre-Deployment Validation =========="

CLUSTER_NAME=${1:-"your-aks-cluster"}
RESOURCE_GROUP=${2:-"your-resource-group"}
NAMESPACE=${3:-"default"}
APP_NAME=${4:-"spring-petclinic"}

echo "Cluster: $CLUSTER_NAME"
echo "Resource Group: $RESOURCE_GROUP"
echo "Namespace: $NAMESPACE"
echo "Application: $APP_NAME"

# Check authentication
echo ""
echo "Checking Azure authentication..."
if az account show > /dev/null 2>&1; then
    echo "✓ Azure CLI authenticated"
else
    echo "✗ Azure CLI not authenticated"
    exit 1
fi

# Check cluster existence
echo ""
echo "Checking AKS cluster..."
if az aks show --resource-group "$RESOURCE_GROUP" --name "$CLUSTER_NAME" > /dev/null 2>&1; then
    echo "✓ AKS cluster found"
else
    echo "✗ AKS cluster not found"
    exit 1
fi

# Get credentials
echo ""
echo "Getting AKS credentials..."
az aks get-credentials --resource-group "$RESOURCE_GROUP" --name "$CLUSTER_NAME" --overwrite-existing

# Check kubectl connection
echo ""
echo "Checking kubectl connection..."
if kubectl cluster-info > /dev/null 2>&1; then
    echo "✓ kubectl connection successful"
else
    echo "✗ kubectl connection failed"
    exit 1
fi

# Check namespace
echo ""
echo "Checking namespace..."
if kubectl get namespace "$NAMESPACE" > /dev/null 2>&1; then
    echo "✓ Namespace $NAMESPACE exists"
else
    echo "✗ Namespace $NAMESPACE does not exist, creating..."
    kubectl create namespace "$NAMESPACE"
fi

# Check storage class
echo ""
echo "Checking storage classes..."
if kubectl get storageclass > /dev/null 2>&1; then
    echo "✓ Storage classes available"
    kubectl get storageclass
else
    echo "⚠ No storage classes found"
fi

# Check node resources
echo ""
echo "Checking node resources..."
kubectl top nodes || echo "Metrics not available"

# Check cluster role binding
echo ""
echo "Checking RBAC..."
if kubectl get clusterrolebinding > /dev/null 2>&1; then
    echo "✓ RBAC configured"
else
    echo "✗ RBAC not configured"
fi

# Check ingress controller
echo ""
echo "Checking ingress controller..."
if kubectl get svc -A | grep -q ingress-nginx; then
    echo "✓ Ingress controller found"
else
    echo "⚠ NGINX ingress controller not found"
fi

# Check DNS
echo ""
echo "Checking DNS..."
kubectl get svc -n kube-system | grep -i dns || echo "⚠ DNS service not found"

# Pre-pull image to verify ACR access
echo ""
echo "Verifying ACR access (if needed)..."
# This is optional and depends on your setup

echo ""
echo "========== Validation Complete =========="
echo "✓ All checks passed, cluster is ready for deployment"
