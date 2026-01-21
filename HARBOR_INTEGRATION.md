# Harbor Integration Guide

This document explains how to use the local Harbor registry with KubeKloud API.

## Overview

The KubeKloud API is now configured to use Harbor, a local container registry running in the same Kubernetes cluster. This eliminates the need for an external Docker registry like Docker Hub or Google Container Registry.

## Architecture

```
┌─────────────────────────────────────────────────────┐
│              Kubernetes Cluster                     │
│                                                     │
│  ┌────────────────────────────────────────────┐   │
│  │  Harbor Registry (harbor-system namespace)  │   │
│  │  - Stores container images                  │   │
│  │  - Scans for vulnerabilities                │   │
│  │  - Manages access control                   │   │
│  └───────────────┬────────────────────────────┘   │
│                  │ Pulls images                    │
│                  ▼                                  │
│  ┌────────────────────────────────────────────┐   │
│  │  KubeKloud API (kubekloud-api namespace)   │   │
│  │  - Uses images from local Harbor           │   │
│  │  - No external registry needed              │   │
│  └────────────────────────────────────────────┘   │
│                                                     │
└─────────────────────────────────────────────────────┘
```

## Files Structure

```
k8s/
├── harbor/
│   ├── namespace.yaml              # Harbor namespace
│   ├── values.yaml                 # Helm chart configuration
│   ├── setup-harbor.sh             # Install Harbor
│   ├── configure-harbor.sh         # Configure project & robot account
│   ├── deploy-with-harbor.sh       # Complete setup script
│   ├── build-push-harbor.sh        # Build & push to Harbor
│   ├── HARBOR_SETUP.md            # Detailed setup guide
│   └── QUICKSTART.md              # Quick start guide
├── api-deployment.yaml            # Updated with Harbor image
└── configmap.yaml                 # Updated with Harbor config
```

## Quick Setup

### Option 1: Automated (Recommended)

Run the all-in-one script:

```bash
cd k8s/harbor
./deploy-with-harbor.sh
```

This script will:
1. Install Harbor via Helm
2. Configure Harbor (create project, robot account)
3. Guide you through Docker configuration
4. Build and push the API image
5. Deploy the API

### Option 2: Step-by-Step

```bash
# 1. Install Harbor
cd k8s/harbor
./setup-harbor.sh

# 2. Configure Harbor
./configure-harbor.sh

# 3. Configure Docker for insecure registry
# Edit /etc/docker/daemon.json:
{
  "insecure-registries": ["harbor.local:30002"]
}
# Restart Docker

# 4. Add to /etc/hosts
echo "<NODE_IP> harbor.local" | sudo tee -a /etc/hosts

# 5. Build and push image
./build-push-harbor.sh

# 6. Deploy API
cd ..
./deploy.sh
```

## Configuration Details

### Harbor Settings

- **Namespace:** `harbor-system`
- **URL:** `http://harbor.local:30002` (NodePort)
- **Admin Credentials:** admin / Harbor12345
- **Project:** `kubekloud`
- **Storage:** 20Gi for images, 5Gi for database

### API Configuration

The API deployment is configured to:
- Pull images from: `harbor.local:30002/kubekloud/kubekloud-api:latest`
- Use `harbor-regcred` secret for authentication
- Run with Harbor configuration in ConfigMap

### Updated Manifests

**api-deployment.yaml:**
```yaml
spec:
  imagePullSecrets:
  - name: harbor-regcred
  containers:
  - name: api
    image: harbor.local:30002/kubekloud/kubekloud-api:latest
```

**configmap.yaml:**
```yaml
data:
  HARBOR_URL: "harbor.local:30002"
  HARBOR_PROJECT: "kubekloud"
```

## Image Management

### Build New Version

```bash
cd k8s/harbor
./build-push-harbor.sh
```

This will:
1. Build the Docker image
2. Tag it for Harbor
3. Push to Harbor registry
4. Display verification commands

### Update Running Deployment

```bash
# After pushing new image
kubectl rollout restart deployment kubekloud-api -n kubekloud-api

# Watch the rollout
kubectl rollout status deployment kubekloud-api -n kubekloud-api
```

### Tag Specific Versions

```bash
# Build with specific tag
cd k8s/harbor
IMAGE_TAG=v1.0.0 ./build-push-harbor.sh

# Or manually tag
docker build -t harbor.local:30002/kubekloud/kubekloud-api:v1.0.0 .
docker push harbor.local:30002/kubekloud/kubekloud-api:v1.0.0

# Update deployment to use specific version
kubectl set image deployment/kubekloud-api \
  api=harbor.local:30002/kubekloud/kubekloud-api:v1.0.0 \
  -n kubekloud-api
```

## Security

### ImagePullSecret

The deployment uses `harbor-regcred` secret created by the configuration script:

```bash
# View secret
kubectl get secret harbor-regcred -n kubekloud-api

# Recreate if needed
kubectl create secret docker-registry harbor-regcred \
  --docker-server=harbor.local:30002 \
  --docker-username=robot\$kubekloud-api-robot \
  --docker-password=<robot-token> \
  -n kubekloud-api
```

### Robot Accounts

Robot accounts are service accounts for automated operations:

- **Name:** `robot$kubekloud-api-robot`
- **Permissions:** Pull & Push to kubekloud project
- **Expiration:** Never (configurable)

Created automatically by `configure-harbor.sh`

### Vulnerability Scanning

Harbor includes Trivy for vulnerability scanning:

1. Access Harbor UI
2. Go to Projects → kubekloud → Repositories
3. Click on an image
4. View vulnerability scan results

Enable automatic scanning in project settings.

## Production Considerations

### Use LoadBalancer or Ingress

Change Harbor exposure from NodePort:

```bash
helm upgrade harbor harbor/harbor \
  --namespace harbor-system \
  --reuse-values \
  --set expose.type=loadBalancer
```

Or configure Ingress with proper domain.

### Enable HTTPS

```bash
helm upgrade harbor harbor/harbor \
  --namespace harbor-system \
  --reuse-values \
  --set expose.tls.enabled=true \
  --set expose.tls.certSource=auto
```

### Increase Storage

```bash
helm upgrade harbor harbor/harbor \
  --namespace harbor-system \
  --reuse-values \
  --set persistence.persistentVolumeClaim.registry.size=100Gi
```

### Enable Replication

For multi-cluster setups, configure replication:
1. Access Harbor UI
2. Go to Administration → Replications
3. Add replication endpoints and rules

### Backup Strategy

Backup Harbor regularly:

```bash
# Database backup
kubectl exec -n harbor-system harbor-database-0 -- \
  pg_dumpall -U postgres > harbor-backup.sql

# Registry data backup (copy PVC data)
# Use Velero or similar tools
```

## Troubleshooting

### Cannot Push to Harbor

**Issue:** `unauthorized: unauthorized to access repository`

**Solution:**
```bash
# Re-login to Harbor
docker login harbor.local:30002

# Check Docker daemon config
docker info | grep "Insecure Registries"
```

### ImagePullBackOff

**Issue:** Pods can't pull images from Harbor

**Solution:**
```bash
# Check secret exists
kubectl get secret harbor-regcred -n kubekloud-api

# Check secret is valid
kubectl describe secret harbor-regcred -n kubekloud-api

# Recreate secret
cd k8s/harbor
./configure-harbor.sh
```

### Harbor Pods Not Running

**Issue:** Harbor components failing to start

**Solution:**
```bash
# Check pod status
kubectl get pods -n harbor-system

# Describe failed pod
kubectl describe pod -n harbor-system <pod-name>

# Check resources
kubectl top nodes

# Common fix: Increase cluster resources
# Harbor needs ~4GB RAM and 2 CPUs
```

### DNS Resolution Issues

**Issue:** Cannot resolve `harbor.local`

**Solution:**
```bash
# Verify /etc/hosts entry
cat /etc/hosts | grep harbor

# Add if missing
NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[0].address}')
echo "$NODE_IP harbor.local" | sudo tee -a /etc/hosts

# Or use IP directly
docker build -t $NODE_IP:30002/kubekloud/kubekloud-api:latest .
```

## Monitoring

### Check Harbor Health

```bash
# API health
curl http://harbor.local:30002/api/v2.0/systeminfo

# Component status
kubectl get pods -n harbor-system

# Resource usage
kubectl top pods -n harbor-system
```

### View Logs

```bash
# All Harbor logs
kubectl logs -n harbor-system -l app=harbor --tail=100

# Specific component
kubectl logs -n harbor-system -l component=core -f
```

### Metrics

Enable Prometheus metrics:

```bash
helm upgrade harbor harbor/harbor \
  --namespace harbor-system \
  --reuse-values \
  --set metrics.enabled=true
```

## Maintenance

### Upgrade Harbor

```bash
# Update Helm repo
helm repo update

# Upgrade Harbor
helm upgrade harbor harbor/harbor \
  --namespace harbor-system \
  --values k8s/harbor/values.yaml
```

### Clean Old Images

1. Access Harbor UI
2. Go to Projects → kubekloud → Repositories
3. Select repository
4. Delete old tags

Or configure retention policy:
1. Projects → kubekloud → Policy
2. Add Tag Retention Rule
3. Example: Keep last 10 versions

### Garbage Collection

Run garbage collection to free space:

1. Harbor UI → Administration → Garbage Collection
2. Click "GC NOW" or schedule

## Migration from External Registry

If migrating from Docker Hub or other registry:

```bash
# Pull image from external registry
docker pull your-registry/kubekloud-api:latest

# Re-tag for Harbor
docker tag your-registry/kubekloud-api:latest \
  harbor.local:30002/kubekloud/kubekloud-api:latest

# Push to Harbor
docker push harbor.local:30002/kubekloud/kubekloud-api:latest

# Update deployment (already done in api-deployment.yaml)
```

## Resources

- **Harbor Documentation:** https://goharbor.io/docs/
- **Helm Chart:** https://github.com/goharbor/harbor-helm
- **Quick Start:** `k8s/harbor/QUICKSTART.md`
- **Detailed Setup:** `k8s/harbor/HARBOR_SETUP.md`

## Summary

**Benefits of Local Harbor:**
- ✅ No external registry fees
- ✅ Faster image pulls (local network)
- ✅ Built-in vulnerability scanning
- ✅ Fine-grained access control
- ✅ Image signing and trust
- ✅ Complete control over images

**Components:**
- Harbor registry in `harbor-system` namespace
- API using Harbor images in `kubekloud-api` namespace
- Automated scripts for setup and builds
- imagePullSecret for authentication

**Key Commands:**
```bash
# Setup
cd k8s/harbor && ./deploy-with-harbor.sh

# Build & push
cd k8s/harbor && ./build-push-harbor.sh

# Update deployment
kubectl rollout restart deployment kubekloud-api -n kubekloud-api

# Access Harbor
open http://harbor.local:30002
```

Enjoy your self-hosted container registry! 🚀

