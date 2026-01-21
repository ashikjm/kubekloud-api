# Harbor Container Registry

This directory contains everything needed to deploy Harbor container registry in your Kubernetes cluster.

## What's Included

### Configuration Files
- **`namespace.yaml`** - Harbor namespace definition
- **`values.yaml`** - Helm chart values for Harbor deployment

### Scripts
- **`setup-harbor.sh`** - Automated Harbor installation via Helm
- **`configure-harbor.sh`** - Post-installation configuration (project, robot account)

### Documentation
- **`QUICKSTART.md`** - Quick start guide (5 steps to get running)
- **`HARBOR_SETUP.md`** - Comprehensive setup and configuration guide
- **`README.md`** - This file

## Quick Start

```bash
# From the harbor directory:

# 1. Install Harbor
./setup-harbor.sh

# 2. Configure Harbor
./configure-harbor.sh

# 3. Build and push image
./build-push-harbor.sh

# 4. Deploy API
cd ..
./deploy.sh
```

## Harbor Components

Harbor consists of several services:

- **Core API** - Main API server
- **Portal** - Web UI
- **Registry** - Docker registry (image storage)
- **PostgreSQL** - Metadata database
- **Redis** - Caching layer
- **Trivy** - Vulnerability scanner
- **Jobservice** - Background jobs

## Default Configuration

- **Namespace:** `harbor-system`
- **Exposure:** NodePort (port 30002)
- **TLS:** Disabled (for development)
- **Storage:** 20Gi for images
- **Admin Password:** `Harbor12345` (⚠️ Change this!)

## Resource Requirements

**Minimum:**
- 4GB RAM
- 2 CPU cores
- 32Gi storage

**Recommended for Production:**
- 8GB+ RAM
- 4+ CPU cores
- 100Gi+ storage

## Access Harbor

### Via NodePort (default)

```bash
# Get node IP
kubectl get nodes -o wide

# Access at: http://<node-ip>:30002
```

### Via Port Forward

```bash
kubectl port-forward -n harbor-system svc/harbor-portal 8080:80
# Access at: http://localhost:8080
```

### Via LoadBalancer (production)

```bash
helm upgrade harbor harbor/harbor \
  --namespace harbor-system \
  --reuse-values \
  --set expose.type=loadBalancer
```

## Usage

### Login to Harbor

```bash
docker login harbor.local:30002
# Username: admin
# Password: Harbor12345
```

### Push Images

```bash
# Tag image
docker tag myimage:latest harbor.local:30002/kubekloud/myimage:latest

# Push
docker push harbor.local:30002/kubekloud/myimage:latest
```

### Pull Images

```bash
docker pull harbor.local:30002/kubekloud/myimage:latest
```

## Kubernetes Integration

The API deployment automatically uses Harbor:

- **Image:** `harbor.local:30002/kubekloud/kubekloud-api:latest`
- **Secret:** `harbor-regcred` (created by configure-harbor.sh)
- **Pull Policy:** Always

## Management

### View Status

```bash
# Helm release
helm status harbor -n harbor-system

# Pods
kubectl get pods -n harbor-system

# Services
kubectl get svc -n harbor-system

# Storage
kubectl get pvc -n harbor-system
```

### View Logs

```bash
# All components
kubectl logs -n harbor-system -l app=harbor

# Specific component
kubectl logs -n harbor-system -l component=core -f
```

### Upgrade Harbor

```bash
helm repo update
helm upgrade harbor harbor/harbor \
  --namespace harbor-system \
  --values values.yaml
```

### Uninstall Harbor

```bash
helm uninstall harbor -n harbor-system
kubectl delete namespace harbor-system

# Clean up PVCs
kubectl delete pvc --all -n harbor-system
```

## Configuration Options

Edit `values.yaml` to customize:

### Change Exposure Type

```yaml
expose:
  type: loadBalancer  # or ingress
```

### Enable TLS

```yaml
expose:
  tls:
    enabled: true
    certSource: auto  # or secret
```

### Adjust Storage

```yaml
persistence:
  persistentVolumeClaim:
    registry:
      size: 100Gi  # Increase for more images
```

### Adjust Resources

```yaml
core:
  resources:
    requests:
      memory: 512Mi
      cpu: 500m
```

## Security

### Change Admin Password

1. Access Harbor UI
2. Click admin → Change Password
3. Or via API:

```bash
curl -X PUT "http://harbor.local:30002/api/v2.0/users/1/password" \
  -u "admin:Harbor12345" \
  -H "Content-Type: application/json" \
  -d '{
    "old_password": "Harbor12345",
    "new_password": "NewSecurePassword123!"
  }'
```

### Create Robot Account

Run `./configure-harbor.sh` or manually:

1. Projects → kubekloud → Robot Accounts
2. NEW ROBOT ACCOUNT
3. Name: `kubekloud-api-robot`
4. Permissions: Pull & Push
5. Save the token

### Enable Vulnerability Scanning

Already enabled in `values.yaml`. View scans:

1. Projects → kubekloud → Repositories
2. Click image → Scan

## Troubleshooting

### Pods Not Starting

```bash
# Check events
kubectl get events -n harbor-system --sort-by='.lastTimestamp'

# Describe pod
kubectl describe pod -n harbor-system <pod-name>

# Common issues:
# - Insufficient resources
# - PVC binding issues
# - Image pull errors
```

### Cannot Access UI

```bash
# Check service
kubectl get svc harbor-portal -n harbor-system

# Port forward to test
kubectl port-forward -n harbor-system svc/harbor-portal 8080:80
```

### Cannot Push Images

```bash
# Check Docker daemon config
docker info | grep "Insecure Registries"

# Should show: harbor.local:30002

# Add to /etc/docker/daemon.json:
{
  "insecure-registries": ["harbor.local:30002"]
}

# Restart Docker
```

### Database Issues

```bash
# Check database pod
kubectl get pod -n harbor-system -l component=database

# View logs
kubectl logs -n harbor-system -l component=database

# Connect to database
kubectl exec -it -n harbor-system harbor-database-0 -- psql -U postgres
```

## Backup & Restore

### Backup

```bash
# Database
kubectl exec -n harbor-system harbor-database-0 -- \
  pg_dumpall -U postgres > harbor-db-backup.sql

# Registry data (copy PVC)
# Use Velero or similar tool
```

### Restore

```bash
# Database
kubectl exec -i -n harbor-system harbor-database-0 -- \
  psql -U postgres < harbor-db-backup.sql
```

## Monitoring

### Resource Usage

```bash
kubectl top pods -n harbor-system
```

### Enable Metrics

```yaml
metrics:
  enabled: true
```

Metrics will be available at `/metrics` endpoint.

### Integration with Prometheus

```yaml
metrics:
  enabled: true
  serviceMonitor:
    enabled: true
```

## Production Checklist

- [ ] Change admin password
- [ ] Enable HTTPS/TLS
- [ ] Use LoadBalancer or Ingress
- [ ] Configure proper domain
- [ ] Increase storage size
- [ ] Set up backups
- [ ] Configure retention policies
- [ ] Enable vulnerability scanning
- [ ] Set up monitoring
- [ ] Configure image replication
- [ ] Use robot accounts for CI/CD
- [ ] Enable audit logs
- [ ] Configure LDAP/OIDC (if needed)

## Resources

- **Harbor Docs:** https://goharbor.io/docs/
- **Helm Chart:** https://github.com/goharbor/harbor-helm
- **GitHub:** https://github.com/goharbor/harbor

## Support

For issues:
1. Check Harbor logs: `kubectl logs -n harbor-system -l app=harbor`
2. Review this documentation
3. See HARBOR_SETUP.md for detailed guides
4. Check Harbor GitHub issues

## Scripts Reference

| Script | Purpose | Usage |
|--------|---------|-------|
| `setup-harbor.sh` | Install Harbor | `./setup-harbor.sh` |
| `configure-harbor.sh` | Configure project & robot | `./configure-harbor.sh` |
| `build-push-harbor.sh` | Build & push API image | `./build-push-harbor.sh` |
| `deploy-with-harbor.sh` | Complete setup | `./deploy-with-harbor.sh` |

## Next Steps

1. ✅ Harbor installed
2. 🔐 Change admin password
3. 📦 Push your first image
4. 🔍 Enable vulnerability scanning
5. 🌐 Configure ingress for production
6. 💾 Set up backups

