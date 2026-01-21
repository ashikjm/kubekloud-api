from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from typing import List
from app.database import get_db
from app.models import User, Cluster, Instance, InstanceStatus
from app.schemas import (
    ClusterCreate, ClusterResponse, ClusterDetail, MessageResponse
)
from app.auth import get_current_user, check_quota, update_quota
from app.k8s_service import k8s_service
import logging

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/clusters", tags=["clusters"])


@router.post("/", response_model=ClusterResponse, status_code=status.HTTP_201_CREATED)
async def create_cluster(
    cluster_data: ClusterCreate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Create a new cluster with specified instances
    """
    # Check if cluster name already exists
    existing_cluster = db.query(Cluster).filter(Cluster.name == cluster_data.name).first()
    if existing_cluster:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Cluster with name '{cluster_data.name}' already exists"
        )
    
    # Generate namespace name
    namespace = f"{cluster_data.name}-ns"
    
    # Calculate total resources needed
    total_cpu = cluster_data.cpu_per_instance * cluster_data.instance_count
    total_memory = cluster_data.memory_per_instance * cluster_data.instance_count
    
    # Check quota
    if not check_quota(current_user, total_cpu, total_memory):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail=f"Insufficient quota. Requested: {total_cpu} CPU, {total_memory}GB memory. "
                   f"Available: {current_user.quota_cpu - current_user.used_cpu} CPU, "
                   f"{current_user.quota_memory - current_user.used_memory}GB memory"
        )
    
    # Create namespace in Kubernetes
    if not k8s_service.create_namespace(namespace):
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to create Kubernetes namespace '{namespace}'"
        )
    
    # Create cluster in database
    cluster = Cluster(
        name=cluster_data.name,
        namespace=namespace,
        instance_type=cluster_data.instance_type,
        cpu_per_instance=cluster_data.cpu_per_instance,
        memory_per_instance=cluster_data.memory_per_instance,
        instance_count=cluster_data.instance_count,
        owner_id=current_user.id
    )
    db.add(cluster)
    db.commit()
    db.refresh(cluster)
    
    # Create instances
    created_instances = []
    for i in range(cluster_data.instance_count):
        instance_name = f"{cluster_data.name}-instance-{i}"
        
        # Create instance in database
        instance = Instance(
            cluster_id=cluster.id,
            instance_name=instance_name,
            status=InstanceStatus.PENDING,
            k8s_resource_name=instance_name
        )
        db.add(instance)
        db.commit()
        db.refresh(instance)
        
        # Create K8s resource
        success = k8s_service.create_instance(
            instance_name=instance_name,
            cpu=cluster_data.cpu_per_instance,
            memory=cluster_data.memory_per_instance,
            instance_type=cluster_data.instance_type,
            namespace=cluster.namespace
        )
        
        if success:
            instance.status = InstanceStatus.RUNNING
            created_instances.append(instance)
        else:
            instance.status = InstanceStatus.FAILED
            logger.error(f"Failed to create instance {instance_name}")
        
        db.commit()
    
    # Update user quota
    update_quota(db, current_user, total_cpu, total_memory)
    
    logger.info(f"Cluster '{cluster_data.name}' created with {len(created_instances)} instances")
    
    return cluster


@router.get("/", response_model=List[ClusterResponse])
async def list_clusters(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    List all clusters owned by the current user
    """
    clusters = db.query(Cluster).filter(Cluster.owner_id == current_user.id).all()
    return clusters


@router.get("/{cluster_id}", response_model=ClusterDetail)
async def get_cluster(
    cluster_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Get detailed information about a specific cluster
    """
    cluster = db.query(Cluster).filter(
        Cluster.id == cluster_id,
        Cluster.owner_id == current_user.id
    ).first()
    
    if not cluster:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Cluster with id {cluster_id} not found"
        )
    
    return cluster


@router.delete("/{cluster_id}", response_model=MessageResponse)
async def delete_cluster(
    cluster_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Delete a cluster and all its instances
    """
    cluster = db.query(Cluster).filter(
        Cluster.id == cluster_id,
        Cluster.owner_id == current_user.id
    ).first()
    
    if not cluster:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Cluster with id {cluster_id} not found"
        )
    
    # Delete all instances from K8s (optional, as namespace deletion will clean them up)
    instances = db.query(Instance).filter(Instance.cluster_id == cluster_id).all()
    for instance in instances:
        k8s_service.delete_instance(
            instance_name=instance.instance_name,
            instance_type=cluster.instance_type,
            namespace=cluster.namespace
        )
    
    # Delete the namespace (this will delete all resources in it)
    k8s_service.delete_namespace(cluster.namespace)
    
    # Calculate resources to release
    total_cpu = cluster.cpu_per_instance * cluster.instance_count
    total_memory = cluster.memory_per_instance * cluster.instance_count
    
    # Delete cluster (cascade will delete instances)
    db.delete(cluster)
    db.commit()
    
    # Update user quota (negative values to release resources)
    update_quota(db, current_user, -total_cpu, -total_memory)
    
    logger.info(f"Cluster '{cluster.name}' (id: {cluster_id}) and namespace '{cluster.namespace}' deleted")
    
    return MessageResponse(
        message=f"Cluster '{cluster.name}' deleted successfully",
        detail={
            "instances_deleted": len(instances),
            "namespace_deleted": cluster.namespace,
            "cpu_released": total_cpu,
            "memory_released": total_memory
        }
    )


@router.post("/{cluster_id}/suspend", response_model=MessageResponse)
async def suspend_cluster(
    cluster_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Suspend all instances in a cluster
    """
    cluster = db.query(Cluster).filter(
        Cluster.id == cluster_id,
        Cluster.owner_id == current_user.id
    ).first()
    
    if not cluster:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Cluster with id {cluster_id} not found"
        )
    
    # Get all instances in the cluster
    instances = db.query(Instance).filter(Instance.cluster_id == cluster_id).all()
    
    suspended_count = 0
    failed_count = 0
    skipped_count = 0
    
    for instance in instances:
        # Only suspend running instances
        if instance.status == InstanceStatus.RUNNING:
            success = k8s_service.stop_instance(
                instance_name=instance.instance_name,
                instance_type=cluster.instance_type,
                namespace=cluster.namespace
            )
            
            if success:
                instance.status = InstanceStatus.SUSPENDED
                suspended_count += 1
            else:
                failed_count += 1
                logger.error(f"Failed to suspend instance {instance.instance_name}")
        else:
            skipped_count += 1
            logger.info(f"Skipped instance {instance.instance_name} with status {instance.status.value}")
    
    db.commit()
    
    logger.info(f"Cluster '{cluster.name}' suspend operation completed: "
                f"{suspended_count} suspended, {failed_count} failed, {skipped_count} skipped")
    
    return MessageResponse(
        message=f"Cluster '{cluster.name}' suspend operation completed",
        detail={
            "cluster_id": cluster_id,
            "total_instances": len(instances),
            "suspended": suspended_count,
            "failed": failed_count,
            "skipped": skipped_count
        }
    )


@router.post("/{cluster_id}/resume", response_model=MessageResponse)
async def resume_cluster(
    cluster_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Resume all suspended instances in a cluster
    """
    cluster = db.query(Cluster).filter(
        Cluster.id == cluster_id,
        Cluster.owner_id == current_user.id
    ).first()
    
    if not cluster:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Cluster with id {cluster_id} not found"
        )
    
    # Get all instances in the cluster
    instances = db.query(Instance).filter(Instance.cluster_id == cluster_id).all()
    
    resumed_count = 0
    failed_count = 0
    skipped_count = 0
    
    for instance in instances:
        # Only resume suspended instances
        if instance.status == InstanceStatus.SUSPENDED:
            success = k8s_service.start_instance(
                instance_name=instance.instance_name,
                instance_type=cluster.instance_type,
                namespace=cluster.namespace
            )
            
            if success:
                instance.status = InstanceStatus.RUNNING
                resumed_count += 1
            else:
                failed_count += 1
                logger.error(f"Failed to resume instance {instance.instance_name}")
        else:
            skipped_count += 1
            logger.info(f"Skipped instance {instance.instance_name} with status {instance.status.value}")
    
    db.commit()
    
    logger.info(f"Cluster '{cluster.name}' resume operation completed: "
                f"{resumed_count} resumed, {failed_count} failed, {skipped_count} skipped")
    
    return MessageResponse(
        message=f"Cluster '{cluster.name}' resume operation completed",
        detail={
            "cluster_id": cluster_id,
            "total_instances": len(instances),
            "resumed": resumed_count,
            "failed": failed_count,
            "skipped": skipped_count
        }
    )

