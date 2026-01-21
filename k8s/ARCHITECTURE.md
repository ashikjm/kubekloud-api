# Deployment Architecture

This document provides detailed architectural diagrams for the KubeKloud API Kubernetes deployment.

## Component Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                     Kubernetes Cluster                          │
│                                                                 │
│  ┌───────────────────────────────────────────────────────────┐ │
│  │           Harbor Namespace (harbor-system)                │ │
│  │  ┌──────────────────────────────────────────────────────┐ │ │
│  │  │  Harbor Services                                     │ │ │
│  │  │  ┌────────┐ ┌─────────┐ ┌──────────┐ ┌──────────┐ │ │ │
│  │  │  │ Portal │ │ Core    │ │ Registry │ │JobService│ │ │ │
│  │  │  │ (UI)   │ │ (API)   │ │ (Images) │ │ (Tasks)  │ │ │ │
│  │  │  └───┬────┘ └────┬────┘ └─────┬────┘ └─────┬────┘ │ │ │
│  │  │      │           │            │            │       │ │ │
│  │  │  ┌───▼───────────▼────────────▼────────────▼────┐ │ │ │
│  │  │  │            PostgreSQL Database              │ │ │ │
│  │  │  │  - Harbor metadata                          │ │ │ │
│  │  │  │  - PVC: 5Gi                                 │ │ │ │
│  │  │  └─────────────────────────────────────────────┘ │ │ │
│  │  │                                                    │ │ │
│  │  │  ┌─────────────┐  ┌──────────────────────────┐  │ │ │
│  │  │  │   Redis     │  │  Trivy Scanner           │  │ │ │
│  │  │  │  (Cache)    │  │  (Vulnerability Scan)    │  │ │ │
│  │  │  └─────────────┘  └──────────────────────────┘  │ │ │
│  │  │                                                    │ │ │
│  │  │  Storage:                                          │ │ │
│  │  │  - Registry: 20Gi PVC (container images)          │ │ │
│  │  │  - Database: 5Gi PVC (metadata)                   │ │ │
│  │  │  - Trivy: 5Gi PVC (vulnerability DB)              │ │ │
│  │  └──────────────────────────────────────────────────┘ │ │
│  │                                                         │ │
│  │  Exposed via:                                           │ │
│  │  - NodePort: 30002 (HTTP)                               │ │
│  │  - Or LoadBalancer (production)                         │ │
│  └─────────────────────────┬───────────────────────────────┘ │
│                            │                                  │
│            Image Pull: harbor.local:30002/kubekloud/*        │
│                            │                                  │
│                            ▼                                  │
│  ┌───────────────────────────────────────────────────────┐  │
│  │        KubeKloud API Namespace (kubekloud-api)         │  │
│  │                                                        │  │
│  │  ┌──────────────────────────────────────────────────┐ │  │
│  │  │  API Deployment                                  │ │  │
│  │  │  ┌──────────────┐      ┌──────────────┐        │ │  │
│  │  │  │  API Pod 1   │      │  API Pod 2   │        │ │  │
│  │  │  │              │      │              │        │ │  │
│  │  │  │ FastAPI App  │      │ FastAPI App  │        │ │  │
│  │  │  │ Port: 8000   │      │ Port: 8000   │        │ │  │
│  │  │  │              │      │              │        │ │  │
│  │  │  │ Resources:   │      │ Resources:   │        │ │  │
│  │  │  │ 256Mi-512Mi  │      │ 256Mi-512Mi  │        │ │  │
│  │  │  │ 250m-500m    │      │ 250m-500m    │        │ │  │
│  │  │  │              │      │              │        │ │  │
│  │  │  │ Health:      │      │ Health:      │        │ │  │
│  │  │  │ /health ✓    │      │ /health ✓    │        │ │  │
│  │  │  └──────┬───────┘      └──────┬───────┘        │ │  │
│  │  │         │                     │                 │ │  │
│  │  │         └─────────┬───────────┘                 │ │  │
│  │  └───────────────────┼─────────────────────────────┘ │  │
│  │                      │                               │  │
│  │  ┌───────────────────▼─────────────────────────────┐ │  │
│  │  │  Service: kubekloud-api-service                 │ │  │
│  │  │  Type: LoadBalancer                             │ │  │
│  │  │  Port: 80 → 8000                                │ │  │
│  │  │  Selector: app=kubekloud-api                    │ │  │
│  │  └─────────────────────────────────────────────────┘ │  │
│  │                      │                               │  │
│  │                      │ Database Connection           │  │
│  │                      ▼                               │  │
│  │  ┌──────────────────────────────────────────────────┐ │  │
│  │  │  PostgreSQL Deployment                           │ │  │
│  │  │  ┌────────────────────────────────────────────┐  │ │  │
│  │  │  │  postgres:16-alpine                        │  │ │  │
│  │  │  │  Database: kubekloud                       │  │ │  │
│  │  │  │  Port: 5432                                │  │ │  │
│  │  │  │                                            │  │ │  │
│  │  │  │  Resources:                                │  │ │  │
│  │  │  │  - Memory: 256Mi-512Mi                     │  │ │  │
│  │  │  │  - CPU: 250m-500m                          │  │ │  │
│  │  │  │                                            │  │ │  │
│  │  │  │  Health Checks:                            │  │ │  │
│  │  │  │  - pg_isready                              │  │ │  │
│  │  │  └────────────┬───────────────────────────────┘  │ │  │
│  │  │               │                                   │ │  │
│  │  │               ▼                                   │ │  │
│  │  │  ┌────────────────────────────────────────────┐  │ │  │
│  │  │  │  PersistentVolumeClaim                     │  │ │  │
│  │  │  │  - Size: 10Gi                              │  │ │  │
│  │  │  │  - AccessMode: ReadWriteOnce               │  │ │  │
│  │  │  │  - Data persists across pod restarts       │  │ │  │
│  │  │  └────────────────────────────────────────────┘  │ │  │
│  │  └──────────────────────────────────────────────────┘ │  │
│  │                                                        │  │
│  │  ┌──────────────────────────────────────────────────┐ │  │
│  │  │  Service: postgres-service                       │ │  │
│  │  │  Type: ClusterIP (internal only)                 │ │  │
│  │  │  Port: 5432                                      │ │  │
│  │  └──────────────────────────────────────────────────┘ │  │
│  │                                                        │  │
│  │  ┌──────────────────────────────────────────────────┐ │  │
│  │  │  ServiceAccount: kubekloud-api-sa                │ │  │
│  │  │  ClusterRole: kubekloud-api-role                 │ │  │
│  │  │  Permissions:                                    │ │  │
│  │  │  - Manage pods, services, PVCs                   │ │  │
│  │  │  - Manage deployments, statefulsets              │ │  │
│  │  │  - Manage VMs (KubeVirt)                         │ │  │
│  │  └──────────────────────────────────────────────────┘ │  │
│  │                                                        │  │
│  │  ┌──────────────────────────────────────────────────┐ │  │
│  │  │  Secret: harbor-regcred                          │ │  │
│  │  │  Type: kubernetes.io/dockerconfigjson            │ │  │
│  │  │  Used by: API pods for pulling images            │ │  │
│  │  └──────────────────────────────────────────────────┘ │  │
│  └────────────────────────────────────────────────────────┘  │
│                                                              │
│  External Access:                                            │
│  ┌────────────────────────────────────────────────────────┐ │
│  │  Internet → LoadBalancer → API Service → API Pods     │ │
│  │  URL: http://<external-ip>                            │ │
│  └────────────────────────────────────────────────────────┘ │
└──────────────────────────────────────────────────────────────┘
```

## Network Flow

### Image Build and Push Flow

```
Developer Machine
      │
      ├── 1. Build Image
      │   docker build -t harbor.local:30002/kubekloud/api:latest .
      │
      ├── 2. Login to Harbor
      │   docker login harbor.local:30002
      │
      └── 3. Push Image
          docker push harbor.local:30002/kubekloud/api:latest
              │
              ▼
        ┌─────────────────┐
        │  Harbor Registry│
        │  Store & Scan   │
        └────────┬────────┘
                 │
                 │ 4. API Pod pulls image
                 │    using imagePullSecret
                 ▼
          ┌────────────────┐
          │   API Pod      │
          │  (Running)     │
          └────────────────┘
```

### API Request Flow

```
Client Request
      │
      ├── HTTP Request to API
      │
      ▼
┌──────────────────┐
│  LoadBalancer    │  External IP
│  Service         │  Port: 80
└────────┬─────────┘
         │
         ├── Routes to one of:
         │
    ┌────▼─────┐     ┌──────────┐
    │ API Pod 1│ or  │API Pod 2 │
    └────┬─────┘     └─────┬────┘
         │                 │
         └────────┬────────┘
                  │
                  ├── Reads/Writes data
                  │
                  ▼
         ┌─────────────────┐
         │   PostgreSQL    │
         │   (Port 5432)   │
         └─────────────────┘
```

### Database Connection Flow

```
API Pod
  │
  ├── Read DATABASE_URL from Secret
  │   postgresql://user:pass@postgres-service:5432/kubekloud
  │
  ├── Resolve DNS: postgres-service → ClusterIP
  │
  └── Connect via ClusterIP
        │
        ▼
  ┌──────────────────┐
  │ PostgreSQL Pod   │
  │ Port: 5432       │
  └────────┬─────────┘
           │
           ├── Reads/Writes
           │
           ▼
  ┌──────────────────┐
  │  PersistentVolume│
  │  10Gi Storage    │
  └──────────────────┘
```

## Resource Allocation

### Harbor System

| Component | Memory Request | Memory Limit | CPU Request | CPU Limit | Storage |
|-----------|----------------|--------------|-------------|-----------|---------|
| Core | 256Mi | 512Mi | 250m | 1000m | - |
| Portal | 256Mi | 512Mi | 100m | 500m | - |
| Registry | 256Mi | 512Mi | 100m | 500m | 20Gi PVC |
| Database | - | - | - | - | 5Gi PVC |
| Redis | - | - | - | - | 1Gi PVC |
| Trivy | 256Mi | 1Gi | 200m | 1000m | 5Gi PVC |
| **Total** | **~1Gi** | **~3Gi** | **~650m** | **~3.5** | **31Gi** |

### KubeKloud API System

| Component | Memory Request | Memory Limit | CPU Request | CPU Limit | Storage |
|-----------|----------------|--------------|-------------|-----------|---------|
| API Pod (×2) | 512Mi | 1Gi | 500m | 1000m | - |
| PostgreSQL | 256Mi | 512Mi | 250m | 500m | 10Gi PVC |
| **Total** | **768Mi** | **1.5Gi** | **750m** | **1.5** | **10Gi** |

### Cluster Requirements

**Minimum:**
- 3 nodes (for HA)
- 2Gi RAM per node (6Gi total)
- 2 CPU cores per node (6 cores total)
- 50Gi storage

**Recommended:**
- 3+ nodes
- 4Gi+ RAM per node
- 4+ CPU cores per node
- 100Gi+ storage

## Security Architecture

```
┌─────────────────────────────────────────────────────────┐
│  Security Layers                                        │
│                                                         │
│  ┌───────────────────────────────────────────────────┐ │
│  │  1. Network Layer                                 │ │
│  │  - LoadBalancer (external access control)         │ │
│  │  - ClusterIP (internal services only)             │ │
│  │  - Network Policies (optional, recommended)       │ │
│  └───────────────────────────────────────────────────┘ │
│                                                         │
│  ┌───────────────────────────────────────────────────┐ │
│  │  2. Authentication & Authorization                │ │
│  │  - Harbor: Admin + Robot Accounts                 │ │
│  │  - Kubernetes: ServiceAccount + RBAC              │ │
│  │  - imagePullSecret: harbor-regcred                │ │
│  └───────────────────────────────────────────────────┘ │
│                                                         │
│  ┌───────────────────────────────────────────────────┐ │
│  │  3. Data Protection                               │ │
│  │  - Secrets: Encrypted at rest                     │ │
│  │  - Database credentials in Secret                 │ │
│  │  - Harbor credentials in Secret                   │ │
│  └───────────────────────────────────────────────────┘ │
│                                                         │
│  ┌───────────────────────────────────────────────────┐ │
│  │  4. Container Security                            │ │
│  │  - Non-root user (UID 1000)                       │ │
│  │  - No privilege escalation                        │ │
│  │  - Vulnerability scanning with Trivy              │ │
│  │  - Resource limits enforced                       │ │
│  └───────────────────────────────────────────────────┘ │
│                                                         │
│  ┌───────────────────────────────────────────────────┐ │
│  │  5. Storage Security                              │ │
│  │  - PVCs with access mode restrictions             │ │
│  │  - Data persistence across restarts               │ │
│  │  - Backup strategy recommended                    │ │
│  └───────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────┘
```

## High Availability

```
┌────────────────────────────────────────────────────┐
│  HA Configuration                                  │
│                                                    │
│  API Layer (Active-Active)                        │
│  ┌──────────┐  ┌──────────┐                      │
│  │ Pod 1    │  │ Pod 2    │  Can scale to N pods │
│  │ Ready ✓  │  │ Ready ✓  │                      │
│  └────┬─────┘  └────┬─────┘                      │
│       │             │                             │
│       └──────┬──────┘                             │
│              │                                     │
│    ┌─────────▼─────────┐                         │
│    │  LoadBalancer     │  Distributes traffic    │
│    │  Health checks    │                         │
│    └───────────────────┘                         │
│                                                    │
│  Database Layer (Single Instance)                 │
│  ┌───────────────────┐                           │
│  │  PostgreSQL Pod   │  Data persists in PVC     │
│  │  PVC: 10Gi        │  Survives pod restarts    │
│  └───────────────────┘                           │
│                                                    │
│  Harbor Registry (Multiple Components)            │
│  - Core, Portal, Registry all HA-capable          │
│  - Shared storage via PVCs                        │
│  - Can scale components individually              │
└────────────────────────────────────────────────────┘
```

## Deployment States

```
Initial State:         After Harbor Setup:      After API Deploy:
                                                
Nothing               Harbor Running           Complete System
                      ↓                        ↓
                      ┌──────────┐            ┌──────────┐
                      │ Harbor   │            │ Harbor   │
                      │ Registry │            │ Registry │
                      └──────────┘            └────┬─────┘
                                                   │ provides images
                                                   ▼
                                              ┌──────────┐
                                              │   API    │
                                              │  + DB    │
                                              └──────────┘
```

## Monitoring Points

```
┌─────────────────────────────────────────────────────┐
│  Recommended Monitoring                             │
│                                                     │
│  Harbor:                                            │
│  ├── /metrics endpoint (Prometheus)                │
│  ├── Pod health (kubectl get pods)                 │
│  ├── Disk usage (PVC utilization)                  │
│  └── API response times                            │
│                                                     │
│  API:                                               │
│  ├── /health endpoint                              │
│  ├── Pod health & restarts                         │
│  ├── Response times                                │
│  ├── Error rates                                   │
│  └── Database connection pool                      │
│                                                     │
│  Database:                                          │
│  ├── pg_isready checks                             │
│  ├── Connection count                              │
│  ├── Query performance                             │
│  ├── Disk usage                                    │
│  └── Backup status                                 │
│                                                     │
│  Cluster:                                           │
│  ├── Node resources (CPU, memory)                  │
│  ├── PVC usage                                     │
│  ├── Network traffic                               │
│  └── Pod autoscaling metrics                       │
└─────────────────────────────────────────────────────┘
```

## Backup Strategy

```
┌──────────────────────────────────────────────────────┐
│  Recommended Backup Approach                         │
│                                                      │
│  Daily:                                              │
│  ├── PostgreSQL database dump                       │
│  │   kubectl exec postgres-pod -- pg_dump ...       │
│  │                                                   │
│  └── Harbor database dump                           │
│      kubectl exec harbor-db -- pg_dumpall ...       │
│                                                      │
│  Weekly:                                             │
│  ├── PVC snapshots (if supported by storage class)  │
│  └── Kubernetes resource definitions                │
│      kubectl get all -n kubekloud-api -o yaml       │
│                                                      │
│  Tools to Consider:                                  │
│  ├── Velero (cluster-wide backup)                   │
│  ├── Stash (database backup operator)               │
│  └── Native cloud backup (EBS snapshots, etc.)      │
└──────────────────────────────────────────────────────┘
```

## Scaling Strategies

### Horizontal Pod Autoscaling

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: kubekloud-api-hpa
  namespace: kubekloud-api
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: kubekloud-api
  minReplicas: 2
  maxReplicas: 10
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
  - type: Resource
    resource:
      name: memory
      target:
        type: Utilization
        averageUtilization: 80
```

### Vertical Scaling

Adjust resource limits in deployment files:
- Increase memory for heavy workloads
- Increase CPU for compute-intensive operations
- Increase storage for growing data

## Disaster Recovery

```
Disaster Scenario → Recovery Steps:

1. Pod Failure
   ├── Automatic: Kubernetes restarts pod
   └── Manual: kubectl delete pod (forces recreation)

2. Node Failure
   ├── Automatic: Pods rescheduled to healthy nodes
   └── Ensure: Multiple replicas spread across nodes

3. Database Corruption
   ├── Restore from backup
   └── kubectl exec -i postgres-pod -- psql < backup.sql

4. Complete Namespace Loss
   ├── Recreate namespace
   ├── Apply manifests: kubectl apply -k k8s/
   └── Restore database from backup

5. Cluster Failure
   ├── New cluster setup
   ├── Restore PVCs from snapshots
   ├── Deploy applications
   └── Restore data from backups
```

## References

- **Main Deployment Guide:** `../DEPLOYMENT.md`
- **Harbor Setup:** `harbor/HARBOR_SETUP.md`
- **Kubernetes Docs:** https://kubernetes.io/docs/
- **Harbor Docs:** https://goharbor.io/docs/

