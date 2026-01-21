from sqlalchemy import Column, Integer, String, Float, ForeignKey, DateTime, Enum as SQLEnum
from sqlalchemy.orm import relationship
from sqlalchemy.ext.declarative import declarative_base
from datetime import datetime
import enum

Base = declarative_base()


class InstanceType(enum.Enum):
    VM = "vm"
    CONTAINER = "container"


class InstanceStatus(enum.Enum):
    RUNNING = "running"
    STOPPED = "stopped"
    SUSPENDED = "suspended"
    PENDING = "pending"
    FAILED = "failed"


class User(Base):
    __tablename__ = "users"
    
    id = Column(Integer, primary_key=True, index=True)
    username = Column(String, unique=True, index=True, nullable=False)
    token = Column(String, unique=True, index=True, nullable=False)
    quota_cpu = Column(Float, nullable=False)  # Total CPU cores allowed
    quota_memory = Column(Float, nullable=False)  # Total memory in GB allowed
    used_cpu = Column(Float, default=0.0)
    used_memory = Column(Float, default=0.0)
    created_at = Column(DateTime, default=datetime.utcnow)
    
    clusters = relationship("Cluster", back_populates="owner", cascade="all, delete-orphan")


class Cluster(Base):
    __tablename__ = "clusters"
    
    id = Column(Integer, primary_key=True, index=True)
    name = Column(String, unique=True, index=True, nullable=False)
    namespace = Column(String, unique=True, index=True, nullable=False)  # K8s namespace for this cluster
    instance_type = Column(SQLEnum(InstanceType), nullable=False)
    cpu_per_instance = Column(Float, nullable=False)
    memory_per_instance = Column(Float, nullable=False)  # in GB
    instance_count = Column(Integer, nullable=False)
    owner_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    created_at = Column(DateTime, default=datetime.utcnow)
    
    owner = relationship("User", back_populates="clusters")
    instances = relationship("Instance", back_populates="cluster", cascade="all, delete-orphan")


class Instance(Base):
    __tablename__ = "instances"
    
    id = Column(Integer, primary_key=True, index=True)
    cluster_id = Column(Integer, ForeignKey("clusters.id"), nullable=False)
    instance_name = Column(String, unique=True, index=True, nullable=False)
    status = Column(SQLEnum(InstanceStatus), default=InstanceStatus.PENDING)
    k8s_resource_name = Column(String)  # Name of the k8s resource (pod/vm)
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    
    cluster = relationship("Cluster", back_populates="instances")

