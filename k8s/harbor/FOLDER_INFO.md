# Harbor Directory

This directory contains all Harbor-related files for setting up a local container registry in your Kubernetes cluster.

## 📁 Contents

### Scripts (All Executable)
- **`setup-harbor.sh`** - Install Harbor using Helm
- **`configure-harbor.sh`** - Configure Harbor (create project, robot account, secrets)
- **`deploy-with-harbor.sh`** - Complete end-to-end setup (Harbor + API)
- **`build-push-harbor.sh`** - Build Docker image and push to Harbor

### Configuration
- **`values.yaml`** - Helm chart values for Harbor deployment
- **`namespace.yaml`** - Harbor namespace definition

### Documentation
- **`QUICKSTART.md`** - Quick 5-step guide
- **`HARBOR_SETUP.md`** - Comprehensive setup guide
- **`README.md`** - Harbor documentation and reference
- **`FOLDER_INFO.md`** - This file

## 🚀 Quick Start

From this directory, run:

```bash
./deploy-with-harbor.sh
```

This will:
1. Install Harbor
2. Configure Harbor
3. Build and push API image
4. Deploy the API

## 📝 Individual Steps

If you prefer step-by-step:

```bash
# 1. Install Harbor
./setup-harbor.sh

# 2. Configure Harbor
./configure-harbor.sh

# 3. Build and push image
./build-push-harbor.sh

# 4. Deploy API (from parent directory)
cd ..
./deploy.sh
```

## 🔧 Script Details

### setup-harbor.sh
- Checks prerequisites (kubectl, helm, docker)
- Adds Harbor Helm repository
- Installs Harbor with custom values
- Waits for all pods to be ready
- Displays access information

### configure-harbor.sh
- Creates `kubekloud` project in Harbor
- Creates robot account for image pulls
- Creates Kubernetes imagePullSecret
- Saves credentials for later use

### build-push-harbor.sh
- Builds Docker image from project root
- Tags image for Harbor registry
- Pushes to Harbor
- Displays verification commands

### deploy-with-harbor.sh
- Runs all above scripts in sequence
- Guides through Docker configuration
- Provides interactive prompts
- Shows final access information

## 📊 Harbor Components

When installed, Harbor consists of:
- **Portal** - Web UI (http://harbor.local:30002)
- **Core** - API server
- **Registry** - Docker registry (image storage)
- **PostgreSQL** - Metadata database
- **Redis** - Caching layer
- **Trivy** - Vulnerability scanner
- **Jobservice** - Background tasks

## 🔑 Default Configuration

- **Namespace:** `harbor-system`
- **Exposure:** NodePort (port 30002)
- **Admin User:** `admin`
- **Admin Password:** `Harbor12345` (⚠️ change this!)
- **Project:** `kubekloud`
- **Storage:** 20Gi for images

## 📚 Documentation

- **Quick Start:** `QUICKSTART.md`
- **Detailed Guide:** `HARBOR_SETUP.md`
- **Reference:** `README.md`

## 🔄 Typical Workflow

### Initial Setup
```bash
cd k8s/harbor
./deploy-with-harbor.sh
```

### Daily Development
```bash
# Make code changes
cd k8s/harbor
./build-push-harbor.sh
kubectl rollout restart deployment kubekloud-api -n kubekloud-api
```

### Update Harbor
```bash
helm upgrade harbor harbor/harbor -n harbor-system -f values.yaml
```

## 🗑️ Cleanup

```bash
# Uninstall Harbor
helm uninstall harbor -n harbor-system

# Delete namespace
kubectl delete namespace harbor-system

# Clean up PVCs
kubectl delete pvc --all -n harbor-system
```

## 💡 Tips

1. **All scripts should be run from this directory** (`k8s/harbor/`)
2. **Change default passwords** before production use
3. **Configure Docker** to allow insecure registry (see QUICKSTART.md)
4. **Add to /etc/hosts:** `<node-ip> harbor.local`
5. **Use robot accounts** instead of admin for automation

## 🆘 Troubleshooting

### Scripts not executable?
```bash
chmod +x *.sh
```

### Harbor not accessible?
```bash
kubectl port-forward -n harbor-system svc/harbor-portal 8080:80
# Access at http://localhost:8080
```

### Can't push images?
```bash
# Check Docker daemon config
docker info | grep "Insecure Registries"
# Should show: harbor.local:30002
```

## 📞 Support

- See `HARBOR_SETUP.md` for detailed troubleshooting
- Check Harbor logs: `kubectl logs -n harbor-system -l app=harbor`
- Harbor docs: https://goharbor.io/docs/

---

**All Harbor-related operations should be run from this directory!**

