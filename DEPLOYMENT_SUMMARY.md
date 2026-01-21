# Kubernetes + Harbor Deployment - Complete Setup

This document provides an overview of the complete Kubernetes deployment setup with Harbor registry.

## 🎯 What You Have Now

A complete, production-ready Kubernetes deployment setup that includes:

1. **Harbor Container Registry** - Self-hosted Docker registry in your cluster
2. **KubeKloud API** - Deployed with high availability (2 replicas)
3. **PostgreSQL Database** - With persistent storage
4. **Automated Scripts** - One-command deployment
5. **Comprehensive Documentation** - Detailed guides for all scenarios

## 📦 What Was Created

### Harbor Setup (`k8s/harbor/`)

| File | Purpose |
|------|---------|
| `setup-harbor.sh` | Automated Harbor installation via Helm |
| `configure-harbor.sh` | Create project and robot account |
| `values.yaml` | Harbor Helm chart configuration |
| `namespace.yaml` | Harbor namespace |
| `HARBOR_SETUP.md` | Detailed Harbor guide |
| `QUICKSTART.md` | 5-step quick start |
| `README.md` | Harbor documentation |

### API Deployment (`k8s/`)

| File | Purpose |
|------|---------|
| `api-deployment.yaml` | API pods (updated for Harbor) |
| `api-service.yaml` | LoadBalancer service |
| `postgres-deployment.yaml` | Database with health checks |
| `postgres-service.yaml` | Database ClusterIP service |
| `postgres-pvc.yaml` | 10Gi persistent storage |
| `configmap.yaml` | Configuration (updated with Harbor) |
| `secret.yaml` | Credentials (⚠️ change passwords!) |
| `serviceaccount.yaml` | RBAC permissions |
| `namespace.yaml` | kubekloud-api namespace |
| `ingress.yaml` | Optional ingress config |
| `kustomization.yaml` | Kustomize deployment |

### Scripts

| Script | Purpose |
|--------|---------|
| `deploy-with-harbor.sh` | Complete setup (Harbor + API) |
| `build-push-harbor.sh` | Build and push to Harbor |
| `deploy.sh` | Deploy API only |
| `harbor/setup-harbor.sh` | Install Harbor |
| `harbor/configure-harbor.sh` | Configure Harbor |

### Documentation

| Document | Content |
|----------|---------|
| `DEPLOYMENT.md` | General deployment guide |
| `HARBOR_INTEGRATION.md` | Harbor integration details |
| `k8s/README.md` | Kubernetes deployment overview |
| `k8s/harbor/HARBOR_SETUP.md` | Detailed Harbor setup |
| `k8s/harbor/QUICKSTART.md` | Quick Harbor guide |
| `k8s/BUILD_PUSH.md` | Docker build instructions |

## 🚀 Quick Start (3 Options)

### Option 1: Complete Setup with Harbor (Recommended)

**No external Docker registry needed!**

```bash
cd k8s/harbor
./deploy-with-harbor.sh
```

This single command will:
1. ✅ Install Harbor container registry
2. ✅ Configure Harbor (create project, robot account)
3. ✅ Guide you through Docker configuration
4. ✅ Build and push API image to Harbor
5. ✅ Deploy API with PostgreSQL
6. ✅ Show access information

**Time:** ~15 minutes
**Result:** Fully functional API with local registry

### Option 2: Harbor Setup Step-by-Step

```bash
# 1. Install Harbor
cd k8s/harbor
./setup-harbor.sh

# 2. Configure Harbor
./configure-harbor.sh

# 3. Configure Docker
# Add to /etc/docker/daemon.json:
# {"insecure-registries": ["harbor.local:30002"]}
# Restart Docker

# 4. Add to /etc/hosts
echo "<NODE_IP> harbor.local" | sudo tee -a /etc/hosts

# 5. Build and push
cd ..
./build-push-harbor.sh

# 6. Deploy API
./deploy.sh
```

### Option 3: Using External Registry

```bash
# 1. Build and push to your registry
docker build -t your-registry/kubekloud-api:latest .
docker push your-registry/kubekloud-api:latest

# 2. Update k8s/api-deployment.yaml
# Change image: to your registry

# 3. Create imagePullSecret if private
kubectl create secret docker-registry regcred \
  --docker-server=your-registry \
  --docker-username=<user> \
  --docker-password=<pass> \
  -n kubekloud-api

# 4. Update api-deployment.yaml to use regcred

# 5. Deploy
cd k8s
./deploy.sh
```

## 📊 Architecture Overview

```
┌──────────────────────────────────────────────────────────────┐
│                    Kubernetes Cluster                        │
│                                                              │
│  ┌────────────────────────────────────────────────────────┐ │
│  │  Harbor Container Registry (harbor-system)             │ │
│  │  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐ │ │
│  │  │  Portal  │ │ Registry │ │PostgreSQL│ │  Trivy   │ │ │
│  │  │  (UI)    │ │ (Images) │ │  (Meta)  │ │  (Scan)  │ │ │
│  │  └──────────┘ └──────────┘ └──────────┘ └──────────┘ │ │
│  │  Exposes: NodePort 30002 or LoadBalancer              │ │
│  └────────────────────────────┬───────────────────────────┘ │
│                                │                             │
│              Image Pull (harbor.local:30002/kubekloud/...)  │
│                                │                             │
│                                ▼                             │
│  ┌────────────────────────────────────────────────────────┐ │
│  │  KubeKloud API (kubekloud-api namespace)               │ │
│  │                                                        │ │
│  │  ┌───────────────────────────────────────────────┐   │ │
│  │  │  API Pods (Deployment, 2 replicas)            │   │ │
│  │  │  - Image: harbor.../kubekloud-api:latest      │   │ │
│  │  │  - Resources: 256Mi-512Mi RAM, 250m-500m CPU  │   │ │
│  │  │  - Health checks: /health endpoint            │   │ │
│  │  │  - ServiceAccount: kubekloud-api-sa            │   │ │
│  │  │  - imagePullSecret: harbor-regcred            │   │ │
│  │  └───────────────┬───────────────────────────────┘   │ │
│  │                  │                                    │ │
│  │                  │ Connects to                       │ │
│  │                  ▼                                    │ │
│  │  ┌───────────────────────────────────────────────┐   │ │
│  │  │  PostgreSQL (StatefulSet)                     │   │ │
│  │  │  - postgres:16-alpine                         │   │ │
│  │  │  - PVC: 10Gi persistent storage               │   │ │
│  │  │  - ClusterIP Service: postgres-service        │   │ │
│  │  │  - Resources: 256Mi-512Mi RAM, 250m-500m CPU  │   │ │
│  │  └───────────────────────────────────────────────┘   │ │
│  │                                                        │ │
│  │  Exposes: LoadBalancer Service (port 80 → 8000)       │ │
│  └────────────────────────────────────────────────────────┘ │
│                                                              │
│  External Access:                                            │
│  - API: http://<EXTERNAL-IP> or port-forward                │
│  - Harbor: http://harbor.local:30002                         │
│  - Docs: http://<EXTERNAL-IP>/docs                           │
└──────────────────────────────────────────────────────────────┘
```

## 🔑 Key Features

### Harbor Registry
- ✅ Self-hosted in same cluster (no external dependencies)
- ✅ Vulnerability scanning with Trivy
- ✅ Access control and RBAC
- ✅ Web UI for image management
- ✅ Robot accounts for CI/CD
- ✅ Project-based organization

### API Deployment
- ✅ High availability (2 replicas)
- ✅ Auto-restart on failure
- ✅ Health checks (liveness & readiness)
- ✅ Resource limits and requests
- ✅ RBAC for Kubernetes operations
- ✅ Secure imagePullSecret

### Database
- ✅ PostgreSQL 16 with persistence
- ✅ 10Gi storage (adjustable)
- ✅ Health checks
- ✅ Resource limits
- ✅ Data survives pod restarts

## 📝 Configuration Changes Made

### Updated Files

**`api-deployment.yaml`:**
- Changed image to: `harbor.local:30002/kubekloud/kubekloud-api:latest`
- Added `imagePullSecrets` for Harbor authentication

**`configmap.yaml`:**
- Added `HARBOR_URL` and `HARBOR_PROJECT` configuration

**`requirements.txt`:**
- Added `psycopg2-binary` for PostgreSQL support

**`Dockerfile`:**
- Updated healthcheck to use stdlib (urllib) instead of requests

## 🔐 Security Considerations

### Before Production:

1. **Change Passwords:**
   - Harbor admin password (default: `Harbor12345`)
   - PostgreSQL password in `k8s/secret.yaml`
   - Update `DATABASE_URL` accordingly

2. **Enable HTTPS:**
   - Configure TLS for Harbor
   - Set up Ingress with cert-manager for API

3. **Review RBAC:**
   - Check permissions in `serviceaccount.yaml`
   - Apply principle of least privilege

4. **Use Robot Accounts:**
   - Replace admin credentials with robot accounts
   - Created automatically by `configure-harbor.sh`

5. **Network Policies:**
   - Restrict pod-to-pod communication
   - Limit ingress/egress traffic

## 🎯 Access Your Services

### Harbor Registry

**URL:** http://harbor.local:30002 (or use NodeIP:30002)

**Credentials:**
- Username: `admin`
- Password: `Harbor12345` (⚠️ change this!)

**Features:**
- View and manage images
- Scan for vulnerabilities
- Configure projects and users
- View audit logs

### KubeKloud API

**Via LoadBalancer:**
```bash
# Get external IP
kubectl get svc kubekloud-api-service -n kubekloud-api
# Access at: http://<EXTERNAL-IP>
```

**Via Port Forward:**
```bash
kubectl port-forward -n kubekloud-api svc/kubekloud-api-service 8000:80
# Access at: http://localhost:8000
```

**Endpoints:**
- API Root: `/`
- Health Check: `/health`
- API Docs: `/docs`
- OpenAPI Spec: `/openapi.json`

## 🔄 Development Workflow

### Make Changes to API

1. **Edit code** in your IDE
2. **Build and push:**
   ```bash
   cd k8s/harbor
   ./build-push-harbor.sh
   ```
3. **Update deployment:**
   ```bash
   kubectl rollout restart deployment kubekloud-api -n kubekloud-api
   ```
4. **Watch rollout:**
   ```bash
   kubectl rollout status deployment kubekloud-api -n kubekloud-api
   ```
5. **Check logs:**
   ```bash
   kubectl logs -n kubekloud-api -l app=kubekloud-api -f
   ```

### Version Tagging

```bash
# Build with version tag
cd k8s/harbor
IMAGE_TAG=v1.0.0 ./build-push-harbor.sh

# Update deployment to use specific version
kubectl set image deployment/kubekloud-api \
  api=harbor.local:30002/kubekloud/kubekloud-api:v1.0.0 \
  -n kubekloud-api
```

## 🐛 Troubleshooting

### Quick Diagnostics

```bash
# Check all pods
kubectl get pods -n kubekloud-api -n harbor-system

# Check services
kubectl get svc -n kubekloud-api -n harbor-system

# Check events
kubectl get events -n kubekloud-api --sort-by='.lastTimestamp'

# Resource usage
kubectl top pods -n kubekloud-api -n harbor-system
kubectl top nodes
```

### Common Issues

**ImagePullBackOff:**
- Verify Harbor is accessible: `curl http://harbor.local:30002`
- Check secret exists: `kubectl get secret harbor-regcred -n kubekloud-api`
- Verify image exists in Harbor UI

**CrashLoopBackOff:**
- Check logs: `kubectl logs -n kubekloud-api <pod-name>`
- Verify DATABASE_URL is correct
- Check database is running

**Pending Pods:**
- Check resources: `kubectl describe pod -n kubekloud-api <pod-name>`
- Verify PVC is bound: `kubectl get pvc -n kubekloud-api`

For detailed troubleshooting, see:
- `k8s/harbor/HARBOR_SETUP.md` - Harbor issues
- `k8s/README.md` - Deployment issues
- `DEPLOYMENT.md` - General issues

## 📚 Documentation Index

| Document | When to Use |
|----------|-------------|
| **DEPLOYMENT_SUMMARY.md** (this file) | Overview and quick start |
| **DEPLOYMENT.md** | General deployment guide |
| **HARBOR_INTEGRATION.md** | Harbor integration details |
| **k8s/README.md** | Kubernetes deployment reference |
| **k8s/harbor/QUICKSTART.md** | Fast Harbor setup |
| **k8s/harbor/HARBOR_SETUP.md** | Detailed Harbor guide |
| **k8s/BUILD_PUSH.md** | Docker build instructions |

## ✅ Deployment Checklist

### Initial Setup
- [ ] Run `./deploy-with-harbor.sh` or follow manual steps
- [ ] Verify Harbor is accessible
- [ ] Verify API is accessible
- [ ] Test API endpoints (`/health`, `/docs`)

### Security
- [ ] Change Harbor admin password
- [ ] Update PostgreSQL password
- [ ] Create robot account for CI/CD
- [ ] Review RBAC permissions

### Production
- [ ] Enable HTTPS for Harbor
- [ ] Configure Ingress with TLS for API
- [ ] Set up monitoring (Prometheus/Grafana)
- [ ] Configure database backups
- [ ] Set up log aggregation
- [ ] Enable autoscaling
- [ ] Configure alerting
- [ ] Test disaster recovery

## 🚀 Next Steps

1. **Deploy:** Run `cd k8s && ./deploy-with-harbor.sh`
2. **Verify:** Check all pods are running
3. **Secure:** Change default passwords
4. **Test:** Create users and test API functionality
5. **Monitor:** Set up monitoring and logging
6. **Production:** Enable HTTPS and configure ingress
7. **CI/CD:** Set up automated builds and deployments

## 💡 Pro Tips

1. **Use Harbor from day 1** - Easier than setting up external registries
2. **Tag versions properly** - Avoid using `latest` in production
3. **Monitor resources** - Adjust limits based on actual usage
4. **Automate backups** - Schedule regular database backups
5. **Test updates** - Always test in staging first
6. **Use robot accounts** - Better than using admin credentials
7. **Enable vulnerability scanning** - Scan all images for security issues

## 🆘 Getting Help

1. **Check logs first:**
   ```bash
   kubectl logs -n kubekloud-api -l app=kubekloud-api --tail=50
   kubectl logs -n harbor-system -l app=harbor --tail=50
   ```

2. **Review documentation:**
   - Start with relevant guide from documentation index above
   - Check troubleshooting sections

3. **Describe resources:**
   ```bash
   kubectl describe pod -n kubekloud-api <pod-name>
   kubectl describe svc -n kubekloud-api kubekloud-api-service
   ```

## 🎉 Success Indicators

Your deployment is successful when:

✅ All pods in `kubekloud-api` namespace are Running
✅ All pods in `harbor-system` namespace are Running
✅ You can access Harbor UI at http://harbor.local:30002
✅ You can access API at external IP or via port-forward
✅ API health check returns: `{"status": "healthy"}`
✅ API docs are accessible at `/docs`
✅ You can push/pull images to/from Harbor

## 📞 Support

For issues with:
- **Harbor:** See `k8s/harbor/HARBOR_SETUP.md`
- **API Deployment:** See `k8s/README.md`
- **General:** See main `README.md`

---

**You're all set! 🚀**

Run `cd k8s && ./deploy-with-harbor.sh` to get started!

