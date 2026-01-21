# Harbor Quick Start Guide

This is a simplified guide to get Harbor and KubeKloud API running quickly.

## 🚀 Complete Setup in 5 Steps

### Step 1: Install Harbor

```bash
cd k8s/harbor
./setup-harbor.sh
```

This will:
- Install Helm (if needed)
- Deploy Harbor to your cluster
- Wait for all components to be ready
- Show you the access URL

**Time:** ~5 minutes

### Step 2: Configure Harbor

```bash
./configure-harbor.sh
```

This will:
- Create the `kubekloud` project
- Create a robot account for image pulls
- Create Kubernetes imagePullSecret

**Time:** ~1 minute

### Step 3: Add Harbor to /etc/hosts

```bash
# Get your node IP
NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')

# Add to /etc/hosts
echo "$NODE_IP harbor.local" | sudo tee -a /etc/hosts
```

### Step 4: Configure Docker for Harbor

**Linux/Mac:**

Edit `/etc/docker/daemon.json`:
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
# Restart Docker Desktop from the menu
```

### Step 5: Build, Push, and Deploy

```bash
# Build and push to Harbor (from harbor directory)
./build-push-harbor.sh

# Deploy the API
cd ..
./deploy.sh
```

**Time:** ~3 minutes

## ✅ Verification

Check Harbor:
```bash
# Access Harbor UI
open http://harbor.local:30002

# Login: admin / Harbor12345
# Navigate to: Projects → kubekloud → Repositories
```

Check Kubernetes:
```bash
# Check API pods
kubectl get pods -n kubekloud-api

# Check if image was pulled successfully
kubectl describe pod -n kubekloud-api <pod-name> | grep -A 5 "Events"
```

## 🎯 Access Your API

```bash
# Get service URL
kubectl get svc kubekloud-api-service -n kubekloud-api

# Or use port-forward
kubectl port-forward -n kubekloud-api svc/kubekloud-api-service 8000:80

# Access:
# - API: http://localhost:8000
# - Docs: http://localhost:8000/docs
```

## 🔧 Troubleshooting

### Harbor pods not starting?

```bash
kubectl get pods -n harbor-system
kubectl describe pod -n harbor-system <pod-name>
```

**Common issue:** Insufficient resources
- Harbor needs ~4GB RAM and 2 CPUs
- Check: `kubectl top nodes`

### Cannot push to Harbor?

```bash
# Check Docker config
docker info | grep -A 5 "Insecure Registries"

# Should show: harbor.local:30002

# Test login
docker login harbor.local:30002
```

### ImagePullBackOff?

```bash
# Check secret exists
kubectl get secret harbor-regcred -n kubekloud-api

# Recreate if needed
kubectl delete secret harbor-regcred -n kubekloud-api
cd harbor
./configure-harbor.sh
```

### Harbor UI not accessible?

```bash
# Check Harbor service
kubectl get svc -n harbor-system

# Use port-forward
kubectl port-forward -n harbor-system svc/harbor-portal 8080:80
# Access: http://localhost:8080
```

## 📋 Default Credentials

**Harbor:**
- URL: http://harbor.local:30002
- Username: `admin`
- Password: `Harbor12345`

**⚠️ Change the password after first login!**

## 🔄 Update Process

When you make changes to your API:

```bash
# 1. Build and push new image
cd k8s/harbor
./build-push-harbor.sh

# 2. Restart API pods to pull new image
kubectl rollout restart deployment kubekloud-api -n kubekloud-api

# 3. Watch the rollout
kubectl rollout status deployment kubekloud-api -n kubekloud-api
```

## 🗑️ Cleanup

Remove everything:

```bash
# Delete API
kubectl delete namespace kubekloud-api

# Delete Harbor
helm uninstall harbor -n harbor-system
kubectl delete namespace harbor-system
kubectl delete pvc --all -n harbor-system
```

## 📚 More Information

- Detailed Harbor setup: `HARBOR_SETUP.md`
- API deployment guide: `../DEPLOYMENT.md`
- Harbor documentation: https://goharbor.io/docs/

## 💡 Tips

1. **For production:** Enable HTTPS and use proper domain
2. **For security:** Use robot accounts instead of admin
3. **For performance:** Adjust resource limits based on usage
4. **For reliability:** Set up automated backups

## Next Steps

- ✅ Harbor deployed and configured
- ✅ API image built and pushed
- ✅ API deployed and running
- 🔐 Change Harbor admin password
- 🌐 Set up Ingress for production
- 📊 Configure monitoring
- 💾 Set up backups

