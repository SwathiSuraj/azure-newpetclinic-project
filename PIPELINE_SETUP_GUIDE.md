# Spring PetClinic CI/CD Pipeline - Complete Setup Guide

## Overview

This guide provides step-by-step instructions to deploy the Spring PetClinic application to Azure Kubernetes Service (AKS) using a complete CI/CD pipeline with Jenkins or GitHub Actions.

### Pipeline Architecture

```
Source Code (GitHub)
    ↓
Build & Compile (Maven)
    ↓
Unit Tests
    ↓
Code Quality (SonarQube)
    ↓
Docker Build
    ↓
Push to ACR
    ↓
Security Scan (Trivy)
    ↓
Deploy to AKS
    ↓
Smoke Tests
    ↓
Notification
```

---

## Prerequisites

### Required Tools

#### Local Development Environment

- **Git**: Version control
  ```bash
  git --version
  ```

- **Java 11+**: Application runtime
  ```bash
  java -version
  ```

- **Apache Maven 3.8+**: Build tool
  ```bash
  mvn -version
  ```

- **Docker Desktop**: Container runtime
  ```bash
  docker --version
  docker ps
  ```

- **Azure CLI**: Azure resource management
  ```bash
  az --version
  az login
  ```

- **kubectl**: Kubernetes management
  ```bash
  kubectl version --client
  ```

#### Azure Resources

1. **Azure Subscription** - Active subscription with credits
2. **Resource Group** - Container for AKS cluster
3. **AKS Cluster** - Kubernetes cluster
4. **Azure Container Registry (ACR)** - Docker image repository
5. **Service Principal** - For authentication

#### CI/CD Infrastructure

1. **Jenkins Server** (Option 1)
   - Jenkins 2.4+ with Pipeline
   - Docker plugin
   - Kubernetes plugin
   - SonarQube plugin
   - Azure plugins

2. **GitHub Actions** (Option 2)
   - GitHub repository with Actions enabled
   - GitHub Secrets configured

3. **SonarQube Server** - Code quality analysis
   - SonarQube 9.0+
   - PostgreSQL database

---

## Part 1: Azure Infrastructure Setup

### 1.1 Create Resource Group

```bash
RESOURCE_GROUP="petclinic-rg"
LOCATION="eastus"

az group create \
  --name $RESOURCE_GROUP \
  --location $LOCATION
```

### 1.2 Create Azure Container Registry

```bash
REGISTRY_NAME="petclinicacr"

az acr create \
  --resource-group $RESOURCE_GROUP \
  --name $REGISTRY_NAME \
  --sku Basic \
  --admin-enabled true

# Get credentials
az acr credential show \
  --name $REGISTRY_NAME \
  --query "[username, passwords[0].value]" \
  --output tsv
```

### 1.3 Create AKS Cluster

```bash
CLUSTER_NAME="petclinic-aks"
NODE_COUNT=3
VM_SIZE="Standard_B2s"

az aks create \
  --resource-group $RESOURCE_GROUP \
  --name $CLUSTER_NAME \
  --node-count $NODE_COUNT \
  --vm-set-type VirtualMachineScaleSets \
  --load-balancer-sku standard \
  --enable-managed-identity \
  --network-plugin azure \
  --docker-bridge-address 172.17.0.1/16 \
  --service-cidr 10.0.0.0/16 \
  --dns-service-ip 10.0.0.10 \
  --node-vm-size $VM_SIZE \
  --enable-cluster-autoscaling \
  --min-count 3 \
  --max-count 10
```

### 1.4 Configure kubectl

```bash
az aks get-credentials \
  --resource-group $RESOURCE_GROUP \
  --name $CLUSTER_NAME \
  --overwrite-existing

# Verify connection
kubectl cluster-info
kubectl get nodes
```

### 1.5 Create Service Principal for Deployment

```bash
# Create service principal
SP=$(az ad sp create-for-rbac \
  --name "petclinic-cicd-sp" \
  --role Contributor \
  --scopes "/subscriptions/$(az account show --query id -o tsv)")

echo $SP | jq '{
  subscription_id: .subscriptionId,
  client_id: .appId,
  client_secret: .password,
  tenant_id: .tenant
}'

# Grant AKS access
az role assignment create \
  --assignee $(echo $SP | jq -r '.appId') \
  --role "Azure Kubernetes Service Cluster User Role" \
  --scope "/subscriptions/$(az account show --query id -o tsv)/resourcegroups/$RESOURCE_GROUP"
```

### 1.6 Create ACR Image Pull Secret in AKS

```bash
REGISTRY_URL="$REGISTRY_NAME.azurecr.io"
REGISTRY_USER=$(az acr credential show -n $REGISTRY_NAME --query "[username]" -o tsv)
REGISTRY_PASS=$(az acr credential show -n $REGISTRY_NAME --query "[passwords[0].value]" -o tsv)

kubectl create secret docker-registry acr-secret \
  --docker-server=$REGISTRY_URL \
  --docker-username=$REGISTRY_USER \
  --docker-password=$REGISTRY_PASS \
  --namespace=default
```

---

## Part 2: Jenkins Setup

### 2.1 Install Jenkins (Using Docker Compose)

```bash
# Start Jenkins with all dependencies
docker-compose up -d

# Get initial admin password
docker exec jenkins cat /var/jenkins_home/secrets/initialAdminPassword
```

Access Jenkins at `http://localhost:8080`

### 2.2 Install Required Jenkins Plugins

1. Navigate to **Manage Jenkins** → **Manage Plugins**
2. Search and install:
   - Docker Pipeline
   - Kubernetes
   - Azure Credentials
   - Azure CLI
   - SonarQube Scanner
   - GitHub Branch Source
   - Pipeline: Declarative
   - Email Extension
   - Slack Notification

### 2.3 Create Jenkins Credentials

**GitHub Access Token:**
1. Go to **Manage Jenkins** → **Manage Credentials**
2. Click **Add Credentials**
3. Type: Username with password
4. Username: `jenkins-bot`
5. Password: Your GitHub Personal Access Token
6. ID: `github-credentials`

**SonarQube Token:**
1. Type: Secret text
2. Secret: Your SonarQube token
3. ID: `sonar-token`

**Azure Service Principal:**
1. Type: Azure Service Principal
2. Fill with values from Step 1.5
3. ID: `azure-credentials`

**ACR Credentials:**
1. Type: Username with password
2. Username: Registry username from Step 1.2
3. Password: Registry password from Step 1.2
4. ID: `acr-credentials`

### 2.4 Create Jenkins Pipeline Job

1. Click **New Item**
2. Name: `spring-petclinic-pipeline`
3. Type: **Pipeline**
4. Click **OK**

**Pipeline Configuration:**
1. Under "Pipeline", select **Pipeline script from SCM**
2. SCM: **Git**
3. Repository URL: `https://github.com/spring-projects/spring-petclinic.git`
4. Branch: `*/main`
5. Script Path: `Jenkinsfile`
6. Click **Save**

### 2.5 Configure Global System Settings

**System Configuration:**
1. SonarQube servers:
   - Server URL: `http://sonarqube:9000`
   - Server authentication token: Select `sonar-token`

2. Docker:
   - Docker URL: `unix:///var/run/docker.sock`

3. Kubernetes:
   - Kubernetes URL: Your AKS cluster URL
   - Kubernetes namespace: `default`

---

## Part 3: GitHub Actions Setup

### 3.1 Add Repository Secrets

In your GitHub repository:
1. Go to **Settings** → **Secrets and variables** → **Actions**
2. Add the following secrets:

```
ACR_REGISTRY_URL=your-registry.azurecr.io
ACR_USERNAME=<registry-username>
ACR_PASSWORD=<registry-password>
SONAR_HOST_URL=http://sonarqube:9000
SONAR_TOKEN=<your-sonar-token>
AZURE_CREDENTIALS=<json-from-service-principal>
AKS_RESOURCE_GROUP=petclinic-rg
AKS_CLUSTER_NAME=petclinic-aks
SLACK_WEBHOOK=<your-slack-webhook>
```

### 3.2 Workflow File

The workflow file `.github/workflows/ci-cd-pipeline.yml` is already created with complete stages.

### 3.3 Create Azure Service Principal JSON

```bash
az ad sp create-for-rbac \
  --name "github-actions-sp" \
  --role Contributor \
  --scopes "/subscriptions/$(az account show --query id -o tsv)" \
  --output json
```

Copy the JSON output to GitHub Secrets as `AZURE_CREDENTIALS`

### 3.4 Trigger Workflow

The workflow triggers automatically on:
- Push to `main` or `develop` branch
- Pull requests to `main`
- Manual trigger with `workflow_dispatch`

---

## Part 4: SonarQube Setup

### 4.1 Access SonarQube

URL: `http://localhost:9000`
Default credentials: `admin` / `admin`

### 4.2 Create Project

1. Click **Create Project**
2. Name: `spring-petclinic`
3. Project Key: `spring-petclinic`
4. Click **Set Up**
5. Select **Jenkins**
6. Follow the setup wizard

### 4.3 Generate Token

1. Click user icon (top-right) → **My Account** → **Security**
2. Generate token: `sonarqube-token`
3. Copy and save securely

### 4.4 Configure Quality Gate

1. Go to **Quality Gates**
2. Create new Quality Gate: `petclinic-quality-gate`
3. Add conditions:
   - Coverage is less than 80%
   - Duplicated Lines (%) is greater than 3%
   - Maintainability Rating is worse than B

---

## Part 5: Local Testing

### 5.1 Clone Repository

```bash
git clone https://github.com/spring-projects/spring-petclinic.git
cd spring-petclinic
```

### 5.2 Build Locally

```bash
# Maven build
mvn clean package

# Run tests
mvn test

# SonarQube analysis
mvn sonar:sonar \
  -Dsonar.projectKey=spring-petclinic \
  -Dsonar.host.url=http://localhost:9000 \
  -Dsonar.login=<your-sonar-token>
```

### 5.3 Build Docker Image

```bash
# Build image
docker build -t spring-petclinic:1.0 .

# Run locally
docker run -p 8080:8080 spring-petclinic:1.0

# Test
curl http://localhost:8080
```

### 5.4 Push to ACR

```bash
# Login to ACR
az acr login --name $REGISTRY_NAME

# Tag image
docker tag spring-petclinic:1.0 $REGISTRY_URL/spring-petclinic:1.0

# Push image
docker push $REGISTRY_URL/spring-petclinic:1.0
```

### 5.5 Scan with Trivy

```bash
# Install Trivy
curl -sfL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh | sh -s -- -b /usr/local/bin

# Scan image
trivy image $REGISTRY_URL/spring-petclinic:1.0

# Generate report
trivy image --format json -o trivy-report.json $REGISTRY_URL/spring-petclinic:1.0
```

---

## Part 6: Manual AKS Deployment

### 6.1 Validate AKS Cluster

```bash
./scripts/validate-aks.sh $CLUSTER_NAME $RESOURCE_GROUP default spring-petclinic
```

### 6.2 Deploy Application

```bash
./scripts/deploy-aks.sh default spring-petclinic 1.0 $REGISTRY_URL
```

### 6.3 Verify Deployment

```bash
# Check deployment
kubectl get deployment spring-petclinic

# Check pods
kubectl get pods -l app=spring-petclinic

# Check service
kubectl get svc spring-petclinic-service

# Get service IP
kubectl get svc spring-petclinic-service -o jsonpath='{.status.loadBalancer.ingress[0].ip}'

# Check logs
kubectl logs -l app=spring-petclinic --tail=100
```

### 6.4 Test Application

```bash
# Port forward
kubectl port-forward svc/spring-petclinic-service 8080:80

# Test in another terminal
curl http://localhost:8080
curl http://localhost:8080/manage/health
```

---

## Part 7: Troubleshooting

### Pipeline Fails at Build Stage

```bash
# Check Maven dependencies
mvn dependency:resolve

# Check Java version compatibility
java -version

# View Maven logs
mvn clean package -X | head -100
```

### Docker Build Fails

```bash
# Verify Docker daemon
docker ps

# Check Dockerfile syntax
docker build --no-cache .

# View build logs
docker build . --progress=plain
```

### ACR Push Failed

```bash
# Verify ACR login
az acr login --name $REGISTRY_NAME

# Check ACR credentials
az acr credential show --name $REGISTRY_NAME

# Test push manually
docker tag test:latest $REGISTRY_URL/test:latest
docker push $REGISTRY_URL/test:latest
```

### Trivy Scan Issues

```bash
# Update Trivy
trivy image --download-db-only

# Check database
trivy version --format json

# Scan with verbose output
trivy image -v $REGISTRY_URL/spring-petclinic:1.0
```

### AKS Deployment Failed

```bash
# Check cluster connectivity
kubectl cluster-info

# Verify image pull
kubectl describe pod -l app=spring-petclinic

# Check events
kubectl get events --sort-by='.lastTimestamp'

# View service logs
kubectl logs -l app=spring-petclinic --previous

# Check resource limits
kubectl top nodes
kubectl top pods
```

### SonarQube Quality Gate Fails

```bash
# View SonarQube logs
docker logs sonarqube

# Check project status in SonarQube UI
curl -s "http://localhost:9000/api/qualitygates/project_status?projectKey=spring-petclinic"

# View detailed issues
curl -s "http://localhost:9000/api/issues/search?componentRoots=spring-petclinic" | jq
```

---

## Part 8: Monitoring & Maintenance

### Monitor Pipeline

**Jenkins:**
- Dashboard: `http://jenkins:8080`
- Pipeline logs in build details
- Configure email notifications

**GitHub Actions:**
- Actions tab in repository
- Workflow run details
- Automatic annotations on PRs

### Monitor Application

```bash
# Check deployment health
kubectl get deployment spring-petclinic -o jsonpath='{.status}'

# Monitor pod resources
watch -n 5 'kubectl top pods -l app=spring-petclinic'

# Check HPA status
kubectl get hpa spring-petclinic-hpa

# View metrics
kubectl get --raw /apis/metrics.k8s.io/v1beta1/namespaces/default/pods
```

### Update Application

```bash
# Deploy new version
./scripts/deploy-aks.sh default spring-petclinic 2.0 $REGISTRY_URL

# Check rollout status
kubectl rollout status deployment/spring-petclinic

# Rollback if needed
kubectl rollout undo deployment/spring-petclinic
```

### Cleanup

```bash
# Delete deployment
kubectl delete deployment spring-petclinic

# Delete service
kubectl delete svc spring-petclinic-service

# Delete HPA
kubectl delete hpa spring-petclinic-hpa

# Delete secrets
kubectl delete secret acr-secret

# Delete AKS cluster
az aks delete --resource-group $RESOURCE_GROUP --name $CLUSTER_NAME
```

---

## Part 9: Security Best Practices

1. **Credentials Management**
   - Never commit credentials to Git
   - Use secrets management systems
   - Rotate credentials regularly

2. **Image Security**
   - Scan images for vulnerabilities
   - Use minimal base images
   - Keep dependencies updated

3. **AKS Security**
   - Use Network Policies
   - Enable RBAC
   - Use private clusters if possible
   - Implement Pod Security Policies

4. **CICD Security**
   - Sign commits
   - Use code review process
   - Enforce branch protection rules
   - Audit all deployments

5. **Runtime Security**
   - Use non-root containers
   - Set resource limits
   - Enable pod security policies
   - Monitor runtime behavior

---

## Part 10: Performance Optimization

1. **Build Optimization**
   - Cache Maven dependencies
   - Use multi-stage Docker builds
   - Parallelize tests

2. **Deployment Optimization**
   - Use rolling updates
   - Configure HPA properly
   - Use pod disruption budgets

3. **Registry Optimization**
   - Enable image cleanup policies
   - Use image caching

4. **Networking**
   - Configure service mesh
   - Use ClusterIP internally
   - LoadBalancer only when needed

---

## Summary

You now have a complete end-to-end CI/CD pipeline for Spring PetClinic that:

✅ Automatically builds and tests code
✅ Analyzes code quality with SonarQube
✅ Scans images for vulnerabilities with Trivy
✅ Deploys to AKS with zero-downtime rollouts
✅ Performs smoke tests post-deployment
✅ Sends notifications on status changes
✅ Supports both Jenkins and GitHub Actions

For questions or issues, refer to the troubleshooting section or consult official documentation.
