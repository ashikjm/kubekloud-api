#!/bin/bash

# Complete KubeKloud API + Harbor Deployment
# This script sets up everything from scratch

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}============================================${NC}"
echo -e "${BLUE}KubeKloud API with Harbor - Full Setup${NC}"
echo -e "${BLUE}============================================${NC}"
echo ""

# Check prerequisites
echo -e "${YELLOW}Checking prerequisites...${NC}"
for cmd in kubectl helm docker; do
    if ! command -v $cmd &> /dev/null; then
        echo -e "${RED}Error: $cmd is not installed${NC}"
        exit 1
    fi
    echo -e "${GREEN}✓ $cmd found${NC}"
done

echo ""
read -p "This will install Harbor and deploy the API. Continue? (y/n) " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Cancelled."
    exit 0
fi

# Step 1: Install Harbor
echo ""
echo -e "${BLUE}=== Step 1: Installing Harbor ===${NC}"
cd harbor
./setup-harbor.sh

# Wait for user to verify
echo ""
echo -e "${YELLOW}Please verify Harbor is accessible before continuing.${NC}"
read -p "Press Enter when ready..."

# Step 2: Configure Harbor
echo ""
echo -e "${BLUE}=== Step 2: Configuring Harbor ===${NC}"
./configure-harbor.sh

# Step 3: Configure Docker
echo ""
echo -e "${BLUE}=== Step 3: Docker Configuration ===${NC}"
echo -e "${YELLOW}⚠️  Important: Add Harbor as insecure registry${NC}"
echo ""
echo "Add this to /etc/docker/daemon.json:"
echo -e "${GREEN}{\"insecure-registries\": [\"harbor.local:30002\"]}${NC}"
echo ""
echo "Then restart Docker:"
echo "  Linux: sudo systemctl restart docker"
echo "  Mac: Restart Docker Desktop"
echo ""
read -p "Press Enter after configuring Docker..."

# Step 4: Add to /etc/hosts
echo ""
echo -e "${BLUE}=== Step 4: Adding Harbor to /etc/hosts ===${NC}"
NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')
echo "Add this line to /etc/hosts:"
echo -e "${GREEN}$NODE_IP harbor.local${NC}"
echo ""
read -p "Add it now? (requires sudo) (y/n) " -n 1 -r
echo ""
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "$NODE_IP harbor.local" | sudo tee -a /etc/hosts
    echo -e "${GREEN}✓ Added to /etc/hosts${NC}"
fi

# Step 5: Build and Push
echo ""
echo -e "${BLUE}=== Step 5: Building and Pushing Image ===${NC}"
./build-push-harbor.sh

# Step 6: Deploy API
echo ""
echo -e "${BLUE}=== Step 6: Deploying KubeKloud API ===${NC}"
cd ..
./deploy.sh

echo ""
echo -e "${GREEN}============================================${NC}"
echo -e "${GREEN}Deployment Complete!${NC}"
echo -e "${GREEN}============================================${NC}"
echo ""

echo -e "${YELLOW}Access Information:${NC}"
echo ""
echo "Harbor Registry:"
echo "  URL: http://harbor.local:30002"
echo "  Username: admin"
echo "  Password: Harbor12345"
echo ""

# Get API service info
API_SERVICE=$(kubectl get svc kubekloud-api-service -n kubekloud-api -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "pending")
if [[ "$API_SERVICE" == "pending" ]] || [[ -z "$API_SERVICE" ]]; then
    echo "KubeKloud API (via port-forward):"
    echo "  kubectl port-forward -n kubekloud-api svc/kubekloud-api-service 8000:80"
    echo "  Then access: http://localhost:8000"
else
    echo "KubeKloud API:"
    echo "  URL: http://$API_SERVICE"
fi

echo ""
echo -e "${YELLOW}Useful Commands:${NC}"
echo "View Harbor status:  kubectl get all -n harbor-system"
echo "View API status:     kubectl get all -n kubekloud-api"
echo "View API logs:       kubectl logs -n kubekloud-api -l app=kubekloud-api -f"
echo "Update image:        ./build-push-harbor.sh && kubectl rollout restart deployment kubekloud-api -n kubekloud-api"
echo ""

