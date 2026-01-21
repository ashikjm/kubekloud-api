#!/bin/bash

# Harbor Setup Script
# Automates Harbor installation in Kubernetes cluster

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}======================================${NC}"
echo -e "${BLUE}Harbor Container Registry Setup${NC}"
echo -e "${BLUE}======================================${NC}"
echo ""

# Check prerequisites
echo -e "${YELLOW}Checking prerequisites...${NC}"

# Check kubectl
if ! command -v kubectl &> /dev/null; then
    echo -e "${RED}Error: kubectl is not installed${NC}"
    exit 1
fi
echo -e "${GREEN}✓ kubectl found${NC}"

# Check helm
if ! command -v helm &> /dev/null; then
    echo -e "${RED}Error: Helm is not installed${NC}"
    echo "Install Helm: https://helm.sh/docs/intro/install/"
    exit 1
fi
echo -e "${GREEN}✓ Helm found${NC}"

# Check cluster connectivity
if ! kubectl cluster-info &> /dev/null; then
    echo -e "${RED}Error: Not connected to a Kubernetes cluster${NC}"
    exit 1
fi
echo -e "${GREEN}✓ Connected to Kubernetes cluster${NC}"

echo ""
echo -e "${YELLOW}Current cluster:${NC}"
kubectl cluster-info | head -1
echo ""

read -p "Continue with this cluster? (y/n) " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Setup cancelled."
    exit 0
fi

# Configuration
NAMESPACE="harbor-system"
HARBOR_VERSION="${HARBOR_VERSION:-1.14.0}"
HARBOR_ADMIN_PASSWORD="${HARBOR_PASSWORD:-Harbor12345}"

echo ""
echo -e "${YELLOW}Configuration:${NC}"
echo "  Namespace: $NAMESPACE"
echo "  Harbor Version: $HARBOR_VERSION"
echo "  Admin Password: ********"
echo ""

# Add Harbor Helm repository
echo -e "${YELLOW}Step 1: Adding Harbor Helm repository...${NC}"
helm repo add harbor https://helm.goharbor.io 2>/dev/null || true
helm repo update
echo -e "${GREEN}✓ Harbor Helm repository added${NC}"

# Create namespace
echo ""
echo -e "${YELLOW}Step 2: Creating namespace...${NC}"
kubectl create namespace $NAMESPACE 2>/dev/null || echo "Namespace already exists"
echo -e "${GREEN}✓ Namespace ready${NC}"

# Check if Harbor is already installed
if helm list -n $NAMESPACE | grep -q "^harbor"; then
    echo ""
    echo -e "${YELLOW}Harbor is already installed. Do you want to upgrade? (y/n)${NC}"
    read -p "" -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        ACTION="upgrade"
    else
        echo "Skipping installation."
        ACTION="skip"
    fi
else
    ACTION="install"
fi

# Install or upgrade Harbor
if [[ "$ACTION" == "install" ]] || [[ "$ACTION" == "upgrade" ]]; then
    echo ""
    echo -e "${YELLOW}Step 3: ${ACTION^}ing Harbor...${NC}"
    echo "This may take a few minutes..."
    
    if [[ -f "values.yaml" ]]; then
        echo "Using custom values.yaml"
        helm $ACTION harbor harbor/harbor \
            --namespace $NAMESPACE \
            --version $HARBOR_VERSION \
            --values values.yaml \
            --set harborAdminPassword=$HARBOR_ADMIN_PASSWORD \
            --timeout 10m \
            --wait
    else
        echo "Using default values"
        helm $ACTION harbor harbor/harbor \
            --namespace $NAMESPACE \
            --version $HARBOR_VERSION \
            --set expose.type=nodePort \
            --set expose.tls.enabled=false \
            --set harborAdminPassword=$HARBOR_ADMIN_PASSWORD \
            --set persistence.persistentVolumeClaim.registry.size=20Gi \
            --timeout 10m \
            --wait
    fi
    
    echo -e "${GREEN}✓ Harbor ${ACTION}ed successfully${NC}"
fi

# Wait for all pods to be ready
echo ""
echo -e "${YELLOW}Step 4: Waiting for Harbor to be ready...${NC}"
kubectl wait --for=condition=ready pod \
    -l app=harbor \
    -n $NAMESPACE \
    --timeout=300s 2>/dev/null || true

# Check deployment status
echo ""
echo -e "${YELLOW}Harbor Deployment Status:${NC}"
kubectl get pods -n $NAMESPACE

# Get access information
echo ""
echo -e "${GREEN}======================================${NC}"
echo -e "${GREEN}Harbor Installation Complete!${NC}"
echo -e "${GREEN}======================================${NC}"
echo ""

# Get NodePort
NODE_PORT=$(kubectl get svc harbor-portal -n $NAMESPACE -o jsonpath='{.spec.ports[0].nodePort}' 2>/dev/null || echo "N/A")
NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')

echo -e "${YELLOW}Access Information:${NC}"
echo ""

if [[ "$NODE_PORT" != "N/A" ]]; then
    echo "Harbor URL: http://$NODE_IP:$NODE_PORT"
    echo "           or http://harbor.local:$NODE_PORT (add to /etc/hosts)"
else
    echo "Use port-forward: kubectl port-forward -n $NAMESPACE svc/harbor-portal 8080:80"
    echo "Then access: http://localhost:8080"
fi

echo ""
echo "Default Credentials:"
echo "  Username: admin"
echo "  Password: $HARBOR_ADMIN_PASSWORD"
echo ""

echo -e "${RED}⚠️  IMPORTANT: Change the admin password immediately!${NC}"
echo ""

echo -e "${YELLOW}Next Steps:${NC}"
echo "1. Access Harbor UI and change admin password"
echo "2. Create a project named 'kubekloud'"
echo "3. Configure Docker to use Harbor:"
echo "   - Add to /etc/docker/daemon.json:"
echo '     {"insecure-registries": ["harbor.local:'$NODE_PORT'"]}'
echo "   - Restart Docker"
echo "4. Login: docker login harbor.local:$NODE_PORT"
echo "5. Run: ./build-push-harbor.sh (from harbor directory)"
echo ""

echo -e "${YELLOW}Useful Commands:${NC}"
echo "View status:  helm status harbor -n $NAMESPACE"
echo "View logs:    kubectl logs -n $NAMESPACE -l app=harbor"
echo "Uninstall:    helm uninstall harbor -n $NAMESPACE"
echo ""

# Save configuration
cat > harbor-config.env <<EOF
# Harbor Configuration
HARBOR_URL=harbor.local:$NODE_PORT
HARBOR_NAMESPACE=$NAMESPACE
HARBOR_ADMIN_USER=admin
HARBOR_ADMIN_PASSWORD=$HARBOR_ADMIN_PASSWORD
HARBOR_PROJECT=kubekloud
NODE_IP=$NODE_IP
NODE_PORT=$NODE_PORT
EOF

echo -e "${GREEN}Configuration saved to harbor-config.env${NC}"
echo ""

