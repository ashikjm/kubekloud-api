# Docker Build and Push Guide

This guide helps you build and push the KubeKloud API Docker image to your container registry.

## Prerequisites

1. Docker installed and running
2. Access to a container registry (Docker Hub, GCR, ECR, etc.)
3. Docker logged in to your registry

## Quick Start

### 1. Choose Your Registry

**Docker Hub:**
```bash
REGISTRY="docker.io/your-username"
```

**Google Container Registry:**
```bash
REGISTRY="gcr.io/your-project-id"
```

**AWS ECR:**
```bash
REGISTRY="123456789.dkr.ecr.us-east-1.amazonaws.com"
```

**Azure ACR:**
```bash
REGISTRY="yourregistry.azurecr.io"
```

### 2. Build the Image

```bash
# Set variables
export IMAGE_NAME="kubekloud-api"
export IMAGE_TAG="latest"  # or use version like "v1.0.0"
export FULL_IMAGE="${REGISTRY}/${IMAGE_NAME}:${IMAGE_TAG}"

# Build from project root
cd ..  # Go to project root if you're in k8s/ directory
docker build -t ${FULL_IMAGE} .

# Verify the build
docker images | grep kubekloud-api
```

### 3. Test Locally (Optional)

```bash
# Run the container
docker run -d \
  --name kubekloud-api-test \
  -p 8000:8000 \
  -e DATABASE_URL="sqlite:///./cmp.db" \
  ${FULL_IMAGE}

# Check if it's running
curl http://localhost:8000/health

# View logs
docker logs kubekloud-api-test

# Stop and remove
docker stop kubekloud-api-test
docker rm kubekloud-api-test
```

### 4. Login to Registry

**Docker Hub:**
```bash
docker login
# Enter username and password
```

**Google Container Registry:**
```bash
gcloud auth configure-docker
```

**AWS ECR:**
```bash
aws ecr get-login-password --region us-east-1 | \
  docker login --username AWS --password-stdin ${REGISTRY}
```

**Azure ACR:**
```bash
az acr login --name yourregistry
```

### 5. Push the Image

```bash
docker push ${FULL_IMAGE}

# Verify the push
docker pull ${FULL_IMAGE}
```

### 6. Update Kubernetes Deployment

Edit `k8s/api-deployment.yaml` and update the image:

```yaml
spec:
  containers:
  - name: api
    image: your-registry/kubekloud-api:latest  # Update this line
```

## Multi-Architecture Builds (Optional)

For ARM and AMD64 support (e.g., Apple Silicon + Linux servers):

```bash
# Create and use buildx builder
docker buildx create --name multiarch --use
docker buildx inspect --bootstrap

# Build and push multi-arch image
docker buildx build \
  --platform linux/amd64,linux/arm64 \
  -t ${FULL_IMAGE} \
  --push \
  .
```

## Best Practices

### 1. Use Specific Tags

Instead of `latest`, use version tags:

```bash
export IMAGE_TAG="v1.0.0"
docker build -t ${REGISTRY}/${IMAGE_NAME}:${IMAGE_TAG} .
docker push ${REGISTRY}/${IMAGE_NAME}:${IMAGE_TAG}
```

### 2. Tag Git Commits

```bash
export GIT_COMMIT=$(git rev-parse --short HEAD)
docker build -t ${REGISTRY}/${IMAGE_NAME}:${GIT_COMMIT} .
docker push ${REGISTRY}/${IMAGE_NAME}:${GIT_COMMIT}
```

### 3. Build with CI/CD

Example GitHub Actions workflow:

```yaml
name: Build and Push

on:
  push:
    branches: [main]
    tags: ['v*']

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Login to Docker Hub
        uses: docker/login-action@v2
        with:
          username: ${{ secrets.DOCKER_USERNAME }}
          password: ${{ secrets.DOCKER_PASSWORD }}
      
      - name: Build and push
        uses: docker/build-push-action@v4
        with:
          context: .
          push: true
          tags: |
            your-registry/kubekloud-api:latest
            your-registry/kubekloud-api:${{ github.sha }}
```

## Security Considerations

### 1. Scan Image for Vulnerabilities

```bash
# Using Docker Scout
docker scout cves ${FULL_IMAGE}

# Using Trivy
trivy image ${FULL_IMAGE}

# Using Snyk
snyk container test ${FULL_IMAGE}
```

### 2. Use Private Registry

- Don't use public registries for production
- Use registry with access controls
- Implement image signing

### 3. Image Pull Secrets (Private Registry)

Create a secret for Kubernetes:

```bash
kubectl create secret docker-registry regcred \
  --docker-server=${REGISTRY} \
  --docker-username=<your-username> \
  --docker-password=<your-password> \
  --docker-email=<your-email> \
  -n kubekloud-api
```

Update `api-deployment.yaml`:

```yaml
spec:
  imagePullSecrets:
  - name: regcred
  containers:
  - name: api
    image: your-private-registry/kubekloud-api:latest
```

## Troubleshooting

### Build fails?

```bash
# Check Dockerfile syntax
docker build --no-cache -t test .

# Check build logs
docker build --progress=plain -t test .
```

### Push fails?

```bash
# Verify authentication
docker login ${REGISTRY}

# Check image size
docker images ${FULL_IMAGE}

# Retry with explicit registry
docker push ${FULL_IMAGE}
```

### Image pull fails in Kubernetes?

```bash
# Check image name
kubectl describe pod <pod-name> -n kubekloud-api

# Verify image exists
docker pull ${FULL_IMAGE}

# Check imagePullSecrets
kubectl get secret regcred -n kubekloud-api
```

## Complete Build Script

Save as `build-and-push.sh`:

```bash
#!/bin/bash
set -e

# Configuration
REGISTRY="${REGISTRY:-docker.io/your-username}"
IMAGE_NAME="kubekloud-api"
VERSION="${VERSION:-$(git describe --tags --always --dirty)}"

# Build
echo "Building ${REGISTRY}/${IMAGE_NAME}:${VERSION}..."
docker build -t ${REGISTRY}/${IMAGE_NAME}:${VERSION} .
docker tag ${REGISTRY}/${IMAGE_NAME}:${VERSION} ${REGISTRY}/${IMAGE_NAME}:latest

# Push
echo "Pushing images..."
docker push ${REGISTRY}/${IMAGE_NAME}:${VERSION}
docker push ${REGISTRY}/${IMAGE_NAME}:latest

echo "Done! Images pushed:"
echo "  - ${REGISTRY}/${IMAGE_NAME}:${VERSION}"
echo "  - ${REGISTRY}/${IMAGE_NAME}:latest"
```

Make it executable:
```bash
chmod +x build-and-push.sh
```

Run it:
```bash
export REGISTRY="your-registry"
./build-and-push.sh
```

## Next Steps

After building and pushing:

1. Update `k8s/api-deployment.yaml` with your image
2. Deploy to Kubernetes: `cd k8s && ./deploy.sh`
3. Monitor the deployment: `kubectl get pods -n kubekloud-api -w`

For deployment instructions, see [DEPLOYMENT.md](../DEPLOYMENT.md)

