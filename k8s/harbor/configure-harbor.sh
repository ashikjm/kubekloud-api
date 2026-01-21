#!/bin/bash

# Configure Harbor Post-Installation
# Creates project and robot account for KubeKloud API

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}======================================${NC}"
echo -e "${BLUE}Harbor Configuration${NC}"
echo -e "${BLUE}======================================${NC}"
echo ""

# Load configuration
if [[ -f "harbor-config.env" ]]; then
    source harbor-config.env
    echo -e "${GREEN}✓ Loaded Harbor configuration${NC}"
else
    echo -e "${YELLOW}Please provide Harbor details:${NC}"
    read -p "Harbor URL (e.g., harbor.local:30002): " HARBOR_URL
    read -p "Admin username [admin]: " HARBOR_ADMIN_USER
    HARBOR_ADMIN_USER=${HARBOR_ADMIN_USER:-admin}
    read -s -p "Admin password: " HARBOR_ADMIN_PASSWORD
    echo ""
    HARBOR_PROJECT="kubekloud"
fi

echo ""
echo -e "${YELLOW}Configuration:${NC}"
echo "  Harbor URL: $HARBOR_URL"
echo "  Project: $HARBOR_PROJECT"
echo ""

# Test Harbor connectivity
echo -e "${YELLOW}Testing Harbor connectivity...${NC}"
HEALTH=$(curl -s -o /dev/null -w "%{http_code}" http://${HARBOR_URL}/api/v2.0/systeminfo || echo "000")

if [[ "$HEALTH" == "200" ]]; then
    echo -e "${GREEN}✓ Harbor is reachable${NC}"
else
    echo -e "${RED}Error: Cannot reach Harbor at http://${HARBOR_URL}${NC}"
    echo "Make sure Harbor is running and accessible"
    exit 1
fi

# Create project
echo ""
echo -e "${YELLOW}Creating project '$HARBOR_PROJECT'...${NC}"

PROJECT_JSON='{
  "project_name": "'${HARBOR_PROJECT}'",
  "public": false,
  "metadata": {
    "auto_scan": "true",
    "severity": "high",
    "prevent_vul": "false"
  }
}'

CREATE_RESULT=$(curl -s -o /dev/null -w "%{http_code}" \
  -X POST "http://${HARBOR_URL}/api/v2.0/projects" \
  -u "${HARBOR_ADMIN_USER}:${HARBOR_ADMIN_PASSWORD}" \
  -H "Content-Type: application/json" \
  -d "$PROJECT_JSON")

if [[ "$CREATE_RESULT" == "201" ]]; then
    echo -e "${GREEN}✓ Project '$HARBOR_PROJECT' created${NC}"
elif [[ "$CREATE_RESULT" == "409" ]]; then
    echo -e "${YELLOW}⚠ Project '$HARBOR_PROJECT' already exists${NC}"
else
    echo -e "${RED}Error: Failed to create project (HTTP $CREATE_RESULT)${NC}"
    echo "You may need to create it manually in Harbor UI"
fi

# Get project ID
echo ""
echo -e "${YELLOW}Getting project ID...${NC}"
PROJECT_ID=$(curl -s -X GET "http://${HARBOR_URL}/api/v2.0/projects?name=${HARBOR_PROJECT}" \
  -u "${HARBOR_ADMIN_USER}:${HARBOR_ADMIN_PASSWORD}" \
  | grep -o '"project_id":[0-9]*' | head -1 | cut -d':' -f2)

if [[ ! -z "$PROJECT_ID" ]]; then
    echo -e "${GREEN}✓ Project ID: $PROJECT_ID${NC}"
else
    echo -e "${RED}Error: Could not get project ID${NC}"
    exit 1
fi

# Create robot account
echo ""
echo -e "${YELLOW}Creating robot account...${NC}"

ROBOT_NAME="kubekloud-api-robot"
ROBOT_JSON='{
  "name": "'${ROBOT_NAME}'",
  "description": "Robot account for KubeKloud API image pulls",
  "duration": -1,
  "level": "project",
  "permissions": [
    {
      "kind": "project",
      "namespace": "'${HARBOR_PROJECT}'",
      "access": [
        {
          "resource": "repository",
          "action": "pull"
        },
        {
          "resource": "repository",
          "action": "push"
        }
      ]
    }
  ]
}'

ROBOT_RESULT=$(curl -s -X POST "http://${HARBOR_URL}/api/v2.0/projects/${PROJECT_ID}/robots" \
  -u "${HARBOR_ADMIN_USER}:${HARBOR_ADMIN_PASSWORD}" \
  -H "Content-Type: application/json" \
  -d "$ROBOT_JSON")

ROBOT_SECRET=$(echo "$ROBOT_RESULT" | grep -o '"secret":"[^"]*"' | cut -d'"' -f4)
ROBOT_FULL_NAME=$(echo "$ROBOT_RESULT" | grep -o '"name":"[^"]*"' | cut -d'"' -f4)

if [[ ! -z "$ROBOT_SECRET" ]]; then
    echo -e "${GREEN}✓ Robot account created${NC}"
    echo ""
    echo -e "${YELLOW}Robot Account Details:${NC}"
    echo "  Name: $ROBOT_FULL_NAME"
    echo "  Secret: $ROBOT_SECRET"
    echo ""
    echo -e "${RED}⚠️  Save this secret! It won't be shown again.${NC}"
    
    # Save to file
    cat > harbor-robot-secret.txt <<EOF
# Harbor Robot Account for KubeKloud API
# Generated: $(date)

Robot Name: $ROBOT_FULL_NAME
Robot Secret: $ROBOT_SECRET
Harbor URL: $HARBOR_URL
Project: $HARBOR_PROJECT

# Use this to create Kubernetes secret:
kubectl create secret docker-registry harbor-regcred \\
  --docker-server=${HARBOR_URL} \\
  --docker-username='${ROBOT_FULL_NAME}' \\
  --docker-password='${ROBOT_SECRET}' \\
  --docker-email=robot@example.com \\
  -n kubekloud-api
EOF
    
    echo -e "${GREEN}Secret saved to: harbor-robot-secret.txt${NC}"
else
    echo -e "${YELLOW}⚠ Could not create robot account via API${NC}"
    echo "Please create it manually in Harbor UI:"
    echo "1. Go to Projects → $HARBOR_PROJECT"
    echo "2. Click 'Robot Accounts' tab"
    echo "3. Click 'NEW ROBOT ACCOUNT'"
    echo "4. Name: $ROBOT_NAME"
    echo "5. Expiration: Never"
    echo "6. Permissions: Pull & Push"
fi

# Create Kubernetes secret
echo ""
echo -e "${YELLOW}Do you want to create Kubernetes imagePullSecret now? (y/n)${NC}"
read -p "" -n 1 -r
echo ""

if [[ $REPLY =~ ^[Yy]$ ]]; then
    # Check if kubekloud-api namespace exists
    if ! kubectl get namespace kubekloud-api &> /dev/null; then
        echo "Creating kubekloud-api namespace..."
        kubectl create namespace kubekloud-api
    fi
    
    # Delete existing secret if exists
    kubectl delete secret harbor-regcred -n kubekloud-api 2>/dev/null || true
    
    if [[ ! -z "$ROBOT_SECRET" ]]; then
        # Use robot account
        kubectl create secret docker-registry harbor-regcred \
          --docker-server=${HARBOR_URL} \
          --docker-username="${ROBOT_FULL_NAME}" \
          --docker-password="${ROBOT_SECRET}" \
          --docker-email=robot@example.com \
          -n kubekloud-api
    else
        # Use admin credentials
        kubectl create secret docker-registry harbor-regcred \
          --docker-server=${HARBOR_URL} \
          --docker-username="${HARBOR_ADMIN_USER}" \
          --docker-password="${HARBOR_ADMIN_PASSWORD}" \
          --docker-email=admin@example.com \
          -n kubekloud-api
    fi
    
    echo -e "${GREEN}✓ Kubernetes secret 'harbor-regcred' created in kubekloud-api namespace${NC}"
fi

echo ""
echo -e "${GREEN}======================================${NC}"
echo -e "${GREEN}Harbor Configuration Complete!${NC}"
echo -e "${GREEN}======================================${NC}"
echo ""

echo -e "${YELLOW}Next Steps:${NC}"
echo "1. Build and push your image:"
echo "   ./build-push-harbor.sh"
echo ""
echo "2. Deploy the API:"
echo "   cd .. && ./deploy.sh"
echo ""

echo -e "${YELLOW}Access Harbor:${NC}"
echo "  URL: http://${HARBOR_URL}"
echo "  Username: ${HARBOR_ADMIN_USER}"
echo "  Project: ${HARBOR_PROJECT}"
echo ""

