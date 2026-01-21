# Architecture Overview

## System Design

The Cloud Management Platform (CMP) is designed as a modular, scalable API service for managing VM and container clusters with multi-tenancy support.

## Components

### 1. API Layer (`main.py`)

- FastAPI application with automatic OpenAPI documentation
- CORS middleware for cross-origin requests
- Exception handling and logging
- Health check endpoints

### 2. Authentication (`app/auth.py`)

- Token-based authentication using Bearer tokens
- User validation middleware
- Quota checking and enforcement
- Resource usage tracking

### 3. Database Layer (`app/database.py`, `app/models.py`)

**Models:**
- `User`: User accounts with tokens and quotas
- `Cluster`: Cluster definitions with resource specifications
- `Instance`: Individual instances within clusters

**Features:**
- SQLAlchemy ORM for database abstraction
- Support for SQLite, PostgreSQL, MySQL
- Automatic table creation
- Relationship management with cascading deletes

### 4. API Schemas (`app/schemas.py`)

Pydantic models for:
- Request validation
- Response serialization
- Type safety
- Automatic documentation generation

### 5. Kubernetes Integration (`app/k8s_service.py`)

**Capabilities:**
- Dynamic manifest generation
- Pod creation and management (containers)
- VirtualMachine creation and management (VMs via KubeVirt)
- Instance lifecycle operations (start, stop, suspend, resume)
- Status synchronization

**Resource Types:**
- **Containers**: Kubernetes Pods with resource limits
- **VMs**: KubeVirt VirtualMachines

### 6. API Routers

#### Users Router (`app/routers/users.py`)
- `POST /api/v1/users/` - Create user
- `GET /api/v1/users/me` - Get current user info
- `GET /api/v1/users/me/quota` - Get quota information
- `GET /api/v1/users/` - List all users

#### Clusters Router (`app/routers/clusters.py`)
- `POST /api/v1/clusters/` - Create cluster
- `GET /api/v1/clusters/` - List user's clusters
- `GET /api/v1/clusters/{id}` - Get cluster details
- `DELETE /api/v1/clusters/{id}` - Delete cluster

#### Instances Router (`app/routers/instances.py`)
- `GET /api/v1/instances/{id}` - Get instance info
- `POST /api/v1/instances/{id}/operate` - Perform operation

## Data Flow

### Creating a Cluster

```
User Request
    ↓
Authentication (verify token)
    ↓
Quota Check (verify available resources)
    ↓
Generate Namespace Name (<cluster-name>-ns)
    ↓
Create K8s Namespace
    ↓
Create Cluster Record (database)
    ↓
For each instance:
    ├─ Create Instance Record (database)
    ├─ Generate K8s Manifest
    └─ Create K8s Resource (in cluster namespace)
    ↓
Update User Quota (increase usage)
    ↓
Return Cluster Details
```

### Deleting a Cluster

```
User Request
    ↓
Authentication (verify token)
    ↓
Verify Ownership
    ↓
For each instance:
    └─ Delete K8s Resource
    ↓
Delete K8s Namespace (cascades to all resources)
    ↓
Delete Cluster & Instances (database)
    ↓
Update User Quota (decrease usage)
    ↓
Return Success Message
```

### Instance Operations

```
User Request (start/stop/suspend/resume)
    ↓
Authentication (verify token)
    ↓
Verify Ownership
    ↓
Validate Operation (check current status)
    ↓
Execute K8s Operation
    ↓
Update Instance Status (database)
    ↓
Return Operation Result
```

## Multi-tenancy Design

### User Isolation

1. **Authentication**: Every request requires a valid Bearer token
2. **Authorization**: Database queries automatically filter by user ownership
3. **Resource Isolation**: Users can only access their own clusters and instances
4. **Namespace Isolation**: Each cluster runs in its own Kubernetes namespace (`<cluster-name>-ns`)

### Quota Management

Each user has:
- **Total Quota**: Maximum CPU cores and memory allowed
- **Used Resources**: Currently allocated resources
- **Available Quota**: `total - used`

Quota is:
- **Checked** before creating clusters
- **Updated** when clusters are created (increase usage)
- **Released** when clusters are deleted (decrease usage)

## Database Schema

```
┌─────────────────┐
│     Users       │
├─────────────────┤
│ id (PK)         │
│ username        │
│ token           │
│ quota_cpu       │
│ quota_memory    │
│ used_cpu        │
│ used_memory     │
│ created_at      │
└────────┬────────┘
         │
         │ 1:N
         │
┌────────▼────────┐
│    Clusters     │
├─────────────────┤
│ id (PK)         │
│ name            │
│ namespace       │
│ instance_type   │
│ cpu_per_inst    │
│ memory_per_inst │
│ instance_count  │
│ owner_id (FK)   │
│ created_at      │
└────────┬────────┘
         │
         │ 1:N
         │
┌────────▼────────┐
│   Instances     │
├─────────────────┤
│ id (PK)         │
│ cluster_id (FK) │
│ instance_name   │
│ status          │
│ k8s_resource    │
│ created_at      │
│ updated_at      │
└─────────────────┘
```

## Kubernetes Resources

### Container Instances (Pods)

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: <cluster-name>-instance-<n>
  labels:
    managed-by: cmp
    instance-type: container
spec:
  containers:
  - name: main
    image: nginx:latest
    resources:
      requests/limits:
        cpu: <cpu>
        memory: <memory>Mi
```

### VM Instances (KubeVirt)

```yaml
apiVersion: kubevirt.io/v1
kind: VirtualMachine
metadata:
  name: <cluster-name>-instance-<n>
  labels:
    managed-by: cmp
    instance-type: vm
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

## Security Considerations

### Current Implementation

- Static token authentication
- User-scoped resource access
- Quota enforcement
- Database-level user isolation

### Production Recommendations

1. **Authentication**
   - Use OAuth2/JWT tokens with expiration
   - Implement token refresh mechanism
   - Add role-based access control (RBAC)

2. **Authorization**
   - Admin vs. user roles
   - Fine-grained permissions
   - Resource-level access control

3. **Network Security**
   - Enable HTTPS/TLS
   - Configure CORS properly
   - Use API gateway with rate limiting

4. **Database Security**
   - Use connection pooling
   - Enable SSL for database connections
   - Regular backups
   - Encrypt sensitive data

5. **Kubernetes Security**
   - Use service accounts with minimal RBAC
   - Enable Pod Security Policies
   - Network policies for isolation
   - Resource quotas per user namespace

## Scalability

### Current Architecture

- Single API server
- Single database
- Direct Kubernetes API calls

### Scaling Strategies

1. **Horizontal Scaling**
   - Deploy multiple API server replicas
   - Use load balancer (e.g., Nginx, HAProxy)
   - Implement session stickiness if needed

2. **Database Scaling**
   - Use PostgreSQL with replication
   - Implement connection pooling
   - Consider read replicas for queries

3. **Kubernetes Operations**
   - Use Kubernetes client connection pooling
   - Implement async operations for long-running tasks
   - Add job queue (e.g., Celery) for background tasks

4. **Caching**
   - Cache user quota information
   - Cache cluster listings
   - Use Redis for distributed caching

## Monitoring and Observability

### Recommended Additions

1. **Metrics**
   - Prometheus metrics for API endpoints
   - Resource usage tracking
   - Kubernetes resource status

2. **Logging**
   - Structured JSON logging
   - Centralized log aggregation (ELK, Loki)
   - Request/response logging

3. **Tracing**
   - Distributed tracing (Jaeger, Zipkin)
   - Request correlation IDs
   - Performance profiling

4. **Alerting**
   - Quota threshold alerts
   - Failed resource creation alerts
   - API error rate monitoring

## Extension Points

### Adding New Instance Types

1. Add enum value in `app/models.py`
2. Implement manifest template in `app/k8s_service.py`
3. Add lifecycle operations for new type

### Custom Resource Specifications

1. Extend `ClusterCreate` schema in `app/schemas.py`
2. Update database model in `app/models.py`
3. Modify manifest generation in `app/k8s_service.py`

### Advanced Quota Models

1. Add quota types in `app/models.py`
2. Implement quota strategies in `app/auth.py`
3. Add quota policy endpoints in `app/routers/users.py`

## Performance Considerations

- **Database queries**: Indexed columns for fast lookups
- **Kubernetes operations**: Async/await patterns can be added
- **Bulk operations**: Batch create/delete operations
- **Pagination**: Add pagination for list endpoints (large datasets)

## Testing Strategy

1. **Unit Tests**: Test individual functions and methods
2. **Integration Tests**: Test API endpoints end-to-end
3. **Load Tests**: Test system under concurrent requests
4. **Kubernetes Tests**: Mock or use test clusters

## Deployment Options

1. **Standalone**: Direct Python execution
2. **Docker**: Containerized deployment
3. **Docker Compose**: Multi-container setup with database
4. **Kubernetes**: Deploy API as K8s service
5. **Cloud Platforms**: AWS ECS, Google Cloud Run, Azure Container Instances

