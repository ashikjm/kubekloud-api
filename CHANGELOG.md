# Changelog

All notable changes to this project will be documented in this file.

## [Unreleased]

### Added
- Namespace isolation for clusters - each cluster now gets its own Kubernetes namespace
- Namespace naming convention: `<cluster-name>-ns`
- Automatic namespace creation during cluster creation
- Automatic namespace deletion during cluster deletion
- Enhanced resource isolation between clusters
- **Cluster-level suspend operation** - suspend all instances in a cluster with one API call
- **Cluster-level resume operation** - resume all suspended instances in a cluster with one API call

### Changed
- Updated Cluster model to include `namespace` field
- Modified all Kubernetes operations to use cluster-specific namespaces
- Updated API responses to include namespace information

### Benefits
- Better resource isolation between clusters
- Simplified cleanup - deleting a cluster automatically deletes its namespace and all resources
- Improved organization - cluster resources are logically grouped
- Foundation for future RBAC and network policy implementation per cluster

## [1.0.0] - 2025-01-09

### Added
- Initial release
- Cluster management (create, list, get, delete)
- Instance operations (start, stop, suspend, resume)
- Multi-tenancy with token-based authentication
- Quota management (CPU and memory tracking)
- Kubernetes integration (Pods for containers, VirtualMachines for VMs)
- Database persistence with SQLAlchemy
- RESTful API with FastAPI
- OpenAPI/Swagger documentation
- Docker and Docker Compose support
- Comprehensive documentation (README, QUICKSTART, ARCHITECTURE)

