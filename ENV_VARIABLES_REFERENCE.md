# Environment Variables Reference

## GitHub Actions Secrets

The following secrets must be configured in your GitHub repository settings at:
`Settings` → `Secrets and variables` → `Actions`

### Azure Credentials

```
AZURE_CREDENTIALS=
{
  "clientId": "your-client-id",
  "clientSecret": "your-client-secret",
  "subscriptionId": "your-subscription-id",
  "tenantId": "your-tenant-id"
}
```

To generate:
```bash
az ad sp create-for-rbac --name "github-actions-sp" --role Contributor --scopes "/subscriptions/<SUBSCRIPTION_ID>" --output json
```

### ACR (Azure Container Registry)

```
ACR_REGISTRY_URL=your-registry.azurecr.io
ACR_USERNAME=<registry-username>
ACR_PASSWORD=<registry-password>
```

Get credentials:
```bash
az acr credential show --name <REGISTRY_NAME> --query "[username, passwords[0].value]" --output tsv
```

### SonarQube

```
SONAR_HOST_URL=http://sonarqube:9000
SONAR_TOKEN=<your-sonar-token>
```

Generate token in SonarQube: Profile → My Account → Security → Generate Token

### AKS Configuration

```
AKS_RESOURCE_GROUP=petclinic-rg
AKS_CLUSTER_NAME=petclinic-aks
```

### Notifications

```
SLACK_WEBHOOK=https://hooks.slack.com/services/YOUR/WEBHOOK/URL
```

---

## Jenkins Pipeline Variables

### Required Environment Variables

In Jenkins, set these via:
1. **Manage Jenkins** → **Configure System** → **Global properties**
2. Or set in Jenkinsfile parameters section

```groovy
string(name: 'GIT_REPO', defaultValue: 'https://github.com/spring-projects/spring-petclinic.git')
string(name: 'GIT_BRANCH', defaultValue: 'main')
string(name: 'REGISTRY_URL', defaultValue: 'your-registry.azurecr.io')
string(name: 'REGISTRY_USERNAME', defaultValue: '')
password(name: 'REGISTRY_PASSWORD', defaultValue: '')
string(name: 'SONAR_HOST_URL', defaultValue: 'http://sonarqube:9000')
string(name: 'AKS_RESOURCE_GROUP', defaultValue: 'your-rg')
string(name: 'AKS_CLUSTER_NAME', defaultValue: 'your-aks')
```

### Jenkins Credentials IDs

Reference these in pipeline:

```groovy
withCredentials([
    string(credentialsId: 'sonar-token', variable: 'SONAR_AUTH_TOKEN'),
    usernamePassword(credentialsId: 'acr-credentials', usernameVariable: 'REGISTRY_USERNAME', passwordVariable: 'REGISTRY_PASSWORD'),
    azureServicePrincipal(credentialsId: 'azure-credentials', variable: 'AZURE_CREDS')
])
```

---

## Docker Compose Environment

In `docker-compose.yaml`:

```yaml
environment:
  # PostgreSQL
  POSTGRES_DB: petclinic
  POSTGRES_USER: petclinic
  POSTGRES_PASSWORD: petclinic
  
  # SonarQube
  SONAR_JDBC_URL: jdbc:postgresql://postgres:5432/sonarqube
  SONAR_JDBC_USERNAME: petclinic
  SONAR_JDBC_PASSWORD: petclinic
  SONAR_ES_BOOTSTRAP_CHECKS_DISABLED: "true"
  
  # Jenkins
  JAVA_OPTS: "-Xmx2g -Xms512m"
```

---

## Build Environment Variables

### Maven Build

```bash
export MAVEN_OPTS="-Xmx1024m"
export JAVA_HOME=/usr/lib/jvm/java-11-openjdk

mvn clean package \
  -DskipTests=true \
  -Dmaven.test.skip=true \
  -Dorg.slf4j.simpleLogger.defaultLogLevel=info
```

### Docker Build

```bash
docker build \
  --build-arg BUILD_DATE="$(date -u +'%Y-%m-%dT%H:%M:%SZ')" \
  --build-arg VCS_REF="$(git rev-parse --short HEAD)" \
  --build-arg VERSION="1.0" \
  -t spring-petclinic:1.0 .
```

### Kubernetes Deployment

```bash
export REGISTRY_URL=your-registry.azurecr.io
export APP_NAME=spring-petclinic
export NAMESPACE=default
export DOCKER_IMAGE_TAG=1.0

kubectl apply -f deployment.yaml
```

---

## Local Development Environment Setup

Create `.env` file in your project:

```bash
# Git Configuration
GIT_REPO=https://github.com/spring-projects/spring-petclinic.git
GIT_BRANCH=main

# Java & Maven
JAVA_VERSION=11
MAVEN_VERSION=3.8.6

# Docker
REGISTRY_URL=localhost:5000
APP_NAME=spring-petclinic
IMAGE_TAG=latest

# SonarQube
SONAR_HOST_URL=http://localhost:9000
SONAR_LOGIN=admin
SONAR_PASSWORD=admin

# Azure
AZURE_SUBSCRIPTION_ID=your-subscription-id
AZURE_RESOURCE_GROUP=petclinic-rg
AZURE_TENANT_ID=your-tenant-id

# AKS
AKS_CLUSTER_NAME=petclinic-aks
AKS_NAMESPACE=default

# Trivy
TRIVY_SEVERITY=HIGH,CRITICAL
```

Load with:
```bash
source .env
# or
export $(cat .env | xargs)
```

---

## CI/CD-Specific Environment Variables

### Build Environment

```
BUILD_NUMBER              # Jenkins: Build number
BUILD_ID                  # Jenkins: Build ID
BUILD_TAG                 # Jenkins: Build tag
GIT_COMMIT               # Git commit SHA
GIT_BRANCH               # Git branch
WORKSPACE                # Jenkins workspace
```

### GitHub Actions Environment

```
GITHUB_SHA               # Commit SHA
GITHUB_REF               # Full branch ref
GITHUB_REF_NAME          # Branch name
GITHUB_REPOSITORY        # Owner/repo
GITHUB_RUN_NUMBER        # Workflow run number
GITHUB_RUN_ID            # Workflow run ID
GITHUB_ACTOR             # User who triggered
```

### Docker Image Metadata

```
IMAGE_TAG=${BUILD_NUMBER}
IMAGE_NAME=spring-petclinic
REGISTRY_URL=your-registry.azurecr.io
FULL_IMAGE=${REGISTRY_URL}/${IMAGE_NAME}:${IMAGE_TAG}
```

### Deployment Target

```
KUBE_CONFIG              # Path to kubeconfig
KUBE_CONTEXT             # Kubernetes context
KUBE_NAMESPACE           # Target namespace
SERVICE_ACCOUNT          # Kubernetes service account
```

---

## Example: Complete Environment Setup

```bash
#!/bin/bash

# Azure Configuration
export AZURE_SUBSCRIPTION_ID="your-subscription-id"
export AZURE_RESOURCE_GROUP="petclinic-rg"
export AZURE_TENANT_ID="your-tenant-id"
export AZURE_SP_ID="your-sp-id"
export AZURE_SP_PASSWORD="your-sp-password"

# AKS Configuration
export AKS_CLUSTER_NAME="petclinic-aks"
export AKS_NAMESPACE="default"

# Container Registry
export REGISTRY_URL="your-registry.azurecr.io"
export REGISTRY_USERNAME="username"
export REGISTRY_PASSWORD="password"

# Application Configuration
export APP_NAME="spring-petclinic"
export IMAGE_TAG="1.0"
export REPLICAS="3"

# SonarQube Configuration
export SONAR_HOST_URL="http://sonarqube:9000"
export SONAR_TOKEN="your-sonar-token"

# Source Control
export GIT_REPO="https://github.com/spring-projects/spring-petclinic.git"
export GIT_BRANCH="main"

# Build Configuration
export JAVA_VERSION="11"
export MAVEN_VERSION="3.8.6"
export BUILD_NUMBER="1"

# Logging
export LOG_LEVEL="INFO"

echo "✓ Environment variables configured"
echo "Registry: $REGISTRY_URL"
echo "AKS Cluster: $AKS_CLUSTER_NAME"
echo "Application: $APP_NAME:$IMAGE_TAG"
```

Usage:
```bash
source setup-env.sh
```

---

## Validation Commands

### Verify All Variables

```bash
#!/bin/bash

REQUIRED_VARS=(
  "AZURE_SUBSCRIPTION_ID"
  "AZURE_RESOURCE_GROUP"
  "AKS_CLUSTER_NAME"
  "REGISTRY_URL"
  "APP_NAME"
  "SONAR_HOST_URL"
)

MISSING=0
for var in "${REQUIRED_VARS[@]}"; do
  if [ -z "${!var}" ]; then
    echo "✗ Missing: $var"
    MISSING=1
  else
    echo "✓ $var is set"
  fi
done

if [ $MISSING -eq 0 ]; then
  echo "✓ All required variables are configured"
else
  echo "✗ Some variables are missing"
  exit 1
fi
```

---

## Important Notes

1. **Never commit secrets** to version control
2. **Use secret management** systems (GitHub Secrets, Jenkins Credentials Manager)
3. **Rotate credentials** regularly
4. **Use different credentials** for different environments (dev, staging, prod)
5. **Document sensitive configurations** separately in secure locations
