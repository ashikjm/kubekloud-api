#!/bin/bash

# KubeKloud API Deployment Script
# This script deploys the KubeKloud API and PostgreSQL database to Kubernetes

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
NAMESPACE="kubekloud-api"
IMAGE_NAME="${IMAGE_NAME:-your-registry/kubekloud-api:latest}"

echo -e "${GREEN}======================================${NC}"
echo -e "${GREEN}KubeKloud API Deployment Script${NC}"
echo -e "${GREEN}======================================${NC}"
echo ""

# Check if kubectl is installed
if ! command -v kubectl &> /dev/null; then
    echo -e "${RED}Error: kubectl is not installed${NC}"
    exit 1
fi

# Check if connected to cluster
if ! kubectl cluster-info &> /dev/null; then
    echo -e "${RED}Error: Not connected to a Kubernetes cluster${NC}"
    exit 1
fi

echo -e "${YELLOW}Current cluster:${NC}"
kubectl cluster-info | head -1
echo ""

read -p "Do you want to continue with this cluster? (y/n) " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Deployment cancelled."
    exit 0
fi

# Check if image name needs to be updated
if [[ "$IMAGE_NAME" == "your-registry/kubekloud-api:latest" ]]; then
    echo ""
    echo -e "${YELLOW}Warning: Using default image name${NC}"
    echo "Current image: $IMAGE_NAME"
    read -p "Enter your Docker image (or press Enter to skip): " USER_IMAGE
    if [[ ! -z "$USER_IMAGE" ]]; then
        IMAGE_NAME="$USER_IMAGE"
        # Update the deployment file
        sed -i.bak "s|image: your-registry/kubekloud-api:latest|image: $IMAGE_NAME|g" api-deployment.yaml
        echo -e "${GREEN}Updated image in api-deployment.yaml${NC}"
    fi
fi

echo ""
echo -e "${YELLOW}Step 1: Creating namespace...${NC}"
kubectl apply -f namespace.yaml

echo ""
echo -e "${YELLOW}Step 2: Creating ConfigMap and Secrets...${NC}"
kubectl apply -f configmap.yaml
kubectl apply -f secret.yaml
echo -e "${RED}⚠️  Remember to update the password in secret.yaml for production!${NC}"

echo ""
echo -e "${YELLOW}Step 3: Setting up RBAC...${NC}"
kubectl apply -f serviceaccount.yaml

echo ""
echo -e "${YELLOW}Step 4: Deploying PostgreSQL...${NC}"
kubectl apply -f postgres-pvc.yaml
kubectl apply -f postgres-deployment.yaml
kubectl apply -f postgres-service.yaml

echo ""
echo -e "${YELLOW}Waiting for PostgreSQL to be ready...${NC}"
kubectl wait --for=condition=ready pod -l app=postgres -n $NAMESPACE --timeout=120s

echo ""
echo -e "${YELLOW}Step 5: Deploying API...${NC}"
kubectl apply -f api-deployment.yaml
kubectl apply -f api-service.yaml

echo ""
echo -e "${YELLOW}Waiting for API to be ready...${NC}"
kubectl wait --for=condition=ready pod -l app=kubekloud-api -n $NAMESPACE --timeout=120s

echo ""
echo -e "${GREEN}======================================${NC}"
echo -e "${GREEN}Deployment Complete!${NC}"
echo -e "${GREEN}======================================${NC}"
echo ""

echo "Deployment Status:"
kubectl get all -n $NAMESPACE

echo ""
echo -e "${YELLOW}Access Instructions:${NC}"
echo ""

# Check service type
SERVICE_TYPE=$(kubectl get svc kubekloud-api-service -n $NAMESPACE -o jsonpath='{.spec.type}')

if [[ "$SERVICE_TYPE" == "LoadBalancer" ]]; then
    echo "Waiting for LoadBalancer IP..."
    sleep 5
    EXTERNAL_IP=$(kubectl get svc kubekloud-api-service -n $NAMESPACE -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
    if [[ -z "$EXTERNAL_IP" ]]; then
        EXTERNAL_IP=$(kubectl get svc kubekloud-api-service -n $NAMESPACE -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
    fi
    
    if [[ ! -z "$EXTERNAL_IP" ]]; then
        echo -e "${GREEN}API URL: http://$EXTERNAL_IP${NC}"
        echo -e "${GREEN}API Docs: http://$EXTERNAL_IP/docs${NC}"
    else
        echo -e "${YELLOW}LoadBalancer IP pending... Run this to get the IP:${NC}"
        echo "kubectl get svc kubekloud-api-service -n $NAMESPACE"
    fi
else
    echo -e "${YELLOW}Use port-forward to access the API:${NC}"
    echo "kubectl port-forward -n $NAMESPACE svc/kubekloud-api-service 8000:80"
    echo ""
    echo "Then access:"
    echo -e "${GREEN}API URL: http://localhost:8000${NC}"
    echo -e "${GREEN}API Docs: http://localhost:8000/docs${NC}"
fi

echo ""
echo -e "${YELLOW}Useful Commands:${NC}"
echo "View logs:    kubectl logs -n $NAMESPACE -l app=kubekloud-api --tail=50 -f"
echo "View pods:    kubectl get pods -n $NAMESPACE"
echo "Describe pod: kubectl describe pod -n $NAMESPACE <pod-name>"
echo "Shell access: kubectl exec -it -n $NAMESPACE <pod-name> -- /bin/bash"
echo ""
echo "To delete deployment:"
echo "kubectl delete namespace $NAMESPACE"
echo ""

