
pipeline {
    agent any

    parameters {
        string(
            name: 'GIT_REPO',
            defaultValue: 'https://github.com/SwathiSuraj/azure-newpetclinic-project.git',
            description: 'GitHub Repository URL'
        )
        string(
            name: 'GIT_BRANCH',
            defaultValue: 'master',
            description: 'GitHub Branch'
        )
        string(
            name: 'REGISTRY_URL',
            defaultValue: 'petclinicacr.azurecr.io',
            description: 'Azure Container Registry URL'
        )
        string(
            name: 'REGISTRY_USERNAME',
            defaultValue: '',
            description: 'ACR Username'
        )
        password(
            name: 'REGISTRY_PASSWORD',
            defaultValue: '',
            description: 'ACR Password'
        )
        string(
            name: 'SONAR_HOST_URL',
            defaultValue: 'http://sonarqube:9000',
            description: 'SonarQube Server URL'
        )
        string(
            name: 'AKS_RESOURCE_GROUP',
            defaultValue: 'test_RG_jenkins_project',
            description: 'AKS Resource Group'
        )
        string(
            name: 'AKS_CLUSTER_NAME',
            defaultValue: 'petclinic-aks',
            description: 'AKS Cluster Name'
        )
    }

    environment {
        APP_NAME = 'spring-petclinic'
        DOCKER_IMAGE_TAG = "${BUILD_NUMBER}"
        JAVA_HOME = '/usr/lib/jvm/java-21-openjdk-amd64'
        MAVEN_HOME = '/usr/share/maven'
        PATH = "${JAVA_HOME}/bin:${MAVEN_HOME}/bin:${env.PATH}"
    }

    options {
        buildDiscarder(logRotator(numToKeepStr: '20'))
        timeout(time: 60, unit: 'MINUTES')
        timestamps()
    }

    stages {

        stage('Checkout') {
            steps {
                echo '========== Checkout Source Code =========='

                checkout([
                    $class: 'GitSCM',
                    branches: [[name: "*/${params.GIT_BRANCH}"]],
                    userRemoteConfigs: [[url: "${params.GIT_REPO}"]]
                ])

                sh '''
                    echo "Current branch:"
                    git branch --show-current
                    echo "Project files:"
                    ls -la
                '''
            }
        }

        stage('Validate') {
            steps {
                echo '========== Validate Environment =========='

                sh '''
                    set -e

                    echo "Checking Java..."
                    java -version
                    javac -version

                    echo "Checking Maven..."
                    mvn -version

                    echo "Checking Git..."
                    git --version

                    echo "Checking Docker..."
                    docker --version

                    echo "Checking Docker access for Jenkins..."
                    docker info >/dev/null

                    echo "Environment validation successful."
                '''
            }
        }

        stage('Build') {
            steps {
                echo '========== Maven Build =========='

                sh '''
                    set -e

                    echo "Building Spring PetClinic..."
                    mvn -B clean package \
                        -DskipTests=true \
                        -Dmaven.test.skip=true \
                        -U

                    echo "Checking the generated JAR..."

                    # Find the actual JAR using a shell wildcard.
                    JAR_FILE=$(find target -maxdepth 1 \
                        -type f \
                        -name 'spring-petclinic-*.jar' \
                        ! -name '*.jar.original' \
                        | head -n 1)

                    if [ -z "$JAR_FILE" ]; then
                        echo "ERROR: JAR file was not generated."
                        ls -la target || true
                        exit 1
                    fi

                    echo "Build successful."
                    echo "Generated JAR: $JAR_FILE"
                    ls -lh "$JAR_FILE"
                '''
            }
        }

        stage('Unit Tests') {
            steps {
                echo '========== Run Unit Tests =========='

                script {
                    try {
                        sh '''
                            set -e
                            mvn -B test
                        '''
                        echo 'Unit tests completed successfully.'
                    } catch (Exception e) {
                        echo "WARNING: Unit tests failed: ${e.message}"
                        unstable('Unit tests failed')
                    }
                }
            }
        }

        stage('Code Quality - SonarQube') {
            steps {
                echo '========== SonarQube Analysis =========='

                script {
                    try {
                        withSonarQubeEnv('SonarQube') {
                            sh '''
                                set -e

                                mvn -B sonar:sonar \
                                    -Dsonar.projectKey=spring-petclinic \
                                    -Dsonar.projectName=spring-petclinic \
                                    -Dsonar.host.url="${SONAR_HOST_URL}" \
                                    -Dsonar.token="${SONAR_AUTH_TOKEN}"
                            '''
                        }

                        timeout(time: 5, unit: 'MINUTES') {
                            def qualityGate = waitForQualityGate()

                            if (qualityGate.status != 'OK') {
                                echo "WARNING: Quality Gate: ${qualityGate.status}"
                                unstable('SonarQube Quality Gate failed')
                            } else {
                                echo 'SonarQube Quality Gate passed.'
                            }
                        }
                    } catch (Exception e) {
                        echo "WARNING: SonarQube is not configured or failed: ${e.message}"
                        unstable('SonarQube stage needs attention')
                    }
                }
            }
        }

        stage('Build Docker Image') {
            steps {
                echo '========== Build Docker Image =========='

                sh '''
                    set -e

                    JAR_FILE=$(find target -maxdepth 1 \
                        -type f \
                        -name 'spring-petclinic-*.jar' \
                        ! -name '*.jar.original' \
                        | head -n 1)

                    if [ -z "$JAR_FILE" ]; then
                        echo "ERROR: No application JAR found."
                        exit 1
                    fi

                    # Create a Dockerfile if the repository has none.
                    if [ ! -f Dockerfile ]; then
                        cat > Dockerfile <<'EOF'
FROM eclipse-temurin:21-jre
WORKDIR /app
COPY target/spring-petclinic-*.jar app.jar
EXPOSE 8080
ENTRYPOINT ["java", "-jar", "app.jar"]
EOF
                    fi

                    echo "Building Docker image..."
                    docker build \
                        -t "${APP_NAME}:${DOCKER_IMAGE_TAG}" .

                    docker tag \
                        "${APP_NAME}:${DOCKER_IMAGE_TAG}" \
                        "${APP_NAME}:latest"

                    docker images | grep spring-petclinic
                    echo "Docker image built successfully."
                '''
            }
        }

        stage('Push to ACR') {
            steps {
                echo '========== Push Image to Azure Container Registry =========='

                script {
                    if (!params.REGISTRY_USERNAME?.trim() ||
                        !params.REGISTRY_PASSWORD?.trim()) {
                        error(
                            'ACR credentials are missing. Configure the ' +
                            'registry username and password before this stage.'
                        )
                    }
                }

                sh '''
                    set -eu

                    echo "Logging in to Azure Container Registry..."

                    printf '%s' "$REGISTRY_PASSWORD" |
                        docker login "$REGISTRY_URL" \
                            --username "$REGISTRY_USERNAME" \
                            --password-stdin

                    docker tag \
                        "${APP_NAME}:${DOCKER_IMAGE_TAG}" \
                        "${REGISTRY_URL}/${APP_NAME}:${DOCKER_IMAGE_TAG}"

                    docker tag \
                        "${APP_NAME}:${DOCKER_IMAGE_TAG}" \
                        "${REGISTRY_URL}/${APP_NAME}:latest"

                    docker push "${REGISTRY_URL}/${APP_NAME}:${DOCKER_IMAGE_TAG}"
                    docker push "${REGISTRY_URL}/${APP_NAME}:latest"

                    docker logout "$REGISTRY_URL"

                    echo "Image pushed to ACR successfully."
                '''
            }
        }

        stage('Trivy Vulnerability Scan') {
            steps {
                echo '========== Trivy Vulnerability Scan =========='

                script {
                    try {
                        sh '''
                            set -e

                            if ! command -v trivy >/dev/null 2>&1; then
                                echo "Trivy is not installed on the VM."
                                echo "Install Trivy separately before scanning."
                                exit 2
                            fi

                            IMAGE="${REGISTRY_URL}/${APP_NAME}:${DOCKER_IMAGE_TAG}"

                            trivy image \
                                --severity HIGH,CRITICAL \
                                --format json \
                                --output trivy-report.json \
                                "$IMAGE"

                            trivy image \
                                --severity HIGH,CRITICAL \
                                "$IMAGE"
                        '''
                    } catch (Exception e) {
                        echo "WARNING: Trivy scan needs attention: ${e.message}"
                        unstable('Trivy scan failed or is not installed')
                    }
                }
            }
        }

        stage('Deploy to AKS') {
            steps {
                echo '========== Deploy to Azure Kubernetes Service =========='

                script {
                    try {
                        withCredentials([
                            usernamePassword(
                                credentialsId: 'azure-service-principal',
                                usernameVariable: 'AZURE_SP_ID',
                                passwordVariable: 'AZURE_SP_PASSWORD'
                            ),
                            string(
                                credentialsId: 'azure-tenant-id',
                                variable: 'AZURE_TENANT_ID'
                            )
                        ]) {
                            sh '''
                                set -eu

                                echo "Logging in to Azure..."

                                az login --service-principal \
                                    --username "$AZURE_SP_ID" \
                                    --password "$AZURE_SP_PASSWORD" \
                                    --tenant "$AZURE_TENANT_ID" \
                                    --output none

                                echo "Getting AKS credentials..."

                                az aks get-credentials \
                                    --resource-group "$AKS_RESOURCE_GROUP" \
                                    --name "$AKS_CLUSTER_NAME" \
                                    --overwrite-existing

                                echo "Checking cluster connection..."
                                kubectl get nodes

                                cat > deployment.yaml <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ${APP_NAME}
  labels:
    app: ${APP_NAME}
spec:
  replicas: 3
  selector:
    matchLabels:
      app: ${APP_NAME}
  template:
    metadata:
      labels:
        app: ${APP_NAME}
    spec:
      containers:
      - name: ${APP_NAME}
        image: ${REGISTRY_URL}/${APP_NAME}:${DOCKER_IMAGE_TAG}
        ports:
        - containerPort: 8080
        resources:
          requests:
            cpu: "250m"
            memory: "256Mi"
          limits:
            cpu: "500m"
            memory: "512Mi"
---
apiVersion: v1
kind: Service
metadata:
  name: ${APP_NAME}-service
spec:
  type: LoadBalancer
  selector:
    app: ${APP_NAME}
  ports:
  - port: 80
    targetPort: 8080
EOF

                                echo "Applying Kubernetes manifests..."
                                kubectl apply -f deployment.yaml

                                echo "Waiting for rollout..."
                                kubectl rollout status \
                                    deployment/"${APP_NAME}" \
                                    --timeout=5m

                                echo "Deployment status:"
                                kubectl get deployment "${APP_NAME}"
                                kubectl get svc "${APP_NAME}-service"
                            '''
                        }
                    } catch (Exception e) {
                        echo "ERROR: AKS deployment failed: ${e.message}"
                        error('AKS deployment stage failed')
                    }
                }
            }
        }

        stage('Smoke Tests') {
            steps {
                echo '========== Post-Deployment Smoke Tests =========='

                script {
                    try {
                        sh '''
                            set -e

                            echo "Getting application service IP..."

                            SERVICE_IP=$(kubectl get svc \
                                "${APP_NAME}-service" \
                                -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

                            if [ -z "$SERVICE_IP" ]; then
                                echo "External IP is not available yet."
                                kubectl get svc "${APP_NAME}-service"
                                exit 1
                            fi

                            echo "Testing service at http://${SERVICE_IP}"

                            ATTEMPT=1
                            while [ "$ATTEMPT" -le 5 ]; do
                                if curl --fail --silent \
                                    "http://${SERVICE_IP}/manage/health"; then
                                    echo "Smoke test passed."
                                    exit 0
                                fi

                                echo "Attempt $ATTEMPT failed; retrying..."
                                sleep 10
                                ATTEMPT=$((ATTEMPT + 1))
                            done

                            echo "ERROR: Application health check failed."
                            exit 1
                        '''
                    } catch (Exception e) {
                        echo "WARNING: Smoke tests failed: ${e.message}"
                        unstable('Smoke tests failed')
                    }
                }
            }
        }
    }

    post {
        always {
            echo '========== Pipeline Cleanup =========='

            archiveArtifacts(
                artifacts: 'target/*.jar,trivy-report.json',
                allowEmptyArchive: true,
                onlyIfSuccessful: false
            )

            cleanWs()

            echo 'Workspace cleanup completed.'
        }

        success {
            echo "Pipeline completed successfully."
            echo "Application: ${APP_NAME}"
            echo "Image tag: ${DOCKER_IMAGE_TAG}"
        }

        failure {
            echo 'Pipeline failed. Check Console Output for the first error.'
        }

        unstable {
            echo 'Pipeline completed with warnings. Review the affected stages.'
        }
    }
}
