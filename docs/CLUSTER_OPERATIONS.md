# Cluster Operations Guide

## Overview

This guide covers all available operations for managing clusters in the Cloud Management Platform.

## Cluster Lifecycle Operations

### 1. Create Cluster

Create a new cluster with multiple homogeneous instances.

**Endpoint:** `POST /api/v1/clusters/`

**Payload:**
```json
{
  "name": "my-cluster",
  "instance_type": "container",
  "cpu_per_instance": 2.0,
  "memory_per_instance": 4.0,
  "instance_count": 3
}
```

**Response:**
```json
{
  "id": 1,
  "name": "my-cluster",
  "namespace": "my-cluster-ns",
  "instance_type": "container",
  "cpu_per_instance": 2.0,
  "memory_per_instance": 4.0,
  "instance_count": 3,
  "owner_id": 1,
  "created_at": "2025-01-09T10:00:00"
}
```

**What happens:**
- ✅ Validates cluster name is unique
- ✅ Checks user quota availability
- ✅ Creates Kubernetes namespace (`<cluster-name>-ns`)
- ✅ Creates all instances in the namespace
- ✅ Updates user quota usage

---

### 2. List Clusters

List all clusters owned by the authenticated user.

**Endpoint:** `GET /api/v1/clusters/`

**Response:**
```json
[
  {
    "id": 1,
    "name": "cluster-a",
    "namespace": "cluster-a-ns",
    "instance_type": "container",
    "cpu_per_instance": 2.0,
    "memory_per_instance": 4.0,
    "instance_count": 3,
    "owner_id": 1,
    "created_at": "2025-01-09T10:00:00"
  },
  {
    "id": 2,
    "name": "cluster-b",
    "namespace": "cluster-b-ns",
    "instance_type": "vm",
    "cpu_per_instance": 4.0,
    "memory_per_instance": 8.0,
    "instance_count": 2,
    "owner_id": 1,
    "created_at": "2025-01-09T11:00:00"
  }
]
```

---

### 3. Get Cluster Details

Get detailed information about a specific cluster including all its instances.

**Endpoint:** `GET /api/v1/clusters/{cluster_id}`

**Response:**
```json
{
  "id": 1,
  "name": "my-cluster",
  "namespace": "my-cluster-ns",
  "instance_type": "container",
  "cpu_per_instance": 2.0,
  "memory_per_instance": 4.0,
  "instance_count": 3,
  "owner_id": 1,
  "created_at": "2025-01-09T10:00:00",
  "instances": [
    {
      "id": 1,
      "cluster_id": 1,
      "instance_name": "my-cluster-instance-0",
      "status": "running",
      "k8s_resource_name": "my-cluster-instance-0",
      "created_at": "2025-01-09T10:00:00",
      "updated_at": "2025-01-09T10:00:00"
    },
    {
      "id": 2,
      "cluster_id": 1,
      "instance_name": "my-cluster-instance-1",
      "status": "running",
      "k8s_resource_name": "my-cluster-instance-1",
      "created_at": "2025-01-09T10:00:00",
      "updated_at": "2025-01-09T10:00:00"
    },
    {
      "id": 3,
      "cluster_id": 1,
      "instance_name": "my-cluster-instance-2",
      "status": "running",
      "k8s_resource_name": "my-cluster-instance-2",
      "created_at": "2025-01-09T10:00:00",
      "updated_at": "2025-01-09T10:00:00"
    }
  ]
}
```

---

### 4. Suspend Cluster

Suspend all running instances in a cluster. This is useful for:
- **Cost savings** - Stop paying for running instances
- **Maintenance windows** - Temporarily pause workloads
- **Development environments** - Suspend when not in use

**Endpoint:** `POST /api/v1/clusters/{cluster_id}/suspend`

**No payload required**

**Response:**
```json
{
  "message": "Cluster 'my-cluster' suspend operation completed",
  "detail": {
    "cluster_id": 1,
    "total_instances": 3,
    "suspended": 3,
    "failed": 0,
    "skipped": 0
  }
}
```

**Behavior:**
- ✅ Only suspends instances with status `running`
- ✅ Skips instances that are already `stopped`, `suspended`, `pending`, or `failed`
- ✅ Updates each instance status to `suspended` on success
- ✅ Provides detailed count of operations performed

**Example:**
```bash
curl -X POST "http://localhost:8000/api/v1/clusters/1/suspend" \
  -H "Authorization: Bearer your-token"
```

---

### 5. Resume Cluster

Resume all suspended instances in a cluster.

**Endpoint:** `POST /api/v1/clusters/{cluster_id}/resume`

**No payload required**

**Response:**
```json
{
  "message": "Cluster 'my-cluster' resume operation completed",
  "detail": {
    "cluster_id": 1,
    "total_instances": 3,
    "resumed": 3,
    "failed": 0,
    "skipped": 0
  }
}
```

**Behavior:**
- ✅ Only resumes instances with status `suspended`
- ✅ Skips instances that are `running`, `stopped`, `pending`, or `failed`
- ✅ Updates each instance status to `running` on success
- ✅ Provides detailed count of operations performed

**Example:**
```bash
curl -X POST "http://localhost:8000/api/v1/clusters/1/resume" \
  -H "Authorization: Bearer your-token"
```

---

### 6. Delete Cluster

Permanently delete a cluster and all its instances. This action:
- ❌ **Cannot be undone**
- ✅ Deletes all instances
- ✅ Deletes the Kubernetes namespace
- ✅ Releases quota back to the user

**Endpoint:** `DELETE /api/v1/clusters/{cluster_id}`

**Response:**
```json
{
  "message": "Cluster 'my-cluster' deleted successfully",
  "detail": {
    "instances_deleted": 3,
    "namespace_deleted": "my-cluster-ns",
    "cpu_released": 6.0,
    "memory_released": 12.0
  }
}
```

**Example:**
```bash
curl -X DELETE "http://localhost:8000/api/v1/clusters/1" \
  -H "Authorization: Bearer your-token"
```

---

## Complete Workflow Examples

### Development Environment Pattern

```bash
# Morning: Resume cluster when starting work
curl -X POST "http://localhost:8000/api/v1/clusters/1/resume" \
  -H "Authorization: Bearer dev-token"

# ... work throughout the day ...

# Evening: Suspend cluster to save costs
curl -X POST "http://localhost:8000/api/v1/clusters/1/suspend" \
  -H "Authorization: Bearer dev-token"
```

### Testing New Configuration

```bash
# 1. Create test cluster
curl -X POST "http://localhost:8000/api/v1/clusters/" \
  -H "Authorization: Bearer token" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "test-cluster",
    "instance_type": "container",
    "cpu_per_instance": 1,
    "memory_per_instance": 2,
    "instance_count": 2
  }'

# 2. Run tests...

# 3. Suspend while analyzing results
curl -X POST "http://localhost:8000/api/v1/clusters/1/suspend" \
  -H "Authorization: Bearer token"

# 4. Make decision: delete if done, resume if need more testing
curl -X DELETE "http://localhost:8000/api/v1/clusters/1" \
  -H "Authorization: Bearer token"
```

### Cost Optimization Pattern

```bash
# Check current clusters
curl -X GET "http://localhost:8000/api/v1/clusters/" \
  -H "Authorization: Bearer token"

# Suspend non-critical clusters during off-hours
curl -X POST "http://localhost:8000/api/v1/clusters/5/suspend" \
  -H "Authorization: Bearer token"
curl -X POST "http://localhost:8000/api/v1/clusters/7/suspend" \
  -H "Authorization: Bearer token"

# Resume during business hours
curl -X POST "http://localhost:8000/api/v1/clusters/5/resume" \
  -H "Authorization: Bearer token"
```

---

## Operation Comparison

| Operation | Instances Affected | Status Change | Quota Impact | Reversible |
|-----------|-------------------|---------------|--------------|------------|
| **Suspend** | Only `running` | `running` → `suspended` | No change | Yes (resume) |
| **Resume** | Only `suspended` | `suspended` → `running` | No change | Yes (suspend) |
| **Delete** | All | All → deleted | Released | No |

---

## Status After Operations

### Suspend Operation

**Before:**
- Instance 1: `running` ✅ → `suspended`
- Instance 2: `running` ✅ → `suspended`
- Instance 3: `stopped` ⏭️ → `stopped` (skipped)
- Instance 4: `failed` ⏭️ → `failed` (skipped)

**After:** 2 suspended, 0 failed, 2 skipped

### Resume Operation

**Before:**
- Instance 1: `suspended` ✅ → `running`
- Instance 2: `suspended` ✅ → `running`
- Instance 3: `running` ⏭️ → `running` (skipped)
- Instance 4: `stopped` ⏭️ → `stopped` (skipped)

**After:** 2 resumed, 0 failed, 2 skipped

---

## Error Handling

### Cluster Not Found
```json
{
  "detail": "Cluster with id 999 not found"
}
```
**Status Code:** 404

### Insufficient Permissions
If the cluster belongs to another user:
```json
{
  "detail": "Cluster with id 5 not found"
}
```
**Status Code:** 404 (for security reasons, we don't reveal existence)

### Partial Failures
If some instances fail to suspend/resume:
```json
{
  "message": "Cluster 'my-cluster' suspend operation completed",
  "detail": {
    "cluster_id": 1,
    "total_instances": 5,
    "suspended": 3,
    "failed": 2,
    "skipped": 0
  }
}
```
**Status Code:** 200 (partial success is still reported as success)

---

## Best Practices

1. **Use suspend/resume for cost optimization**
   - Suspend development clusters outside work hours
   - Suspend test environments when not actively testing

2. **Monitor operation results**
   - Check the `failed` count in responses
   - Investigate failures if count > 0

3. **Check cluster details before operations**
   - Verify instance statuses before suspend/resume
   - Understand current state to predict outcome

4. **Automate suspend/resume schedules**
   - Use cron jobs or schedulers for regular patterns
   - Implement business hours automation

5. **Delete unused clusters**
   - Don't just suspend indefinitely
   - Clean up to release quota for other uses

---

## Monitoring Cluster Operations

### Check Kubernetes directly
```bash
# View all resources in cluster namespace
kubectl get all -n my-cluster-ns

# Watch pod status
kubectl get pods -n my-cluster-ns -w

# View namespace events
kubectl get events -n my-cluster-ns --sort-by='.lastTimestamp'
```

### Check via API
```bash
# Get cluster details with instance statuses
curl -X GET "http://localhost:8000/api/v1/clusters/1" \
  -H "Authorization: Bearer token" | jq
```

### Check quota usage
```bash
# See how suspend affects quota (it doesn't!)
curl -X GET "http://localhost:8000/api/v1/users/me/quota" \
  -H "Authorization: Bearer token" | jq
```

---

## FAQ

**Q: Does suspending a cluster release quota?**
A: No, suspended instances still count toward your quota. Only deleting releases quota.

**Q: What's the difference between suspend and stop?**
A: Suspend is intended for temporary pauses where you plan to resume. Stop is for permanently stopping an instance.

**Q: Can I suspend individual instances?**
A: Yes, use the instance operation endpoint: `POST /api/v1/instances/{id}/operate` with `{"operation": "suspend"}`

**Q: How long does suspend/resume take?**
A: Depends on your Kubernetes cluster, but typically seconds for containers, longer for VMs.

**Q: What happens if I try to suspend an already suspended cluster?**
A: The operation completes successfully with those instances being "skipped" in the response.

