# Spring PetClinic CI/CD Pipeline - Complete Implementation

## 📋 Project Overview

A complete end-to-end CI/CD pipeline implementation for deploying Spring Boot applications to Azure Kubernetes Service (AKS) with automated testing, security scanning, and deployment.

### 🎯 Features

- ✅ **Automated Build Pipeline** - Maven-based Java build
- ✅ **Comprehensive Testing** - Unit tests with coverage reporting
- ✅ **Code Quality Analysis** - SonarQube integration with Quality Gates
- ✅ **Container Security** - Trivy vulnerability scanning
- ✅ **Docker Containerization** - Multi-stage builds
- ✅ **Azure Container Registry** - Centralized image repository
- ✅ **AKS Deployment** - Kubernetes orchestration with autoscaling
- ✅ **Smoke Tests** - Post-deployment validation
- ✅ **Dual Pipeline Options** - Jenkins & GitHub Actions
- ✅ **Health Monitoring** - Probes & metrics
- ✅ **Notifications** - Slack/Email alerts

---

## 📁 Project Structure

```
PETCLINIC/
├── Jenkinsfile                          # Jenkins pipeline definition
├── .github/
│   └── workflows/
│       └── ci-cd-pipeline.yml           # GitHub Actions workflow
├── Dockerfile                           # Multi-stage Docker build
├── sonar-project.properties             # SonarQube configuration
├── pipeline.config                      # Pipeline environment variables
├── docker-compose.yaml                  # Local test infrastructure
├── jenkins-config.yaml                  # Jenkins JCasC configuration
├── scripts/
│   ├── validate-aks.sh                  # AKS validation
│   ├── deploy-aks.sh                    # Manual AKS deployment
│   └── trivy-scan.sh                    # Trivy scanning script
├── PIPELINE_SETUP_GUIDE.md              # Step-by-step setup guide
├── ENV_VARIABLES_REFERENCE.md           # Configuration reference
└── README.md                            # This file
```

---

## 🚀 Quick Start

### Option 1: GitHub Actions (Recommended)

**Prerequisites:**