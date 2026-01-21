# Namespace Isolation Architecture

## Overview

Each cluster in the Cloud Management Platform is deployed in its own dedicated Kubernetes namespace. This provides strong isolation and simplified resource management.

## Naming Convention

```
Cluster Name: my-cluster
Namespace:    my-cluster-ns
```

All instances within that cluster are deployed in the `my-cluster-ns` namespace.

## Visual Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                    Kubernetes Cluster                            │
│                                                                   │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  Namespace: cluster-a-ns                                  │  │
│  │                                                             │  │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐      │  │
│  │  │  Pod/VM     │  │  Pod/VM     │  │  Pod/VM     │      │  │
│  │  │ instance-0  │  │ instance-1  │  │ instance-2  │      │  │
│  │  └─────────────┘  └─────────────┘  └─────────────┘      │  │
│  │                                                             │  │
│  │  Labels: managed-by=cmp, cluster=cluster-a                │  │
│  └──────────────────────────────────────────────────────────┘  │
│                                                                   │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  Namespace: cluster-b-ns                                  │  │
│  │                                                             │  │
│  │  ┌─────────────┐  ┌─────────────┐                        │  │
│  │  │  Pod/VM     │  │  Pod/VM     │                        │  │
│  │  │ instance-0  │  │ instance-1  │                        │  │
│  │  └─────────────┘  └─────────────┘                        │  │
│  │                                                             │  │
│  │  Labels: managed-by=cmp, cluster=cluster-b                │  │
│  └──────────────────────────────────────────────────────────┘  │
│                                                                   │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  Namespace: my-app-ns                                     │  │
│  │                                                             │  │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐      │  │
│  │  │  Pod/VM     │  │  Pod/VM     │  │  Pod/VM     │      │  │
│  │  │ instance-0  │  │ instance-1  │  │ instance-2  │      │  │
│  │  └─────────────┘  └─────────────┘  └─────────────┘      │  │
│  │                                                             │  │
│  │  Labels: managed-by=cmp, cluster=my-app                   │  │
│  └──────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
```

## Benefits

### 1. Resource Isolation
- Network isolation (with NetworkPolicies)
- Resource quota enforcement per cluster
- No naming conflicts between clusters
- Clear resource boundaries

### 2. Simplified Management
- **Delete cluster** → Deletes namespace → All resources cleaned up automatically
- Easy to see all resources for a cluster: `kubectl get all -n my-cluster-ns`
- Simplified debugging and troubleshooting

### 3. Security
- RBAC can be applied per namespace/cluster
- Service accounts scoped to namespace
- Network policies for cluster isolation
- Fine-grained access control

### 4. Organization
- Logical grouping of related resources
- Clear ownership and responsibility
- Easy resource accounting and tracking
- Better audit trails

### 5. Multi-tenancy Support
- Each user's clusters are in separate namespaces
- Foundation for per-cluster billing/accounting
- Easier to implement quotas and limits
- Supports future multi-cluster scenarios

## Implementation Details

### Cluster Creation Flow

```python
# 1. User creates cluster
POST /api/v1/clusters/
{
  "name": "my-app",
  "instance_type": "container",
  "cpu_per_instance": 2,
  "memory_per_instance": 4,
  "instance_count": 3
}

# 2. System generates namespace name
namespace = "my-app-ns"

# 3. Create namespace in Kubernetes
kubectl create namespace my-app-ns

# 4. Add labels
kubectl label namespace my-app-ns \
  managed-by=cmp \
  cluster-namespace=true

# 5. Create instances in that namespace
kubectl apply -f pod-0.yaml -n my-app-ns
kubectl apply -f pod-1.yaml -n my-app-ns
kubectl apply -f pod-2.yaml -n my-app-ns
```

### Cluster Deletion Flow

```python
# 1. User deletes cluster
DELETE /api/v1/clusters/1

# 2. System deletes individual instances (optional)
# This step is technically optional since deleting the namespace
# will cascade delete all resources

# 3. Delete the namespace
kubectl delete namespace my-app-ns

# 4. Kubernetes automatically:
#    - Terminates all pods/VMs
#    - Deletes all services
#    - Removes all configmaps/secrets
#    - Cleans up all resources in namespace
```

## Kubernetes Commands

### List all CMP-managed namespaces
```bash
kubectl get namespaces -l managed-by=cmp
```

### View resources in a cluster
```bash
kubectl get all -n my-cluster-ns
```

### Monitor a cluster's pods
```bash
kubectl get pods -n my-cluster-ns -w
```

### View resource usage
```bash
kubectl top pods -n my-cluster-ns
```

### Describe namespace
```bash
kubectl describe namespace my-cluster-ns
```

## Future Enhancements

### 1. Resource Quotas per Namespace
```yaml
apiVersion: v1
kind: ResourceQuota
metadata:
  name: cluster-quota
  namespace: my-cluster-ns
spec:
  hard:
    requests.cpu: "10"
    requests.memory: "20Gi"
    persistentvolumeclaims: "10"
```

### 2. Network Policies
```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: deny-from-other-namespaces
  namespace: my-cluster-ns
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  ingress:
  - from:
    - podSelector: {}  # Allow from same namespace only
```

### 3. Limit Ranges
```yaml
apiVersion: v1
kind: LimitRange
metadata:
  name: resource-limits
  namespace: my-cluster-ns
spec:
  limits:
  - max:
      cpu: "4"
      memory: "8Gi"
    min:
      cpu: "100m"
      memory: "128Mi"
    type: Container
```

### 4. Service Accounts and RBAC
```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: cluster-sa
  namespace: my-cluster-ns
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: cluster-admin
  namespace: my-cluster-ns
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: admin
subjects:
- kind: ServiceAccount
  name: cluster-sa
  namespace: my-cluster-ns
```

## Best Practices

1. **Naming**: Keep cluster names DNS-compliant (lowercase, alphanumeric, hyphens)
2. **Labels**: Add custom labels for better organization
3. **Monitoring**: Set up namespace-level monitoring and alerting
4. **Quotas**: Consider adding ResourceQuotas for production
5. **Network Policies**: Implement network isolation for sensitive workloads
6. **Cleanup**: The system automatically cleans up namespaces on cluster deletion

## Troubleshooting

### Namespace stuck in "Terminating"
```bash
# Check for finalizers
kubectl get namespace my-cluster-ns -o yaml

# Force delete if needed (use with caution)
kubectl delete namespace my-cluster-ns --grace-period=0 --force
```

### View namespace events
```bash
kubectl get events -n my-cluster-ns --sort-by='.lastTimestamp'
```

### Check namespace resource usage
```bash
kubectl describe resourcequota -n my-cluster-ns
kubectl top pods -n my-cluster-ns
```

