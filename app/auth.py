from fastapi import Depends, HTTPException, status, Security
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from sqlalchemy.orm import Session
from app.database import get_db
from app.models import User

security = HTTPBearer()


async def get_current_user(
    credentials: HTTPAuthorizationCredentials = Security(security),
    db: Session = Depends(get_db)
) -> User:
    """
    Authenticate user based on bearer token
    """
    token = credentials.credentials
    
    user = db.query(User).filter(User.token == token).first()
    
    if not user:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid authentication token",
            headers={"WWW-Authenticate": "Bearer"},
        )
    
    return user


def check_quota(user: User, cpu_needed: float, memory_needed: float) -> bool:
    """
    Check if user has enough quota for the requested resources
    """
    available_cpu = user.quota_cpu - user.used_cpu
    available_memory = user.quota_memory - user.used_memory
    
    return cpu_needed <= available_cpu and memory_needed <= available_memory


def update_quota(db: Session, user: User, cpu_delta: float, memory_delta: float):
    """
    Update user's resource usage
    cpu_delta and memory_delta can be positive (allocation) or negative (deallocation)
    """
    user.used_cpu += cpu_delta
    user.used_memory += memory_delta
    db.commit()
    db.refresh(user)

