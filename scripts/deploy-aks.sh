#!/bin/bash
# Deploy script for manual deployments

set -e

NAMESPACE=${1:-"default"}
APP_NAME=${2:-"spring-petclinic"}
IMAGE_TAG=${3:-"latest"}
REGISTRY_URL=${4:-"your-registry.azurecr.io"}

echo "========== Deploying Application to AKS =========="
echo "Namespace: $NAMESPACE"
echo "Application: $APP_NAME"
echo "Image Tag: $IMAGE_TAG"
echo "Registry: $REGISTRY_URL"

# Verify kubectl connection
kubectl cluster-info > /dev/null || (echo "✗ kubectl not connected"; exit 1)

# Create namespace if not exists
kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -

# Create ACR secret if needed
read -p "Create ACR secret? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    read -p "Enter ACR username: " ACR_USER
    read -sp "Enter ACR password: " ACR_PASS
    echo
    
    kubectl create secret docker-registry acr-secret \
        --docker-server="$REGISTRY_URL" \
        --docker-username="$ACR_USER" \
        --docker-password="$ACR_PASS" \
        --namespace="$NAMESPACE" \
        --dry-run=client -o yaml | kubectl apply -f -
fi

# Update image in deployment
echo "Deploying application..."
cat > /tmp/deployment.yaml << EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: $APP_NAME
  namespace: $NAMESPACE
spec:
  replicas: 3
  selector:
    matchLabels:
      app: $APP_NAME
  template:
    metadata:
      labels:
        app: $APP_NAME
    spec:
      imagePullSecrets:
      - name: acr-secret
      containers:
      - name: $APP_NAME
        image: $REGISTRY_URL/$APP_NAME:$IMAGE_TAG
        ports:
        - containerPort: 8080
        resources:
          limits:
            cpu: "500m"
            memory: "512Mi"
          requests:
            cpu: "250m"
            memory: "256Mi"
        livenessProbe:
          httpGet:
            path: /manage/health/liveness
            port: 8080
          initialDelaySeconds: 45
          periodSeconds: 15
        readinessProbe:
          httpGet:
            path: /manage/health/readiness
            port: 8080
          initialDelaySeconds: 15
          periodSeconds: 10
---
apiVersion: v1
kind: Service
metadata:
  name: $APP_NAME-service
  namespace: $NAMESPACE
spec:
  type: LoadBalancer
  selector:
    app: $APP_NAME
  ports:
  - protocol: TCP
    port: 80
    targetPort: 8080
EOF

kubectl apply -f /tmp/deployment.yaml

# Wait for rollout
echo "Waiting for deployment..."
kubectl rollout status deployment/$APP_NAME -n "$NAMESPACE" --timeout=10m

# Get service endpoint
echo ""
echo "========== Deployment Status =========="
kubectl get deployment -n "$NAMESPACE" -l app=$APP_NAME
echo ""
kubectl get svc -n "$NAMESPACE" -l app=$APP_NAME

# Check service IP
SERVICE_IP=$(kubectl get svc ${APP_NAME}-service -n "$NAMESPACE" -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "Pending")
echo ""
echo "Service Endpoint: http://$SERVICE_IP"
echo "=========================================="
