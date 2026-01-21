# Harbor Container Registry Setup Guide

This guide helps you deploy Harbor container registry in your Kubernetes cluster and configure the KubeKloud API to use it.

## What is Harbor?

Harbor is an open-source container registry that secures artifacts with policies and role-based access control, ensures images are scanned and free from vulnerabilities, and signs images as trusted.

## Architecture

```
┌─────────────────────────────────────────────────────┐
│           Kubernetes Cluster                        │
│                                                     │
│  ┌──────────────────────────────────────────────┐  │
│  │  Namespace: harbor-system                    │  │
│  │  ┌────────────────────────────────────────┐  │  │
│  │  │  Harbor Components:                    │  │  │
│  │  │  - Core API                            │  │  │
│  │  │  - Registry (image storage)            │  │  │
│  │  │  - Portal (Web UI)                     │  │  │
│  │  │  - PostgreSQL Database                 │  │  │
│  │  │  - Redis Cache                         │  │  │
│  │  │  - Trivy (vulnerability scanner)       │  │  │
│  │  └────────────────────────────────────────┘  │  │
│  └──────────────────────────────────────────────┘  │
│                       ▲                             │
│                       │                             │
│  ┌──────────────────────────────────────────────┐  │
│  │  Namespace: kubekloud-api                    │  │
│  │  ┌────────────────────────────────────────┐  │  │
│  │  │  API Pods (pull images from Harbor)    │  │  │
│  │  └────────────────────────────────────────┘  │  │
│  └──────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────┘
```

## Prerequisites

- Kubernetes cluster v1.20+
- kubectl configured
- Helm 3.x installed (recommended method)
- At least 4GB RAM and 2 CPU cores available
- 32Gi+ storage for Harbor data

## Installation Methods

### Method 1: Helm Installation (Recommended)

This is the easiest and most maintainable approach.

#### Step 1: Install Helm (if not already installed)

```bash
# macOS
brew install helm

# Linux
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# Windows (with Chocolatey)
choco install kubernetes-helm

# Verify installation
helm version
```

#### Step 2: Add Harbor Helm Repository

```bash
helm repo add harbor https://helm.goharbor.io
helm repo update
```

#### Step 3: Create Namespace

```bash
kubectl create namespace harbor-system
```

#### Step 4: Install Harbor

**Option A: Quick Install (Development)**

```bash
helm install harbor harbor/harbor \
  --namespace harbor-system \
  --set expose.type=nodePort \
  --set expose.tls.enabled=false \
  --set harborAdminPassword=Harbor12345 \
  --set persistence.persistentVolumeClaim.registry.size=20Gi
```

**Option B: Production Install (with custom values)**

```bash
# Use the provided values.yaml
helm install harbor harbor/harbor \
  --namespace harbor-system \
  --values k8s/harbor/values.yaml
```

#### Step 5: Wait for Harbor to be Ready

```bash
# Watch pods until all are running
kubectl get pods -n harbor-system -w

# Check all components
kubectl get all -n harbor-system
```

This usually takes 3-5 minutes.

#### Step 6: Access Harbor UI

**With NodePort (default):**

```bash
# Get the NodePort
kubectl get svc -n harbor-system

# Access Harbor at:
# http://<any-node-ip>:30002

# Or use port-forward for testing
kubectl port-forward -n harbor-system svc/harbor-portal 8080:80

# Access at: http://localhost:8080
```

**Default Credentials:**
- Username: `admin`
- Password: `Harbor12345` (or what you set)

### Method 2: Manual Manifests (Advanced)

For users who prefer not to use Helm, we provide basic manifests. However, this is more complex and less flexible.

See `HARBOR_MANUAL.md` for manual installation instructions.

## Post-Installation Configuration

### Step 1: Login to Harbor

1. Access Harbor UI at the exposed URL
2. Login with admin credentials
3. Change the admin password immediately!

### Step 2: Create a Project

Harbor organizes images into projects. Create a project for KubeKloud:

**Via UI:**
1. Click "NEW PROJECT"
2. Project Name: `kubekloud`
3. Access Level: Private
4. Click "OK"

**Via CLI (using Harbor API):**

```bash
# Set variables
HARBOR_URL="http://harbor.local:30002"  # Update with your Harbor URL
HARBOR_USER="admin"
HARBOR_PASSWORD="Harbor12345"

# Create project
curl -X POST "${HARBOR_URL}/api/v2.0/projects" \
  -u "${HARBOR_USER}:${HARBOR_PASSWORD}" \
  -H "Content-Type: application/json" \
  -d '{
    "project_name": "kubekloud",
    "public": false
  }'
```

### Step 3: Create Robot Account (Recommended)

Robot accounts are service accounts for automated image pulls.

**Via UI:**
1. Go to Projects → kubekloud
2. Click "Robot Accounts" tab
3. Click "NEW ROBOT ACCOUNT"
4. Name: `kubekloud-api-robot`
5. Expiration: Never (or set appropriate time)
6. Permissions: Pull & Push
7. Save the token securely!

**The token will be used for imagePullSecret**

### Step 4: Configure DNS/Hosts (Local Testing)

If using NodePort without a proper domain, add Harbor to your hosts file:

```bash
# Get any node IP
NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')

# Add to /etc/hosts (Linux/Mac)
echo "${NODE_IP} harbor.local" | sudo tee -a /etc/hosts

# Windows: Edit C:\Windows\System32\drivers\etc\hosts
# Add line: <NODE_IP> harbor.local
```

### Step 5: Configure Docker to Use Harbor

**If Harbor is using HTTP (not HTTPS):**

Edit Docker daemon configuration to allow insecure registry:

**Linux:**
```bash
sudo nano /etc/docker/daemon.json
```

**Mac (Docker Desktop):**
Preferences → Docker Engine

**Add:**
```json
{
  "insecure-registries": ["harbor.local:30002"]
}
```

**Restart Docker:**
```bash
# Linux
sudo systemctl restart docker

# Mac
# Restart Docker Desktop
```

### Step 6: Login to Harbor from Docker

```bash
docker login harbor.local:30002
# Username: admin
# Password: Harbor12345
```

## Build and Push KubeKloud API Image

Now build and push the KubeKloud API image to your Harbor registry:

```bash
# From the harbor directory
./build-push-harbor.sh

# Or manually:
cd /Users/ashikjm/opensource/kubekloud-api
docker build -t harbor.local:30002/kubekloud/kubekloud-api:latest .
docker push harbor.local:30002/kubekloud/kubekloud-api:latest
```

**Verify in Harbor UI:**
- Go to Projects → kubekloud → Repositories
- You should see `kubekloud-api`

## Configure Kubernetes to Pull from Harbor

### Option 1: Using Docker Config Secret

```bash
# Create secret from Docker config (after docker login)
kubectl create secret generic harbor-regcred \
  --from-file=.dockerconfigjson=$HOME/.docker/config.json \
  --type=kubernetes.io/dockerconfigjson \
  -n kubekloud-api
```

### Option 2: Using Username/Password

```bash
kubectl create secret docker-registry harbor-regcred \
  --docker-server=harbor.local:30002 \
  --docker-username=admin \
  --docker-password=Harbor12345 \
  --docker-email=admin@example.com \
  -n kubekloud-api
```

### Option 3: Using Robot Account (Recommended)

```bash
kubectl create secret docker-registry harbor-regcred \
  --docker-server=harbor.local:30002 \
  --docker-username=robot\$kubekloud-api-robot \
  --docker-password=<robot-account-token> \
  --docker-email=robot@example.com \
  -n kubekloud-api
```

## Update KubeKloud API Deployment

The API deployment has already been updated to use Harbor. See the changes in:
- `k8s/api-deployment.yaml` - Uses Harbor image and imagePullSecret
- `k8s/configmap.yaml` - Added Harbor configuration

## Deploy KubeKloud API

Now deploy the API using Harbor images:

```bash
cd k8s
./deploy.sh
```

The script will automatically use the Harbor registry configuration.

## Verification

### Check Harbor

```bash
# View images in Harbor
curl -u admin:Harbor12345 http://harbor.local:30002/api/v2.0/projects/kubekloud/repositories
```

### Check Kubernetes

```bash
# Check if pods are running
kubectl get pods -n kubekloud-api

# Check image pull events
kubectl describe pod -n kubekloud-api <pod-name> | grep -A 10 Events
```

### Test Image Pull

```bash
# Create a test pod
kubectl run test-harbor \
  --image=harbor.local:30002/kubekloud/kubekloud-api:latest \
  --image-pull-policy=Always \
  -n kubekloud-api

# Check if it pulled successfully
kubectl get pod test-harbor -n kubekloud-api

# Cleanup
kubectl delete pod test-harbor -n kubekloud-api
```

## Production Considerations

### 1. Use LoadBalancer or Ingress

Update Harbor to use LoadBalancer:

```bash
helm upgrade harbor harbor/harbor \
  --namespace harbor-system \
  --reuse-values \
  --set expose.type=loadBalancer
```

Or configure Ingress:

```yaml
expose:
  type: ingress
  ingress:
    hosts:
      core: harbor.yourdomain.com
    className: nginx
```

### 2. Enable HTTPS/TLS

```bash
helm upgrade harbor harbor/harbor \
  --namespace harbor-system \
  --reuse-values \
  --set expose.tls.enabled=true \
  --set expose.tls.certSource=secret \
  --set expose.tls.secret.secretName=harbor-tls
```

Create TLS secret with cert-manager or manually.

### 3. Configure Storage Class

Use a proper StorageClass for production:

```bash
helm upgrade harbor harbor/harbor \
  --namespace harbor-system \
  --reuse-values \
  --set persistence.persistentVolumeClaim.registry.storageClass=standard
```

### 4. Enable Vulnerability Scanning

Already enabled in our values.yaml. View scan results in Harbor UI.

### 5. Configure Backup

Set up automated backups for Harbor data:

```bash
# Backup Harbor database and registry data
kubectl exec -n harbor-system <harbor-database-pod> -- \
  pg_dump -U postgres registry > harbor-backup-$(date +%Y%m%d).sql
```

### 6. Enable Replication (Multi-cluster)

Configure replication in Harbor UI for disaster recovery.

### 7. Enable Metrics and Monitoring

```bash
helm upgrade harbor harbor/harbor \
  --namespace harbor-system \
  --reuse-values \
  --set metrics.enabled=true
```

## Troubleshooting

### Harbor pods not starting?

```bash
# Check pod status
kubectl get pods -n harbor-system

# Describe problematic pod
kubectl describe pod -n harbor-system <pod-name>

# Check persistent volume claims
kubectl get pvc -n harbor-system
```

### Cannot push images?

```bash
# Test Harbor connectivity
curl http://harbor.local:30002/api/v2.0/systeminfo

# Check Docker login
docker login harbor.local:30002

# Verify insecure-registries in Docker config
docker info | grep -A 5 "Insecure Registries"
```

### ImagePullBackOff in Kubernetes?

```bash
# Check secret exists
kubectl get secret harbor-regcred -n kubekloud-api

# Verify secret is correctly formatted
kubectl get secret harbor-regcred -n kubekloud-api -o yaml

# Check image name in deployment
kubectl get deployment kubekloud-api -n kubekloud-api -o yaml | grep image:

# Test manual pull
docker pull harbor.local:30002/kubekloud/kubekloud-api:latest
```

### Harbor UI not accessible?

```bash
# Check service
kubectl get svc -n harbor-system

# Port forward to test
kubectl port-forward -n harbor-system svc/harbor-portal 8080:80

# Check logs
kubectl logs -n harbor-system -l app=harbor -l component=portal
```

## Useful Commands

```bash
# Harbor status
helm status harbor -n harbor-system

# Harbor logs
kubectl logs -n harbor-system -l app=harbor --tail=100 -f

# List all Harbor services
kubectl get svc -n harbor-system

# Harbor resource usage
kubectl top pods -n harbor-system

# Upgrade Harbor
helm upgrade harbor harbor/harbor -n harbor-system -f values.yaml

# Uninstall Harbor
helm uninstall harbor -n harbor-system
```

## Scripts Provided

1. **`setup-harbor.sh`** - Automated Harbor installation
2. **`build-push-harbor.sh`** - Build and push to Harbor
3. **`configure-harbor.sh`** - Post-installation configuration

## Next Steps

1. ✅ Install Harbor using Helm
2. 🔐 Change default passwords
3. 📦 Create `kubekloud` project
4. 🤖 Set up robot account
5. 🐳 Build and push API image
6. 🔑 Create imagePullSecret
7. 🚀 Deploy API with Harbor images
8. 🔒 Enable HTTPS in production
9. 📊 Set up monitoring
10. 💾 Configure backups

## References

- [Harbor Documentation](https://goharbor.io/docs/)
- [Harbor Helm Chart](https://github.com/goharbor/harbor-helm)
- [Kubernetes Image Pull Secrets](https://kubernetes.io/docs/tasks/configure-pod-container/pull-image-private-registry/)

## Support

For issues with Harbor, check:
- Harbor logs: `kubectl logs -n harbor-system -l app=harbor`
- Harbor documentation: https://goharbor.io/docs/
- KubeKloud API integration issues: See main DEPLOYMENT.md

