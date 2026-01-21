from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from app.database import get_db
from app.models import User, Instance, Cluster, InstanceStatus
from app.schemas import InstanceOperation, InstanceResponse, MessageResponse
from app.auth import get_current_user
from app.k8s_service import k8s_service
import logging

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/instances", tags=["instances"])


@router.get("/{instance_id}", response_model=InstanceResponse)
async def get_instance(
    instance_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Get information about a specific instance
    """
    instance = db.query(Instance).join(Cluster).filter(
        Instance.id == instance_id,
        Cluster.owner_id == current_user.id
    ).first()
    
    if not instance:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Instance with id {instance_id} not found"
        )
    
    # Update status from K8s
    cluster = db.query(Cluster).filter(Cluster.id == instance.cluster_id).first()
    k8s_status = k8s_service.get_instance_status(
        instance_name=instance.instance_name,
        instance_type=cluster.instance_type,
        namespace=cluster.namespace
    )
    if k8s_status:
        instance.status = k8s_status
        db.commit()
        db.refresh(instance)
    
    return instance


@router.post("/{instance_id}/operate", response_model=MessageResponse)
async def operate_instance(
    instance_id: int,
    operation: InstanceOperation,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Perform an operation on an instance (start, stop, suspend, resume)
    """
    # Get instance and verify ownership
    instance = db.query(Instance).join(Cluster).filter(
        Instance.id == instance_id,
        Cluster.owner_id == current_user.id
    ).first()
    
    if not instance:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Instance with id {instance_id} not found"
        )
    
    cluster = db.query(Cluster).filter(Cluster.id == instance.cluster_id).first()
    
    # Perform operation
    success = False
    new_status = instance.status
    
    if operation.operation == "start":
        if instance.status == InstanceStatus.STOPPED:
            success = k8s_service.start_instance(
                instance_name=instance.instance_name,
                instance_type=cluster.instance_type,
                namespace=cluster.namespace
            )
            if success:
                new_status = InstanceStatus.RUNNING
        else:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"Cannot start instance in status '{instance.status.value}'"
            )
    
    elif operation.operation == "stop":
        if instance.status == InstanceStatus.RUNNING:
            success = k8s_service.stop_instance(
                instance_name=instance.instance_name,
                instance_type=cluster.instance_type,
                namespace=cluster.namespace
            )
            if success:
                new_status = InstanceStatus.STOPPED
        else:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"Cannot stop instance in status '{instance.status.value}'"
            )
    
    elif operation.operation == "suspend":
        if instance.status == InstanceStatus.RUNNING:
            # For suspend, we stop the instance but mark it as suspended
            success = k8s_service.stop_instance(
                instance_name=instance.instance_name,
                instance_type=cluster.instance_type,
                namespace=cluster.namespace
            )
            if success:
                new_status = InstanceStatus.SUSPENDED
        else:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"Cannot suspend instance in status '{instance.status.value}'"
            )
    
    elif operation.operation == "resume":
        if instance.status == InstanceStatus.SUSPENDED:
            success = k8s_service.start_instance(
                instance_name=instance.instance_name,
                instance_type=cluster.instance_type,
                namespace=cluster.namespace
            )
            if success:
                new_status = InstanceStatus.RUNNING
        else:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"Cannot resume instance in status '{instance.status.value}'"
            )
    
    if not success:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to {operation.operation} instance"
        )
    
    # Update instance status
    instance.status = new_status
    db.commit()
    
    logger.info(f"Instance {instance.instance_name} operation '{operation.operation}' completed")
    
    return MessageResponse(
        message=f"Instance operation '{operation.operation}' completed successfully",
        detail={
            "instance_id": instance_id,
            "instance_name": instance.instance_name,
            "previous_status": instance.status.value,
            "new_status": new_status.value
        }
    )

