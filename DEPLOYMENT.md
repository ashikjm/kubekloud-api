# Kubernetes Deployment Summary

This guide provides quick instructions to deploy the KubeKloud API to Kubernetes.

## What's Included

### Updated Files
1. **Dockerfile** - Updated healthcheck to use stdlib instead of requests
2. **requirements.txt** - Added `psycopg2-binary` for PostgreSQL support
3. **.dockerignore** - Optimizes Docker build by excluding unnecessary files

### New Kubernetes Manifests (`k8s/` directory)

| File | Description |
|------|-------------|
| `namespace.yaml` | Creates `kubekloud-api` namespace |
| `configmap.yaml` | Configuration for database and Kubernetes settings |
| `secret.yaml` | Database credentials (⚠️ Change in production!) |
| `serviceaccount.yaml` | RBAC permissions for API to manage K8s resources |
| `postgres-pvc.yaml` | 10Gi persistent storage for database |
| `postgres-deployment.yaml` | PostgreSQL 16 database deployment |
| `postgres-service.yaml` | ClusterIP service for database (internal) |
| `api-deployment.yaml` | API deployment with 2 replicas |
| `api-service.yaml` | LoadBalancer service for API (external) |
| `ingress.yaml` | (Optional) Ingress for production with domain |
| `kustomization.yaml` | Kustomize configuration for easy deployment |
| `deploy.sh` | Automated deployment script |
| `README.md` | Comprehensive deployment documentation |

## Quick Deployment

### Method 1: Using the Deploy Script (Easiest)

```bash
# 1. Build and push your Docker image
docker build -t your-registry/kubekloud-api:latest .
docker push your-registry/kubekloud-api:latest

# 2. Run the deployment script
cd k8s
./deploy.sh
```

The script will:
- ✅ Check cluster connectivity
- ✅ Create namespace and resources
- ✅ Deploy PostgreSQL with persistent storage
- ✅ Deploy API with 2 replicas
- ✅ Wait for pods to be ready
- ✅ Show access instructions

### Method 2: Manual kubectl Apply

```bash
# 1. Build and push Docker image
docker build -t your-registry/kubekloud-api:latest .
docker push your-registry/kubekloud-api:latest

# 2. Update image in api-deployment.yaml
# Change: image: your-registry/kubekloud-api:latest

# 3. Apply manifests
kubectl apply -f k8s/

# 4. Wait for deployment
kubectl wait --for=condition=ready pod -l app=kubekloud-api -n kubekloud-api --timeout=120s
```

### Method 3: Using Kustomize

```bash
# 1. Build and push Docker image (same as above)

# 2. Update image reference
# Edit k8s/api-deployment.yaml

# 3. Deploy with kustomize
kubectl apply -k k8s/
```

## Accessing the API

### Get Service URL

```bash
# For LoadBalancer
kubectl get svc kubekloud-api-service -n kubekloud-api

# Access at the EXTERNAL-IP shown
```

### Using Port Forward (Local Testing)

```bash
kubectl port-forward -n kubekloud-api svc/kubekloud-api-service 8000:80

# Access at:
# - API: http://localhost:8000
# - Docs: http://localhost:8000/docs
# - Health: http://localhost:8000/health
```

## Architecture Overview

```
┌─────────────────────────────────────────┐
│         Kubernetes Cluster              │
│                                         │
│  ┌──────────────────────────────────┐  │
│  │   Namespace: kubekloud-api       │  │
│  │                                  │  │
│  │  ┌────────────────────────────┐ │  │
│  │  │  LoadBalancer Service      │ │  │
│  │  │  (External IP)             │ │  │
│  │  └──────────┬─────────────────┘ │  │
│  │             │                    │  │
│  │  ┌──────────▼─────────────────┐ │  │
│  │  │  API Deployment (2 pods)   │ │  │
│  │  │  - FastAPI Application     │ │  │
│  │  │  - Port 8000               │ │  │
│  │  │  - Health checks           │ │  │
│  │  └──────────┬─────────────────┘ │  │
│  │             │                    │  │
│  │  ┌──────────▼─────────────────┐ │  │
│  │  │  PostgreSQL Service        │ │  │
│  │  │  (ClusterIP - internal)    │ │  │
│  │  └──────────┬─────────────────┘ │  │
│  │             │                    │  │
│  │  ┌──────────▼─────────────────┐ │  │
│  │  │  PostgreSQL Deployment     │ │  │
│  │  │  - postgres:16-alpine      │ │  │
│  │  │  - Persistent Storage      │ │  │
│  │  └────────────────────────────┘ │  │
│  │             │                    │  │
│  │  ┌──────────▼─────────────────┐ │  │
│  │  │  PersistentVolumeClaim     │ │  │
│  │  │  (10Gi storage)            │ │  │
│  │  └────────────────────────────┘ │  │
│  │                                  │  │
│  └──────────────────────────────────┘  │
│                                         │
└─────────────────────────────────────────┘
```

## Configuration

### Environment Variables

Set in `configmap.yaml`:
- `K8S_NAMESPACE`: Default namespace for K8s operations
- `POSTGRES_DB`: Database name
- `POSTGRES_HOST`: Database host
- `POSTGRES_PORT`: Database port

Set in `secret.yaml` (⚠️ **Change these!**):
- `POSTGRES_USER`: Database username
- `POSTGRES_PASSWORD`: Database password
- `DATABASE_URL`: Full connection string

### Resource Allocation

**PostgreSQL:**
- Memory: 256Mi (request) / 512Mi (limit)
- CPU: 250m (request) / 500m (limit)
- Storage: 10Gi persistent volume

**API:**
- Memory: 256Mi (request) / 512Mi (limit)
- CPU: 250m (request) / 500m (limit)
- Replicas: 2 (for high availability)

## Security Checklist

Before deploying to production:

- [ ] Change PostgreSQL password in `secret.yaml`
- [ ] Update Docker image registry to private registry
- [ ] Configure proper ingress with HTTPS
- [ ] Review RBAC permissions in `serviceaccount.yaml`
- [ ] Enable network policies
- [ ] Set up proper monitoring and logging
- [ ] Configure backup strategy for database
- [ ] Review and adjust resource limits
- [ ] Enable pod security policies
- [ ] Use a secrets management solution (Vault, Sealed Secrets)

## Monitoring and Troubleshooting

### View Logs

```bash
# API logs
kubectl logs -n kubekloud-api -l app=kubekloud-api --tail=100 -f

# Database logs
kubectl logs -n kubekloud-api -l app=postgres --tail=100 -f
```

### Check Status

```bash
# All resources
kubectl get all -n kubekloud-api

# Describe problematic pod
kubectl describe pod <pod-name> -n kubekloud-api

# Events in namespace
kubectl get events -n kubekloud-api --sort-by='.lastTimestamp'
```

### Database Connection Test

```bash
# Connect to API pod
kubectl exec -it -n kubekloud-api <api-pod-name> -- /bin/bash

# Inside pod, test database
python -c "from app.database import engine; print(engine.connect())"
```

### Scale API

```bash
# Scale to 3 replicas
kubectl scale deployment kubekloud-api -n kubekloud-api --replicas=3

# Enable autoscaling
kubectl autoscale deployment kubekloud-api -n kubekloud-api \
  --cpu-percent=70 --min=2 --max=10
```

## Production Considerations

### Use Ingress Instead of LoadBalancer

1. Change service type in `api-service.yaml`:
   ```yaml
   spec:
     type: ClusterIP  # Changed from LoadBalancer
   ```

2. Deploy ingress:
   ```bash
   kubectl apply -f k8s/ingress.yaml
   ```

3. Configure your DNS to point to ingress IP

### Enable HTTPS

1. Install cert-manager
2. Configure TLS in `ingress.yaml`
3. See `k8s/README.md` for detailed instructions

### Database Backups

- Set up automated backups using CronJob
- Consider using managed PostgreSQL (AWS RDS, GCP Cloud SQL)
- Example backup CronJob provided in `k8s/README.md`

## Cleanup

Remove everything:
```bash
kubectl delete namespace kubekloud-api
```

Or remove individual resources:
```bash
kubectl delete -k k8s/
```

## Next Steps

1. ✅ Deploy to your Kubernetes cluster
2. 🔐 Update security configurations
3. 🌐 Set up proper domain and HTTPS
4. 📊 Configure monitoring (Prometheus/Grafana)
5. 💾 Set up database backups
6. 📝 Review and adjust resource limits
7. 🔄 Set up CI/CD pipeline

## Support

For detailed documentation, see:
- `k8s/README.md` - Comprehensive deployment guide
- `README.md` - Project overview
- `API_EXAMPLES.md` - API usage examples

## Common Issues

**Pod not starting?**
- Check logs: `kubectl logs <pod-name> -n kubekloud-api`
- Check events: `kubectl describe pod <pod-name> -n kubekloud-api`

**Database connection failed?**
- Verify PostgreSQL is running: `kubectl get pods -n kubekloud-api -l app=postgres`
- Check secret configuration: `kubectl get secret kubekloud-api-secret -n kubekloud-api -o yaml`

**Cannot access API?**
- For LoadBalancer: Wait for external IP assignment
- For testing: Use port-forward
- Check service: `kubectl get svc -n kubekloud-api`

**Image pull errors?**
- Update image reference in `api-deployment.yaml`
- Ensure image is pushed to registry
- Check imagePullSecrets if using private registry

