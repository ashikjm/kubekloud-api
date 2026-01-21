from pydantic import BaseModel, Field
from typing import List, Optional
from datetime import datetime
from app.models import InstanceType, InstanceStatus


# User Schemas
class UserBase(BaseModel):
    username: str
    quota_cpu: float = Field(gt=0, description="CPU quota in cores")
    quota_memory: float = Field(gt=0, description="Memory quota in GB")


class UserCreate(UserBase):
    token: str


class UserResponse(UserBase):
    id: int
    used_cpu: float
    used_memory: float
    created_at: datetime
    
    class Config:
        from_attributes = True


# Cluster Schemas
class ClusterCreate(BaseModel):
    name: str = Field(..., min_length=1, max_length=100)
    instance_type: InstanceType
    cpu_per_instance: float = Field(gt=0, description="CPU cores per instance")
    memory_per_instance: float = Field(gt=0, description="Memory in GB per instance")
    instance_count: int = Field(gt=0, description="Number of instances")


class ClusterResponse(BaseModel):
    id: int
    name: str
    namespace: str
    instance_type: InstanceType
    cpu_per_instance: float
    memory_per_instance: float
    instance_count: int
    owner_id: int
    created_at: datetime
    
    class Config:
        from_attributes = True


class ClusterDetail(ClusterResponse):
    instances: List["InstanceResponse"] = []


# Instance Schemas
class InstanceResponse(BaseModel):
    id: int
    cluster_id: int
    instance_name: str
    status: InstanceStatus
    k8s_resource_name: Optional[str]
    created_at: datetime
    updated_at: datetime
    
    class Config:
        from_attributes = True


class InstanceOperation(BaseModel):
    operation: str = Field(..., pattern="^(start|stop|suspend|resume)$")


# Response Schemas
class MessageResponse(BaseModel):
    message: str
    detail: Optional[dict] = None


class QuotaResponse(BaseModel):
    total_cpu: float
    total_memory: float
    used_cpu: float
    used_memory: float
    available_cpu: float
    available_memory: float

