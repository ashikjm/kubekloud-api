# Kubernetes Deployment

This directory contains everything needed to deploy KubeKloud API with Harbor registry on Kubernetes.

## 🎯 Quick Start

### Option 1: With Harbor (Recommended - No External Registry Needed)

Deploy everything including Harbor registry:

```bash
cd k8s/harbor
./deploy-with-harbor.sh
```

This installs Harbor and deploys the API using local registry.

### Option 2: With External Registry

If you already have a Docker registry:

```bash
# 1. Build and push to your registry
docker build -t your-registry/kubekloud-api:latest ..
docker push your-registry/kubekloud-api:latest

# 2. Update image in api-deployment.yaml
# 3. Create imagePullSecret if using private registry
# 4. Deploy
./deploy.sh
```

## 📁 Directory Structure

```
k8s/
├── harbor/                        # Harbor registry setup
│   ├── setup-harbor.sh           # Install Harbor
│   ├── configure-harbor.sh       # Configure Harbor
│   ├── deploy-with-harbor.sh     # Complete setup with Harbor
│   ├── build-push-harbor.sh      # Build & push to Harbor
│   ├── values.yaml               # Helm values
│   ├── HARBOR_SETUP.md          # Detailed guide
│   ├── QUICKSTART.md            # Quick start
│   └── README.md                # Harbor docs
├── api-deployment.yaml          # API deployment (2 replicas)
├── api-service.yaml             # API LoadBalancer service
├── configmap.yaml               # Configuration
├── secret.yaml                  # Secrets (change passwords!)
├── serviceaccount.yaml          # RBAC permissions
├── postgres-deployment.yaml     # PostgreSQL database
├── postgres-service.yaml        # Database service
├── postgres-pvc.yaml            # Database storage (10Gi)
├── namespace.yaml               # kubekloud-api namespace
├── ingress.yaml                 # Optional ingress
├── kustomization.yaml           # Kustomize config
├── deploy.sh                    # Deploy script
└── README.md                    # This file
```

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────┐
│              Kubernetes Cluster                     │
│                                                     │
│  ┌──────────────────────────────────────────────┐  │
│  │  Harbor (harbor-system namespace)            │  │
│  │  - Container registry                        │  │
│  │  - Vulnerability scanning                    │  │
│  │  - Access control                            │  │
│  └─────────────────┬────────────────────────────┘  │
│                    │ Image pulls                    │
│                    ▼                                │
│  ┌──────────────────────────────────────────────┐  │
│  │  KubeKloud API (kubekloud-api namespace)     │  │
│  │                                              │  │
│  │  ┌────────────────────────────────────────┐ │  │
│  │  │  API Pods (2 replicas)                 │ │  │
│  │  │  - FastAPI application                 │ │  │
│  │  │  - Harbor images                       │ │  │
│  │  └──────────────┬─────────────────────────┘ │  │
│  │                 │                            │  │
│  │  ┌──────────────▼─────────────────────────┐ │  │
│  │  │  PostgreSQL                            │ │  │
│  │  │  - 10Gi persistent storage             │ │  │
│  │  └────────────────────────────────────────┘ │  │
│  └──────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────┘
```

## 📝 Deployment Methods

### Method 1: Complete Harbor Setup (Best for Self-Hosting)

```bash
cd harbor
./deploy-with-harbor.sh
```

**Includes:**
- Harbor registry installation
- Harbor configuration (project, robot account)
- Docker configuration guidance
- Image build and push
- API deployment

**Time:** ~15 minutes

**Pros:**
- No external registry needed
- Free and self-hosted
- Vulnerability scanning included
- Full control over images

### Method 2: Quick API Deployment (Requires External Registry)

```bash
./deploy.sh
```

**Requires:**
- Docker image already pushed to registry
- imagePullSecret configured (if private)

**Time:** ~5 minutes

### Method 3: Manual Step-by-Step

See detailed instructions in individual component READMEs.

## 🔧 Configuration

### Essential Updates Before Production

1. **Secrets** (`secret.yaml`):
   - Change PostgreSQL password
   - Update DATABASE_URL

2. **Image** (`api-deployment.yaml`):
   - Update image reference for your registry
   - Or use Harbor: `harbor.local:30002/kubekloud/kubekloud-api:latest`

3. **Service Type** (`api-service.yaml`):
   - LoadBalancer (default) - Gets external IP
   - ClusterIP - Use with Ingress
   - NodePort - Development only

4. **Storage** (`postgres-pvc.yaml`):
   - Adjust size based on needs
   - Set storageClassName if required

## 🚀 Common Operations

### Deploy or Update

```bash
# Deploy all resources
kubectl apply -f k8s/

# Or use kustomize
kubectl apply -k k8s/
```

### View Status

```bash
# All resources
kubectl get all -n kubekloud-api

# Pods only
kubectl get pods -n kubekloud-api

# Watch deployment
kubectl get pods -n kubekloud-api -w
```

### View Logs

```bash
# API logs
kubectl logs -n kubekloud-api -l app=kubekloud-api -f

# Database logs
kubectl logs -n kubekloud-api -l app=postgres -f
```

### Access API

```bash
# Get external IP (LoadBalancer)
kubectl get svc kubekloud-api-service -n kubekloud-api

# Or port-forward
kubectl port-forward -n kubekloud-api svc/kubekloud-api-service 8000:80
# Access at: http://localhost:8000
```

### Update Image

```bash
# Build and push new image
cd harbor
./build-push-harbor.sh

# Restart deployment to pull new image
kubectl rollout restart deployment kubekloud-api -n kubekloud-api

# Watch rollout
kubectl rollout status deployment kubekloud-api -n kubekloud-api
```

### Scale API

```bash
# Manual scaling
kubectl scale deployment kubekloud-api -n kubekloud-api --replicas=3

# Auto-scaling
kubectl autoscale deployment kubekloud-api -n kubekloud-api \
  --cpu-percent=70 --min=2 --max=10
```

## 🔐 Security

### RBAC Permissions

The API uses a ServiceAccount (`kubekloud-api-sa`) with permissions to:
- Manage pods, services, PVCs
- Manage deployments, statefulsets
- Manage VMs (KubeVirt)

Review and adjust in `serviceaccount.yaml`.

### Image Pull Secrets

For private registries, create secret:

```bash
kubectl create secret docker-registry regcred \
  --docker-server=<registry-url> \
  --docker-username=<username> \
  --docker-password=<password> \
  -n kubekloud-api
```

For Harbor, run:
```bash
cd harbor
./configure-harbor.sh
```

### Network Policies

Add network policies to restrict pod-to-pod communication:

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: api-policy
  namespace: kubekloud-api
spec:
  podSelector:
    matchLabels:
      app: kubekloud-api
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from:
    - namespaceSelector: {}
  egress:
  - to:
    - podSelector:
        matchLabels:
          app: postgres
```

## 📊 Monitoring

### Resource Usage

```bash
kubectl top pods -n kubekloud-api
kubectl top nodes
```

### Health Checks

```bash
# API health
kubectl exec -n kubekloud-api <pod-name> -- \
  curl -s http://localhost:8000/health

# Database health
kubectl exec -n kubekloud-api <postgres-pod> -- \
  pg_isready -U kubekloud_user
```

## 🔄 Maintenance

### Backup Database

```bash
# Create backup
kubectl exec -n kubekloud-api <postgres-pod> -- \
  pg_dump -U kubekloud_user kubekloud > backup.sql

# Restore backup
kubectl exec -i -n kubekloud-api <postgres-pod> -- \
  psql -U kubekloud_user kubekloud < backup.sql
```

### Update Kubernetes Manifests

```bash
# Edit manifest
vim api-deployment.yaml

# Apply changes
kubectl apply -f api-deployment.yaml

# Verify
kubectl rollout status deployment kubekloud-api -n kubekloud-api
```

### Clean Up

```bash
# Delete everything
kubectl delete namespace kubekloud-api

# Or selectively
kubectl delete -f k8s/
```

## 🐛 Troubleshooting

### Pods Not Starting

```bash
# Describe pod to see events
kubectl describe pod -n kubekloud-api <pod-name>

# Common issues:
# - ImagePullBackOff: Check image exists and secret is valid
# - CrashLoopBackOff: Check logs for application errors
# - Pending: Check resource availability and PVC status
```

### Database Connection Issues

```bash
# Check database pod
kubectl get pod -n kubekloud-api -l app=postgres

# Test connection from API pod
kubectl exec -n kubekloud-api <api-pod> -- \
  python -c "from app.database import engine; print(engine.connect())"

# Check DATABASE_URL secret
kubectl get secret kubekloud-api-secret -n kubekloud-api -o yaml
```

### Can't Access API

```bash
# Check service
kubectl get svc kubekloud-api-service -n kubekloud-api

# Check endpoints
kubectl get endpoints kubekloud-api-service -n kubekloud-api

# For LoadBalancer, external IP may take time
# Use port-forward as alternative
kubectl port-forward -n kubekloud-api svc/kubekloud-api-service 8000:80
```

## 📚 Documentation

- **`DEPLOYMENT.md`** - General deployment guide
- **`harbor/HARBOR_SETUP.md`** - Harbor detailed setup
- **`harbor/QUICKSTART.md`** - Harbor quick start
- **`BUILD_PUSH.md`** - Docker build instructions
- **`HARBOR_INTEGRATION.md`** - Harbor integration guide

## 🔗 Resources

- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [Harbor Documentation](https://goharbor.io/docs/)
- [Helm Documentation](https://helm.sh/docs/)
- [PostgreSQL on Kubernetes](https://www.postgresql.org/docs/)

## ✅ Pre-flight Checklist

Before deploying to production:

- [ ] Update all passwords in `secret.yaml`
- [ ] Configure proper image registry
- [ ] Set up imagePullSecrets
- [ ] Review RBAC permissions
- [ ] Configure ingress with HTTPS
- [ ] Set up monitoring
- [ ] Configure database backups
- [ ] Adjust resource limits
- [ ] Enable network policies
- [ ] Set up log aggregation
- [ ] Configure alerting
- [ ] Test disaster recovery

## 💡 Tips

1. **Start with Harbor** - Easiest way to get started without external dependencies
2. **Use specific image tags** - Avoid `latest` in production
3. **Monitor resources** - Adjust limits based on actual usage
4. **Regular backups** - Automate database backups
5. **Use Ingress** - Better than LoadBalancer for production
6. **Enable autoscaling** - Handle traffic spikes automatically
7. **Test updates** - Use staging environment first

## 🆘 Support

For issues:
1. Check the logs: `kubectl logs -n kubekloud-api -l app=kubekloud-api`
2. Review documentation in this directory
3. Check Harbor status (if using): `kubectl get pods -n harbor-system`
4. See main project README for general issues

## 🚀 Next Steps After Deployment

1. Access API at external IP or via port-forward
2. Visit API docs at `/docs` endpoint
3. Create your first user via API
4. Set up monitoring and alerting
5. Configure automated backups
6. Enable HTTPS with cert-manager
7. Set up CI/CD pipeline

---

**Happy Deploying! 🎉**

For quick start, run: `./deploy-with-harbor.sh`
