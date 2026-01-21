# Quick Reference Card

One-page reference for deploying and managing KubeKloud API with Harbor.

## 🚀 Quick Deploy (5 minutes)

```bash
cd k8s/harbor && ./deploy-with-harbor.sh
```

That's it! This single command does everything.

## 📋 Command Cheat Sheet

### Deployment

```bash
# Complete setup with Harbor
cd k8s/harbor && ./deploy-with-harbor.sh

# Deploy API only (requires external registry)
cd k8s && ./deploy.sh

# Deploy Harbor only
cd k8s/harbor && ./setup-harbor.sh

# Configure Harbor
cd k8s/harbor && ./configure-harbor.sh
```

### Build & Push

```bash
# Build and push to Harbor
cd k8s/harbor && ./build-push-harbor.sh

# Build with specific tag
cd k8s/harbor && IMAGE_TAG=v1.0.0 ./build-push-harbor.sh

# Manual build
docker build -t harbor.local:30002/kubekloud/kubekloud-api:latest .
docker push harbor.local:30002/kubekloud/kubekloud-api:latest
```

### Status Checks

```bash
# All resources
kubectl get all -n kubekloud-api
kubectl get all -n harbor-system

# Just pods
kubectl get pods -n kubekloud-api

# Watch pods
kubectl get pods -n kubekloud-api -w

# Pod details
kubectl describe pod <pod-name> -n kubekloud-api
```

### Logs

```bash
# API logs (follow)
kubectl logs -n kubekloud-api -l app=kubekloud-api -f

# API logs (last 100 lines)
kubectl logs -n kubekloud-api -l app=kubekloud-api --tail=100

# Database logs
kubectl logs -n kubekloud-api -l app=postgres -f

# Harbor logs
kubectl logs -n harbor-system -l app=harbor -f
```

### Access Services

```bash
# Get API external IP
kubectl get svc kubekloud-api-service -n kubekloud-api

# Port forward API
kubectl port-forward -n kubekloud-api svc/kubekloud-api-service 8000:80

# Port forward Harbor
kubectl port-forward -n harbor-system svc/harbor-portal 8080:80

# Access Harbor UI
open http://harbor.local:30002
```

### Update & Restart

```bash
# Update image and restart
cd k8s/harbor && ./build-push-harbor.sh
kubectl rollout restart deployment kubekloud-api -n kubekloud-api

# Watch rollout
kubectl rollout status deployment kubekloud-api -n kubekloud-api

# Rollback if needed
kubectl rollout undo deployment kubekloud-api -n kubekloud-api
```

### Scaling

```bash
# Scale manually
kubectl scale deployment kubekloud-api -n kubekloud-api --replicas=3

# Enable autoscaling
kubectl autoscale deployment kubekloud-api -n kubekloud-api \
  --cpu-percent=70 --min=2 --max=10

# View HPA status
kubectl get hpa -n kubekloud-api
```

### Database Operations

```bash
# Connect to database
kubectl exec -it -n kubekloud-api <postgres-pod> -- \
  psql -U kubekloud_user -d kubekloud

# Backup database
kubectl exec -n kubekloud-api <postgres-pod> -- \
  pg_dump -U kubekloud_user kubekloud > backup.sql

# Restore database
kubectl exec -i -n kubekloud-api <postgres-pod> -- \
  psql -U kubekloud_user kubekloud < backup.sql

# Check database size
kubectl exec -n kubekloud-api <postgres-pod> -- \
  psql -U kubekloud_user -c "SELECT pg_size_pretty(pg_database_size('kubekloud'));"
```

### Troubleshooting

```bash
# Check events
kubectl get events -n kubekloud-api --sort-by='.lastTimestamp'

# Resource usage
kubectl top pods -n kubekloud-api
kubectl top nodes

# Check PVC status
kubectl get pvc -n kubekloud-api

# Test API health
kubectl exec -n kubekloud-api <api-pod> -- \
  curl -s http://localhost:8000/health

# Test database connectivity
kubectl exec -n kubekloud-api <postgres-pod> -- \
  pg_isready -U kubekloud_user
```

### Cleanup

```bash
# Delete API namespace (keeps Harbor)
kubectl delete namespace kubekloud-api

# Delete Harbor
helm uninstall harbor -n harbor-system
kubectl delete namespace harbor-system

# Delete everything
kubectl delete namespace kubekloud-api harbor-system
```

## 🔑 Important URLs

| Service | URL | Credentials |
|---------|-----|-------------|
| Harbor UI | http://harbor.local:30002 | admin / Harbor12345 |
| API | http://\<external-ip\> | (none by default) |
| API Docs | http://\<external-ip\>/docs | (none by default) |
| API Health | http://\<external-ip\>/health | (none by default) |

## 📁 File Locations

| What | Where |
|------|-------|
| API manifests | `k8s/*.yaml` |
| Harbor manifests | `k8s/harbor/` |
| Deploy scripts | `k8s/*.sh` |
| Documentation | Root `*.md` and `k8s/*.md` |
| Dockerfile | Root `Dockerfile` |
| Requirements | Root `requirements.txt` |

## 🔧 Configuration Files

| File | Purpose | Change for Production |
|------|---------|----------------------|
| `k8s/secret.yaml` | Passwords | ✅ Yes, change passwords! |
| `k8s/api-deployment.yaml` | API config | Maybe (resources, replicas) |
| `k8s/configmap.yaml` | Settings | Maybe (namespace, Harbor URL) |
| `k8s/harbor/values.yaml` | Harbor config | Yes (passwords, storage) |

## 🎯 Common Tasks

### First Time Setup
1. `cd k8s/harbor && ./deploy-with-harbor.sh`
2. Add Harbor to /etc/hosts
3. Configure Docker insecure registry
4. Access services and verify

### Daily Development
1. Make code changes
2. `cd k8s/harbor && ./build-push-harbor.sh`
3. `kubectl rollout restart deployment kubekloud-api -n kubekloud-api`
4. Check logs

### Debugging Issues
1. `kubectl get pods -n kubekloud-api`
2. `kubectl logs -n kubekloud-api <pod-name>`
3. `kubectl describe pod -n kubekloud-api <pod-name>`
4. Check documentation in `k8s/`

### Production Deployment
1. Change all passwords in secrets
2. Enable HTTPS/TLS
3. Configure proper ingress
4. Set up monitoring
5. Configure backups
6. See `DEPLOYMENT.md` for details

## 📊 Resource Requirements

**Minimum Cluster:**
- 3 nodes
- 2Gi RAM per node
- 2 CPU per node
- 50Gi storage

**Recommended:**
- 3+ nodes
- 4Gi+ RAM per node
- 4+ CPU per node
- 100Gi+ storage

## 🆘 Quick Troubleshooting

| Problem | Quick Fix |
|---------|-----------|
| ImagePullBackOff | Check Harbor is running, verify secret exists |
| CrashLoopBackOff | Check logs: `kubectl logs <pod>` |
| Pending | Check resources: `kubectl describe pod <pod>` |
| Can't access API | Use port-forward as temporary solution |
| Can't push to Harbor | Check Docker insecure-registries config |
| Harbor UI not loading | Port-forward: `kubectl port-forward -n harbor-system svc/harbor-portal 8080:80` |

## 📚 Documentation Index

- **DEPLOYMENT_SUMMARY.md** - Complete overview
- **DEPLOYMENT.md** - General deployment guide  
- **HARBOR_INTEGRATION.md** - Harbor integration
- **k8s/README.md** - Kubernetes reference
- **k8s/ARCHITECTURE.md** - Architecture diagrams
- **k8s/harbor/HARBOR_SETUP.md** - Detailed Harbor guide
- **k8s/harbor/QUICKSTART.md** - Harbor quick start

## 💡 Pro Tips

1. **Always use version tags**, not `latest` in production
2. **Set up monitoring** early (Prometheus + Grafana)
3. **Automate backups** from day one
4. **Test in staging** before production updates
5. **Use robot accounts** instead of admin for CI/CD
6. **Enable autoscaling** to handle traffic spikes
7. **Document your customizations** for future reference

## ⚡ Speed Commands

Most used commands for quick access:

```bash
# Deploy
cd k8s/harbor && ./deploy-with-harbor.sh

# Update
cd k8s/harbor && ./build-push-harbor.sh && kubectl rollout restart deployment kubekloud-api -n kubekloud-api

# Status
kubectl get all -n kubekloud-api

# Logs
kubectl logs -n kubekloud-api -l app=kubekloud-api -f

# Access
kubectl port-forward -n kubekloud-api svc/kubekloud-api-service 8000:80
```

---

**Keep this file handy for quick reference! 📎**

For detailed information, see the full documentation files listed above.

