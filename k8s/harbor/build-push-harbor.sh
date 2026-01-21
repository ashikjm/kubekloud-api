#!/bin/bash

# Build and Push KubeKloud API to Harbor
# This script builds the Docker image and pushes it to your local Harbor registry

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}======================================${NC}"
echo -e "${BLUE}Build & Push to Harbor${NC}"
echo -e "${BLUE}======================================${NC}"
echo ""

# Load configuration if exists
if [[ -f "harbor/harbor-config.env" ]]; then
    source harbor/harbor-config.env
    echo -e "${GREEN}✓ Loaded Harbor configuration${NC}"
else
    echo -e "${YELLOW}Harbor config not found. Using defaults...${NC}"
    HARBOR_URL="${HARBOR_URL:-harbor.local:30002}"
    HARBOR_PROJECT="${HARBOR_PROJECT:-kubekloud}"
fi

# Configuration
IMAGE_NAME="kubekloud-api"
IMAGE_TAG="${IMAGE_TAG:-latest}"
FULL_IMAGE="${HARBOR_URL}/${HARBOR_PROJECT}/${IMAGE_NAME}:${IMAGE_TAG}"

echo ""
echo -e "${YELLOW}Configuration:${NC}"
echo "  Harbor URL: $HARBOR_URL"
echo "  Project: $HARBOR_PROJECT"
echo "  Image: $IMAGE_NAME"
echo "  Tag: $IMAGE_TAG"
echo "  Full Image: $FULL_IMAGE"
echo ""

# Check Docker
if ! command -v docker &> /dev/null; then
    echo -e "${RED}Error: Docker is not installed${NC}"
    exit 1
fi

# Check Docker daemon
if ! docker info &> /dev/null; then
    echo -e "${RED}Error: Docker daemon is not running${NC}"
    exit 1
fi

# Check if logged in to Harbor
echo -e "${YELLOW}Checking Docker login to Harbor...${NC}"
if ! docker login $HARBOR_URL --username admin --password-stdin <<< "${HARBOR_ADMIN_PASSWORD:-Harbor12345}" 2>/dev/null; then
    echo ""
    echo -e "${YELLOW}Please login to Harbor:${NC}"
    docker login $HARBOR_URL
fi

echo -e "${GREEN}✓ Logged in to Harbor${NC}"
echo ""

# Navigate to project root (two levels up from harbor directory)
cd "$(dirname "$0")/../.."
PROJECT_ROOT=$(pwd)

echo -e "${YELLOW}Building Docker image...${NC}"
echo "Location: $PROJECT_ROOT"
echo ""

# Build the image
docker build -t $FULL_IMAGE .

if [[ $? -eq 0 ]]; then
    echo ""
    echo -e "${GREEN}✓ Image built successfully${NC}"
else
    echo -e "${RED}Error: Failed to build image${NC}"
    exit 1
fi

# Check image size
IMAGE_SIZE=$(docker images $FULL_IMAGE --format "{{.Size}}")
echo "Image size: $IMAGE_SIZE"
echo ""

# Push to Harbor
echo -e "${YELLOW}Pushing image to Harbor...${NC}"
docker push $FULL_IMAGE

if [[ $? -eq 0 ]]; then
    echo ""
    echo -e "${GREEN}✓ Image pushed successfully${NC}"
else
    echo -e "${RED}Error: Failed to push image${NC}"
    exit 1
fi

echo ""
echo -e "${GREEN}======================================${NC}"
echo -e "${GREEN}Build & Push Complete!${NC}"
echo -e "${GREEN}======================================${NC}"
echo ""

echo -e "${YELLOW}Image Details:${NC}"
echo "  Repository: $HARBOR_URL/$HARBOR_PROJECT/$IMAGE_NAME"
echo "  Tag: $IMAGE_TAG"
echo "  Full Image: $FULL_IMAGE"
echo ""

echo -e "${YELLOW}Verify in Harbor UI:${NC}"
echo "  URL: http://$HARBOR_URL"
echo "  Navigate to: Projects → $HARBOR_PROJECT → Repositories"
echo ""

echo -e "${YELLOW}Next Steps:${NC}"
echo "1. Verify image in Harbor UI"
echo "2. Create imagePullSecret if not exists:"
echo "   kubectl create secret docker-registry harbor-regcred \\"
echo "     --docker-server=$HARBOR_URL \\"
echo "     --docker-username=admin \\"
echo "     --docker-password=<your-password> \\"
echo "     -n kubekloud-api"
echo ""
echo "3. Deploy the API:"
echo "   cd ../k8s && ./deploy.sh"
echo ""

# Tag additional versions if needed
if [[ ! -z "$GIT_COMMIT" ]]; then
    GIT_TAG="${HARBOR_URL}/${HARBOR_PROJECT}/${IMAGE_NAME}:${GIT_COMMIT}"
    echo -e "${YELLOW}Tagging with git commit: $GIT_COMMIT${NC}"
    docker tag $FULL_IMAGE $GIT_TAG
    docker push $GIT_TAG
    echo -e "${GREEN}✓ Also pushed: $GIT_TAG${NC}"
    echo ""
fi

