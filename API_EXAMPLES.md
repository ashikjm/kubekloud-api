# API Examples

Complete examples for all API operations.

## Authentication

All requests require a Bearer token in the Authorization header:
```
Authorization: Bearer your-token-here
```

---

## User Operations

### Create User
```bash
curl -X POST "http://localhost:8000/api/v1/users/" \
  -H "Content-Type: application/json" \
  -d '{
    "username": "john",
    "token": "secret-token-123",
    "quota_cpu": 16.0,
    "quota_memory": 64.0
  }'
```

### Get Current User Info
```bash
curl -X GET "http://localhost:8000/api/v1/users/me" \
  -H "Authorization: Bearer secret-token-123"
```

### Check Quota
```bash
curl -X GET "http://localhost:8000/api/v1/users/me/quota" \
  -H "Authorization: Bearer secret-token-123"
```

**Response:**
```json
{
  "total_cpu": 16.0,
  "total_memory": 64.0,
  "used_cpu": 6.0,
  "used_memory": 12.0,
  "available_cpu": 10.0,
  "available_memory": 52.0
}
```

---

## Cluster Operations

### Create Cluster (Containers)
```bash
curl -X POST "http://localhost:8000/api/v1/clusters/" \
  -H "Authorization: Bearer secret-token-123" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "web-cluster",
    "instance_type": "container",
    "cpu_per_instance": 2.0,
    "memory_per_instance": 4.0,
    "instance_count": 3
  }'
```

### Create Cluster (VMs)
```bash
curl -X POST "http://localhost:8000/api/v1/clusters/" \
  -H "Authorization: Bearer secret-token-123" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "vm-cluster",
    "instance_type": "vm",
    "cpu_per_instance": 4.0,
    "memory_per_instance": 8.0,
    "instance_count": 2
  }'
```

### List All Clusters
```bash
curl -X GET "http://localhost:8000/api/v1/clusters/" \
  -H "Authorization: Bearer secret-token-123"
```

### Get Cluster Details
```bash
curl -X GET "http://localhost:8000/api/v1/clusters/1" \
  -H "Authorization: Bearer secret-token-123"
```

**Response:**
```json
{
  "id": 1,
  "name": "web-cluster",
  "namespace": "web-cluster-ns",
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
      "instance_name": "web-cluster-instance-0",
      "status": "running",
      "k8s_resource_name": "web-cluster-instance-0",
      "created_at": "2025-01-09T10:00:00",
      "updated_at": "2025-01-09T10:00:00"
    },
    {
      "id": 2,
      "cluster_id": 1,
      "instance_name": "web-cluster-instance-1",
      "status": "running",
      "k8s_resource_name": "web-cluster-instance-1",
      "created_at": "2025-01-09T10:00:00",
      "updated_at": "2025-01-09T10:00:00"
    },
    {
      "id": 3,
      "cluster_id": 1,
      "instance_name": "web-cluster-instance-2",
      "status": "running",
      "k8s_resource_name": "web-cluster-instance-2",
      "created_at": "2025-01-09T10:00:00",
      "updated_at": "2025-01-09T10:00:00"
    }
  ]
}
```

### Suspend Cluster
```bash
curl -X POST "http://localhost:8000/api/v1/clusters/1/suspend" \
  -H "Authorization: Bearer secret-token-123"
```

**Response:**
```json
{
  "message": "Cluster 'web-cluster' suspend operation completed",
  "detail": {
    "cluster_id": 1,
    "total_instances": 3,
    "suspended": 3,
    "failed": 0,
    "skipped": 0
  }
}
```

### Resume Cluster
```bash
curl -X POST "http://localhost:8000/api/v1/clusters/1/resume" \
  -H "Authorization: Bearer secret-token-123"
```

**Response:**
```json
{
  "message": "Cluster 'web-cluster' resume operation completed",
  "detail": {
    "cluster_id": 1,
    "total_instances": 3,
    "resumed": 3,
    "failed": 0,
    "skipped": 0
  }
}
```

### Delete Cluster
```bash
curl -X DELETE "http://localhost:8000/api/v1/clusters/1" \
  -H "Authorization: Bearer secret-token-123"
```

**Response:**
```json
{
  "message": "Cluster 'web-cluster' deleted successfully",
  "detail": {
    "instances_deleted": 3,
    "namespace_deleted": "web-cluster-ns",
    "cpu_released": 6.0,
    "memory_released": 12.0
  }
}
```

---

## Instance Operations

### Get Instance Details
```bash
curl -X GET "http://localhost:8000/api/v1/instances/1" \
  -H "Authorization: Bearer secret-token-123"
```

**Response:**
```json
{
  "id": 1,
  "cluster_id": 1,
  "instance_name": "web-cluster-instance-0",
  "status": "running",
  "k8s_resource_name": "web-cluster-instance-0",
  "created_at": "2025-01-09T10:00:00",
  "updated_at": "2025-01-09T10:00:00"
}
```

### Stop Instance
```bash
curl -X POST "http://localhost:8000/api/v1/instances/1/operate" \
  -H "Authorization: Bearer secret-token-123" \
  -H "Content-Type: application/json" \
  -d '{"operation": "stop"}'
```

### Start Instance
```bash
curl -X POST "http://localhost:8000/api/v1/instances/1/operate" \
  -H "Authorization: Bearer secret-token-123" \
  -H "Content-Type: application/json" \
  -d '{"operation": "start"}'
```

### Suspend Instance
```bash
curl -X POST "http://localhost:8000/api/v1/instances/1/operate" \
  -H "Authorization: Bearer secret-token-123" \
  -H "Content-Type: application/json" \
  -d '{"operation": "suspend"}'
```

### Resume Instance
```bash
curl -X POST "http://localhost:8000/api/v1/instances/1/operate" \
  -H "Authorization: Bearer secret-token-123" \
  -H "Content-Type: application/json" \
  -d '{"operation": "resume"}'
```

---

## Complete Workflows

### Workflow 1: Development Environment

```bash
# 1. Create user
curl -X POST "http://localhost:8000/api/v1/users/" \
  -H "Content-Type: application/json" \
  -d '{
    "username": "dev-user",
    "token": "dev-token-456",
    "quota_cpu": 20.0,
    "quota_memory": 40.0
  }'

# 2. Create development cluster
curl -X POST "http://localhost:8000/api/v1/clusters/" \
  -H "Authorization: Bearer dev-token-456" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "dev-env",
    "instance_type": "container",
    "cpu_per_instance": 2.0,
    "memory_per_instance": 4.0,
    "instance_count": 2
  }'

# 3. Work during the day...

# 4. Suspend at end of day to save costs
curl -X POST "http://localhost:8000/api/v1/clusters/1/suspend" \
  -H "Authorization: Bearer dev-token-456"

# 5. Next morning, resume cluster
curl -X POST "http://localhost:8000/api/v1/clusters/1/resume" \
  -H "Authorization: Bearer dev-token-456"

# 6. When done with project, delete cluster
curl -X DELETE "http://localhost:8000/api/v1/clusters/1" \
  -H "Authorization: Bearer dev-token-456"
```

### Workflow 2: Testing Different Configurations

```bash
TOKEN="test-token-789"

# Create test clusters with different configs
curl -X POST "http://localhost:8000/api/v1/clusters/" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "test-small",
    "instance_type": "container",
    "cpu_per_instance": 1.0,
    "memory_per_instance": 2.0,
    "instance_count": 3
  }'

curl -X POST "http://localhost:8000/api/v1/clusters/" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "test-large",
    "instance_type": "container",
    "cpu_per_instance": 4.0,
    "memory_per_instance": 8.0,
    "instance_count": 2
  }'

# Run tests on both...

# Keep one, delete the other
curl -X DELETE "http://localhost:8000/api/v1/clusters/1" \
  -H "Authorization: Bearer $TOKEN"

# Suspend the keeper during analysis
curl -X POST "http://localhost:8000/api/v1/clusters/2/suspend" \
  -H "Authorization: Bearer $TOKEN"
```

### Workflow 3: Multi-Cluster Management

```bash
TOKEN="prod-token-123"

# Create multiple clusters
curl -X POST "http://localhost:8000/api/v1/clusters/" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"name": "web-app", "instance_type": "container", "cpu_per_instance": 2, "memory_per_instance": 4, "instance_count": 3}'

curl -X POST "http://localhost:8000/api/v1/clusters/" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"name": "api-backend", "instance_type": "container", "cpu_per_instance": 4, "memory_per_instance": 8, "instance_count": 2}'

curl -X POST "http://localhost:8000/api/v1/clusters/" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"name": "batch-jobs", "instance_type": "vm", "cpu_per_instance": 8, "memory_per_instance": 16, "instance_count": 1}'

# List all clusters
curl -X GET "http://localhost:8000/api/v1/clusters/" \
  -H "Authorization: Bearer $TOKEN"

# Suspend non-critical clusters at night
curl -X POST "http://localhost:8000/api/v1/clusters/3/suspend" \
  -H "Authorization: Bearer $TOKEN"  # batch-jobs

# Check quota after operations
curl -X GET "http://localhost:8000/api/v1/users/me/quota" \
  -H "Authorization: Bearer $TOKEN"
```

---

## Using jq for Pretty Output

Install jq: `brew install jq` (Mac) or `apt-get install jq` (Linux)

```bash
# Pretty print cluster list
curl -s -X GET "http://localhost:8000/api/v1/clusters/" \
  -H "Authorization: Bearer token" | jq

# Extract just cluster names
curl -s -X GET "http://localhost:8000/api/v1/clusters/" \
  -H "Authorization: Bearer token" | jq '.[].name'

# Get instance count per cluster
curl -s -X GET "http://localhost:8000/api/v1/clusters/" \
  -H "Authorization: Bearer token" | jq '.[] | {name: .name, instances: .instance_count}'

# Check quota usage percentage
curl -s -X GET "http://localhost:8000/api/v1/users/me/quota" \
  -H "Authorization: Bearer token" | \
  jq '{cpu_usage: ((.used_cpu / .total_cpu) * 100), memory_usage: ((.used_memory / .total_memory) * 100)}'
```

---

## Error Handling Examples

### Invalid Token
```bash
curl -X GET "http://localhost:8000/api/v1/clusters/" \
  -H "Authorization: Bearer invalid-token"
```
**Response (401):**
```json
{
  "detail": "Invalid authentication token"
}
```

### Insufficient Quota
```bash
curl -X POST "http://localhost:8000/api/v1/clusters/" \
  -H "Authorization: Bearer token" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "big-cluster",
    "instance_type": "container",
    "cpu_per_instance": 100.0,
    "memory_per_instance": 200.0,
    "instance_count": 10
  }'
```
**Response (403):**
```json
{
  "detail": "Insufficient quota. Requested: 1000.0 CPU, 2000.0GB memory. Available: 10.0 CPU, 40.0GB memory"
}
```

### Cluster Not Found
```bash
curl -X GET "http://localhost:8000/api/v1/clusters/999" \
  -H "Authorization: Bearer token"
```
**Response (404):**
```json
{
  "detail": "Cluster with id 999 not found"
}
```

### Duplicate Cluster Name
```bash
curl -X POST "http://localhost:8000/api/v1/clusters/" \
  -H "Authorization: Bearer token" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "existing-cluster",
    "instance_type": "container",
    "cpu_per_instance": 2.0,
    "memory_per_instance": 4.0,
    "instance_count": 2
  }'
```
**Response (400):**
```json
{
  "detail": "Cluster with name 'existing-cluster' already exists"
}
```

### Invalid Instance Operation
```bash
curl -X POST "http://localhost:8000/api/v1/instances/1/operate" \
  -H "Authorization: Bearer token" \
  -H "Content-Type: application/json" \
  -d '{"operation": "start"}'
```
**Response (400) - when instance is already running:**
```json
{
  "detail": "Cannot start instance in status 'running'"
}
```

---

## Testing with Scripts

### Bash Script Example

```bash
#!/bin/bash
set -e

TOKEN="your-token-here"
API_URL="http://localhost:8000/api/v1"

echo "Creating cluster..."
CLUSTER_RESPONSE=$(curl -s -X POST "$API_URL/clusters/" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "script-test",
    "instance_type": "container",
    "cpu_per_instance": 1.0,
    "memory_per_instance": 2.0,
    "instance_count": 2
  }')

CLUSTER_ID=$(echo $CLUSTER_RESPONSE | jq -r '.id')
echo "Created cluster with ID: $CLUSTER_ID"

echo "Waiting 5 seconds..."
sleep 5

echo "Suspending cluster..."
curl -s -X POST "$API_URL/clusters/$CLUSTER_ID/suspend" \
  -H "Authorization: Bearer $TOKEN" | jq

echo "Waiting 5 seconds..."
sleep 5

echo "Resuming cluster..."
curl -s -X POST "$API_URL/clusters/$CLUSTER_ID/resume" \
  -H "Authorization: Bearer $TOKEN" | jq

echo "Deleting cluster..."
curl -s -X DELETE "$API_URL/clusters/$CLUSTER_ID" \
  -H "Authorization: Bearer $TOKEN" | jq

echo "Done!"
```

### Python Script Example

```python
import requests
import time

TOKEN = "your-token-here"
API_URL = "http://localhost:8000/api/v1"
HEADERS = {
    "Authorization": f"Bearer {TOKEN}",
    "Content-Type": "application/json"
}

# Create cluster
response = requests.post(
    f"{API_URL}/clusters/",
    headers=HEADERS,
    json={
        "name": "python-test",
        "instance_type": "container",
        "cpu_per_instance": 1.0,
        "memory_per_instance": 2.0,
        "instance_count": 2
    }
)
cluster = response.json()
cluster_id = cluster["id"]
print(f"Created cluster: {cluster_id}")

# Suspend
time.sleep(5)
response = requests.post(
    f"{API_URL}/clusters/{cluster_id}/suspend",
    headers=HEADERS
)
print(f"Suspend result: {response.json()}")

# Resume
time.sleep(5)
response = requests.post(
    f"{API_URL}/clusters/{cluster_id}/resume",
    headers=HEADERS
)
print(f"Resume result: {response.json()}")

# Delete
response = requests.delete(
    f"{API_URL}/clusters/{cluster_id}",
    headers=HEADERS
)
print(f"Delete result: {response.json()}")
```

