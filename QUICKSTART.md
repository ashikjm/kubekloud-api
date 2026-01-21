# Quick Start Guide

Get up and running with Cloud Management Platform API in minutes.

## Prerequisites

- Python 3.9+
- Kubernetes cluster with `kubectl` configured
- (Optional) KubeVirt for VM support

## 1. Install Dependencies

```bash
# Create virtual environment
python -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate

# Install dependencies
pip install -r requirements.txt
```

## 2. Configure Environment

```bash
# Copy example environment file
cp .env.example .env

# Edit .env if needed (defaults work for local development)
```

## 3. Initialize Database

```bash
# Run initialization script
python scripts/init_db.py

# When prompted, create an admin user (recommended for testing)
```

## 4. Start the API Server

```bash
python main.py
```

The API will be available at: http://localhost:8000

**API Documentation**: http://localhost:8000/docs

## 5. Test the API

### Option A: Use the Test Script

```bash
# Make script executable
chmod +x scripts/test_api.sh

# Run tests
./scripts/test_api.sh
```

### Option B: Manual Testing with curl

**Create a User:**

```bash
curl -X POST "http://localhost:8000/api/v1/users/" \
  -H "Content-Type: application/json" \
  -d '{
    "username": "john",
    "token": "my-secret-token",
    "quota_cpu": 16.0,
    "quota_memory": 64.0
  }'
```

**Create a Cluster:**

```bash
curl -X POST "http://localhost:8000/api/v1/clusters/" \
  -H "Authorization: Bearer my-secret-token" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "my-first-cluster",
    "instance_type": "container",
    "cpu_per_instance": 1.0,
    "memory_per_instance": 2.0,
    "instance_count": 3
  }'
```

**List Your Clusters:**

```bash
curl -X GET "http://localhost:8000/api/v1/clusters/" \
  -H "Authorization: Bearer my-secret-token"
```

**Check Your Quota:**

```bash
curl -X GET "http://localhost:8000/api/v1/users/me/quota" \
  -H "Authorization: Bearer my-secret-token"
```

### Option C: Use the Interactive API Docs

1. Open http://localhost:8000/docs
2. Click "Authorize" button
3. Enter your token (e.g., `my-secret-token`)
4. Try out the endpoints interactively

## Docker Deployment

### Quick Start with Docker Compose

```bash
# Build and start services
docker-compose up -d

# Check logs
docker-compose logs -f api

# Stop services
docker-compose down
```

### Build Docker Image Only

```bash
# Build image
docker build -t cmp-api .

# Run container
docker run -d -p 8000:8000 \
  -v $(pwd)/cmp.db:/app/cmp.db \
  -v ~/.kube/config:/home/appuser/.kube/config:ro \
  cmp-api
```

## Common Operations

### Create VM-based Cluster

```bash
curl -X POST "http://localhost:8000/api/v1/clusters/" \
  -H "Authorization: Bearer my-secret-token" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "vm-cluster",
    "instance_type": "vm",
    "cpu_per_instance": 2.0,
    "memory_per_instance": 4.0,
    "instance_count": 2
  }'
```

### Stop an Instance

```bash
# Get instance ID from cluster details first
curl -X GET "http://localhost:8000/api/v1/clusters/1" \
  -H "Authorization: Bearer my-secret-token"

# Then stop the instance
curl -X POST "http://localhost:8000/api/v1/instances/1/operate" \
  -H "Authorization: Bearer my-secret-token" \
  -H "Content-Type: application/json" \
  -d '{"operation": "stop"}'
```

### Suspend a Cluster

Suspend all instances in the cluster (useful for saving costs):

```bash
curl -X POST "http://localhost:8000/api/v1/clusters/1/suspend" \
  -H "Authorization: Bearer my-secret-token"
```

### Resume a Cluster

Resume all suspended instances:

```bash
curl -X POST "http://localhost:8000/api/v1/clusters/1/resume" \
  -H "Authorization: Bearer my-secret-token"
```

### Delete a Cluster

```bash
curl -X DELETE "http://localhost:8000/api/v1/clusters/1" \
  -H "Authorization: Bearer my-secret-token"
```

## Troubleshooting

### "Failed to load k8s config"

Make sure `kubectl` is configured:

```bash
kubectl cluster-info
```

If this fails, configure your kubeconfig or set `K8S_CONFIG_PATH` in `.env`.

### "Insufficient quota" Error

Check your current usage:

```bash
curl -X GET "http://localhost:8000/api/v1/users/me/quota" \
  -H "Authorization: Bearer my-secret-token"
```

Delete unused clusters or increase quota.

### Database Locked Error (SQLite)

SQLite doesn't handle concurrent writes well. For production, use PostgreSQL:

```env
DATABASE_URL=postgresql://user:password@localhost/cmp
```

### Kubernetes Resources Not Created

Check API server logs for errors. Common issues:
- Insufficient RBAC permissions
- Resource quota exceeded in namespace
- KubeVirt not installed (for VMs)

## Next Steps

- Read the [full documentation](README.md)
- Explore the API docs at `/docs`
- Set up monitoring and logging
- Configure PostgreSQL for production
- Implement role-based access control
- Add rate limiting

## Support

For issues and questions, refer to:
- API Documentation: http://localhost:8000/docs
- README: [README.md](README.md)
- GitHub Issues: [Create an issue]

Happy clustering! 🚀

