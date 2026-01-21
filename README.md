# KubeKCloud API 

A modular FastAPI service for managing VM and container clusters with multi-tenancy, quota management, and Kubernetes integration. 

## Features

- **Cluster Management**: Create, list, and delete clusters of VMs or containers
- **Instance Operations**: Start, stop, suspend, and resume individual instances
- **Multi-tenancy**: Token-based authentication with user isolation
- **Namespace Isolation**: Each cluster gets its own Kubernetes namespace (`<cluster-name>-ns`)
- **Quota Management**: CPU and memory quota tracking per user
- **Kubernetes Integration**: Automatic creation and management of K8s resources
- **Database Persistence**: SQLAlchemy-based data storage

## Architecture

```
cmp/
├── app/
│   ├── __init__.py
│   ├── models.py          # Database models
│   ├── schemas.py         # Pydantic schemas
│   ├── database.py        # Database configuration
│   ├── config.py          # Application settings
│   ├── auth.py            # Authentication & authorization
│   ├── k8s_service.py     # Kubernetes service layer
│   └── routers/
│       ├── __init__.py
│       ├── users.py       # User management endpoints
│       ├── clusters.py    # Cluster management endpoints
│       └── instances.py   # Instance management endpoints
├── main.py                # FastAPI application entry point
├── requirements.txt       # Python dependencies
└── README.md
```

## Installation

### Prerequisites

- Python 3.9+
- Kubernetes cluster (with kubectl configured)
- For VM management: KubeVirt installed on your cluster

### Setup

1. Clone the repository:
```bash
git clone <repository-url>
cd cmp
```

2. Create a virtual environment:
```bash
python -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate
```

3. Install dependencies:
```bash
pip install -r requirements.txt
```

4. Configure environment variables:
```bash
cp .env.example .env
# Edit .env with your configuration
```

5. Run the application:
```bash
python main.py
```

The API will be available at `http://localhost:8000`

## Configuration

### Environment Variables

Create a `.env` file in the root directory:

```env
# Database Configuration
DATABASE_URL=sqlite:///./cmp.db

# Kubernetes Configuration
K8S_NAMESPACE=default
K8S_CONFIG_PATH=
```

### Database Options

- **SQLite** (default): `sqlite:///./cmp.db`
- **PostgreSQL**: `postgresql://user:password@localhost/dbname`
- **MySQL**: `mysql+pymysql://user:password@localhost/dbname`

## API Documentation

Once the application is running, visit:
- **Swagger UI**: http://localhost:8000/docs
- **ReDoc**: http://localhost:8000/redoc

## Usage

### 1. Create a User

First, create a user with a static token and quota:

```bash
curl -X POST "http://localhost:8000/api/v1/users/" \
  -H "Content-Type: application/json" \
  -d '{
    "username": "john_doe",
    "token": "secret-token-123",
    "quota_cpu": 16.0,
    "quota_memory": 64.0
  }'
```

### 2. Create a Cluster

Create a cluster with multiple instances:

```bash
curl -X POST "http://localhost:8000/api/v1/clusters/" \
  -H "Authorization: Bearer secret-token-123" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "my-cluster",
    "instance_type": "container",
    "cpu_per_instance": 2.0,
    "memory_per_instance": 4.0,
    "instance_count": 3
  }'
```

### 3. List Clusters

```bash
curl -X GET "http://localhost:8000/api/v1/clusters/" \
  -H "Authorization: Bearer secret-token-123"
```

### 4. Get Cluster Details

```bash
curl -X GET "http://localhost:8000/api/v1/clusters/1" \
  -H "Authorization: Bearer secret-token-123"
```

### 5. Operate on an Instance

Start, stop, suspend, or resume an instance:

```bash
curl -X POST "http://localhost:8000/api/v1/instances/1/operate" \
  -H "Authorization: Bearer secret-token-123" \
  -H "Content-Type: application/json" \
  -d '{
    "operation": "stop"
  }'
```

Available operations: `start`, `stop`, `suspend`, `resume`

### 6. Check User Quota

```bash
curl -X GET "http://localhost:8000/api/v1/users/me/quota" \
  -H "Authorization: Bearer secret-token-123"
```

### 7. Suspend a Cluster

Suspend all running instances in the cluster:

```bash
curl -X POST "http://localhost:8000/api/v1/clusters/1/suspend" \
  -H "Authorization: Bearer secret-token-123"
```

### 8. Resume a Cluster

Resume all suspended instances in the cluster:

```bash
curl -X POST "http://localhost:8000/api/v1/clusters/1/resume" \
  -H "Authorization: Bearer secret-token-123"
```

### 9. Delete a Cluster

```bash
curl -X DELETE "http://localhost:8000/api/v1/clusters/1" \
  -H "Authorization: Bearer secret-token-123"
```

## API Endpoints

### Users

- `POST /api/v1/users/` - Create a new user
- `GET /api/v1/users/` - List all users
- `GET /api/v1/users/me` - Get current user info
- `GET /api/v1/users/me/quota` - Get current user quota

### Clusters

- `POST /api/v1/clusters/` - Create a new cluster
- `GET /api/v1/clusters/` - List all clusters (user-scoped)
- `GET /api/v1/clusters/{cluster_id}` - Get cluster details
- `DELETE /api/v1/clusters/{cluster_id}` - Delete a cluster
- `POST /api/v1/clusters/{cluster_id}/suspend` - Suspend all instances in a cluster
- `POST /api/v1/clusters/{cluster_id}/resume` - Resume all suspended instances in a cluster

### Instances

- `GET /api/v1/instances/{instance_id}` - Get instance info
- `POST /api/v1/instances/{instance_id}/operate` - Perform operation on instance

## Data Models

### User
- `username`: Unique username
- `token`: Static authentication token
- `quota_cpu`: Total CPU cores allowed
- `quota_memory`: Total memory in GB allowed
- `used_cpu`: Currently used CPU cores
- `used_memory`: Currently used memory in GB

### Cluster
- `name`: Unique cluster name
- `namespace`: Kubernetes namespace for this cluster (auto-generated as `<name>-ns`)
- `instance_type`: Either "vm" or "container"
- `cpu_per_instance`: CPU cores per instance
- `memory_per_instance`: Memory in GB per instance
- `instance_count`: Number of instances in the cluster

### Instance
- `instance_name`: Unique instance name
- `status`: Current status (running, stopped, suspended, pending, failed)
- `cluster_id`: Parent cluster ID
- `k8s_resource_name`: Name of the Kubernetes resource

## Kubernetes Integration

### Namespace Isolation

Each cluster is deployed in its own dedicated Kubernetes namespace following the naming convention:
- Cluster name: `my-cluster`
- Namespace: `my-cluster-ns`

This provides:
- **Resource isolation** between clusters
- **Easy cleanup** - deleting a cluster deletes its namespace and all resources
- **Clear organization** - each cluster's resources are grouped together
- **RBAC capabilities** - fine-grained access control per cluster

### Container Instances

Container instances are deployed as Kubernetes Pods with resource limits:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: <instance-name>
  namespace: <cluster-name>-ns
spec:
  containers:
  - name: main
    image: nginx:latest
    resources:
      requests:
        cpu: <cpu>
        memory: <memory>Mi
      limits:
        cpu: <cpu>
        memory: <memory>Mi
```

### VM Instances

VM instances use KubeVirt VirtualMachine resources:

```yaml
apiVersion: kubevirt.io/v1
kind: VirtualMachine
metadata:
  name: <instance-name>
  namespace: <cluster-name>-ns
spec:
  running: true
  template:
    spec:
      domain:
        cpu:
          cores: <cpu>
        resources:
          requests:
            memory: <memory>Gi
```

## Multi-tenancy & Security

### Authentication

The API uses Bearer token authentication. Each request must include:

```
Authorization: Bearer <user-token>
```

### Resource Isolation

- Users can only view and manage their own clusters and instances
- All API operations are scoped to the authenticated user
- Database queries automatically filter by user ownership

### Quota Management

- Each user has a fixed CPU and memory quota
- Quotas are checked before creating new clusters
- Resources are automatically released when clusters are deleted
- Quota usage is tracked in real-time

## Development

### Running in Development Mode

```bash
python main.py
```

The server will start with auto-reload enabled.

### Database Migrations

The application automatically creates tables on startup. For production, consider using Alembic for migrations.

### Testing with curl

A complete test workflow:

```bash
# 1. Create user
curl -X POST http://localhost:8000/api/v1/users/ \
  -H "Content-Type: application/json" \
  -d '{"username":"test","token":"test123","quota_cpu":10,"quota_memory":20}'

# 2. Create cluster
curl -X POST http://localhost:8000/api/v1/clusters/ \
  -H "Authorization: Bearer test123" \
  -H "Content-Type: application/json" \
  -d '{"name":"test-cluster","instance_type":"container","cpu_per_instance":1,"memory_per_instance":2,"instance_count":2}'

# 3. List clusters
curl -X GET http://localhost:8000/api/v1/clusters/ \
  -H "Authorization: Bearer test123"

# 4. Check quota
curl -X GET http://localhost:8000/api/v1/users/me/quota \
  -H "Authorization: Bearer test123"
```

## Production Considerations

1. **Database**: Use PostgreSQL or MySQL instead of SQLite
2. **Authentication**: Implement admin-only endpoints for user management
3. **CORS**: Configure specific allowed origins
4. **Logging**: Set up centralized logging (e.g., ELK stack)
5. **Monitoring**: Add Prometheus metrics
6. **Rate Limiting**: Implement API rate limiting
7. **Secrets Management**: Use proper secrets management (e.g., Vault)
8. **HTTPS**: Deploy behind a reverse proxy with TLS

## Troubleshooting

### Database Connection Issues

- Check `DATABASE_URL` in `.env`
- Ensure database server is running (for PostgreSQL/MySQL)
- Verify database permissions

### Kubernetes Connection Issues

- Verify `kubectl` is configured correctly
- Check `K8S_CONFIG_PATH` in `.env`
- Ensure proper RBAC permissions for the service account

### Quota Exceeded Errors

- Check current usage: `GET /api/v1/users/me/quota`
- Delete unused clusters to free resources
- Contact admin to increase quota

## License

[Your License Here]

## Contributing

[Your Contributing Guidelines Here]

