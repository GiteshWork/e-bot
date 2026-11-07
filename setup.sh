
#!/usr/bin/env bash

set -euo pipefail

# Configuration
CLUSTER_NAME="demo"
NAMESPACE="demo"
RELEASE_NAME="demo"
IMAGE_NAME="enterprisebot-demo"
IMAGE_TAG="1.0.0"
CHART_PATH="./chart"

echo "======================================"
echo " Enterprise Bot - Local Setup"
echo "======================================"

# Check required tools
for cmd in docker kind kubectl helm; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        echo "ERROR: Required command not found: $cmd"
        exit 1
    fi
done

# 1. Create or reuse kind cluster
if ! kind get clusters | grep -qx "$CLUSTER_NAME"; then

    echo "[1/6] Creating kind cluster..."

    KIND_CONFIG=$(mktemp)

    cat > "$KIND_CONFIG" <<'EOF'
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
  - role: control-plane
    labels:
      ingress-ready: "true"
    extraPortMappings:
      - containerPort: 80
        hostPort: 80
        protocol: TCP
      - containerPort: 443
        hostPort: 443
        protocol: TCP
EOF

    kind create cluster \
        --name "$CLUSTER_NAME" \
        --config "$KIND_CONFIG" \
        --wait 120s

    rm -f "$KIND_CONFIG"

else
    echo "[1/6] Reusing existing kind cluster..."
fi

kubectl config use-context "kind-${CLUSTER_NAME}"

# 2. Install ingress-nginx
echo "[2/6] Installing ingress-nginx..."

helm repo add ingress-nginx \
    https://kubernetes.github.io/ingress-nginx \
    --force-update

helm repo update ingress-nginx

helm upgrade --install ingress-nginx \
    ingress-nginx/ingress-nginx \
    --version 4.13.2 \
    --namespace ingress-nginx \
    --create-namespace \
    --set controller.hostPort.enabled=true \
    --set controller.hostPort.ports.http=80 \
    --set controller.hostPort.ports.https=443 \
    --set-string 'controller.nodeSelector.ingress-ready=true' \
    --set 'controller.tolerations[0].key=node-role.kubernetes.io/control-plane' \
    --set 'controller.tolerations[0].operator=Exists' \
    --set 'controller.tolerations[0].effect=NoSchedule' \
    --set controller.service.type=NodePort \
    --wait \
    --timeout 5m

kubectl rollout status deployment/ingress-nginx-controller \
    -n ingress-nginx \
    --timeout=180s

# 3. Build application image
echo "[3/6] Building Docker image..."

docker build \
    -t "${IMAGE_NAME}:${IMAGE_TAG}" \
    ./service

# 4. Load image into kind
echo "[4/6] Loading Docker image into kind..."

kind load docker-image \
    "${IMAGE_NAME}:${IMAGE_TAG}" \
    --name "$CLUSTER_NAME"

# 5. Deploy application using Helm
echo "[5/6] Deploying application..."

helm upgrade --install "$RELEASE_NAME" "$CHART_PATH" \
    --namespace "$NAMESPACE" \
    --create-namespace \
    --wait \
    --timeout 180s

# 6. Verify deployment
echo "[6/6] Checking deployment..."

kubectl get pods -n "$NAMESPACE"
kubectl get services -n "$NAMESPACE"
kubectl get ingress -n "$NAMESPACE"

echo "======================================"
echo " Setup completed successfully!"
echo "======================================"
echo "Application: http://demo.local"
