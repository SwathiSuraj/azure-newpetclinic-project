#!/bin/bash
# Trivy scanning script with detailed reporting

set -e

IMAGE_NAME=${1:-"spring-petclinic"}
IMAGE_TAG=${2:-"latest"}
REGISTRY_URL=${3:-"your-registry.azurecr.io"}
SEVERITY=${4:-"HIGH,CRITICAL"}
OUTPUT_DIR=${5:-"./trivy-reports"}

echo "========== Trivy Vulnerability Scanning =========="
echo "Image: $REGISTRY_URL/$IMAGE_NAME:$IMAGE_TAG"
echo "Severity: $SEVERITY"
echo "Output Directory: $OUTPUT_DIR"

# Create output directory
mkdir -p "$OUTPUT_DIR"

# Install Trivy if not present
if ! command -v trivy &> /dev/null; then
    echo "Installing Trivy..."
    wget -qO - https://aquasecurity.github.io/trivy-repo/deb/public.key | apt-key add -
    echo "deb https://aquasecurity.github.io/trivy-repo/deb $(lsb_release -sc) main" | tee -a /etc/apt/sources.list.d/trivy.list
    apt-get update
    apt-get install -y trivy
fi

echo "Trivy version:"
trivy version

# Check if image exists
echo ""
echo "Checking image availability..."
docker pull "$REGISTRY_URL/$IMAGE_NAME:$IMAGE_TAG" > /dev/null 2>&1 || {
    echo "⚠ Could not pull image, scanning from local or remote repository"
}

# Run Trivy scans
echo ""
echo "Running vulnerability scans..."

# JSON report
echo "Generating JSON report..."
trivy image \
    --severity "$SEVERITY" \
    --format json \
    --output "$OUTPUT_DIR/trivy-scan-full.json" \
    "$REGISTRY_URL/$IMAGE_NAME:$IMAGE_TAG" || true

# Table report
echo "Generating table report..."
trivy image \
    --severity "$SEVERITY" \
    --format table \
    --output "$OUTPUT_DIR/trivy-scan-table.txt" \
    "$REGISTRY_URL/$IMAGE_NAME:$IMAGE_TAG" || true

# SARIF report for GitHub Security
echo "Generating SARIF report..."
trivy image \
    --severity "$SEVERITY" \
    --format sarif \
    --output "$OUTPUT_DIR/trivy-scan.sarif" \
    "$REGISTRY_URL/$IMAGE_NAME:$IMAGE_TAG" || true

# Display summary
echo ""
echo "========== Scan Results Summary =========="
if [ -f "$OUTPUT_DIR/trivy-scan-table.txt" ]; then
    cat "$OUTPUT_DIR/trivy-scan-table.txt"
fi

# Count vulnerabilities
echo ""
echo "Vulnerability Count:"
if [ -f "$OUTPUT_DIR/trivy-scan-full.json" ]; then
    CRITICAL=$(jq '[.Results[] | .Misconfigurations[]? | select(.Severity=="CRITICAL")] | length' "$OUTPUT_DIR/trivy-scan-full.json" 2>/dev/null || echo "0")
    HIGH=$(jq '[.Results[] | .Misconfigurations[]? | select(.Severity=="HIGH")] | length' "$OUTPUT_DIR/trivy-scan-full.json" 2>/dev/null || echo "0")
    
    echo "Critical: $CRITICAL"
    echo "High: $HIGH"
fi

echo ""
echo "Reports generated in: $OUTPUT_DIR"
echo "=========================================="

# Exit with warning if CRITICAL found
if [ -f "$OUTPUT_DIR/trivy-scan-table.txt" ] && grep -q "CRITICAL" "$OUTPUT_DIR/trivy-scan-table.txt"; then
    echo "⚠ CRITICAL vulnerabilities detected!"
    exit 1
fi

echo "✓ Scan completed successfully"
exit 0
