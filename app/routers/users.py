from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from typing import List
from app.database import get_db
from app.models import User
from app.schemas import UserCreate, UserResponse, QuotaResponse
from app.auth import get_current_user

router = APIRouter(prefix="/users", tags=["users"])


@router.post("/", response_model=UserResponse, status_code=status.HTTP_201_CREATED)
async def create_user(
    user_data: UserCreate,
    db: Session = Depends(get_db)
):
    """
    Create a new user (admin operation - in production, add admin auth)
    """
    # Check if username already exists
    existing_user = db.query(User).filter(User.username == user_data.username).first()
    if existing_user:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"User with username '{user_data.username}' already exists"
        )
    
    # Check if token already exists
    existing_token = db.query(User).filter(User.token == user_data.token).first()
    if existing_token:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Token already in use"
        )
    
    # Create user
    user = User(
        username=user_data.username,
        token=user_data.token,
        quota_cpu=user_data.quota_cpu,
        quota_memory=user_data.quota_memory,
        used_cpu=0.0,
        used_memory=0.0
    )
    db.add(user)
    db.commit()
    db.refresh(user)
    
    return user


@router.get("/me", response_model=UserResponse)
async def get_current_user_info(
    current_user: User = Depends(get_current_user)
):
    """
    Get information about the currently authenticated user
    """
    return current_user


@router.get("/me/quota", response_model=QuotaResponse)
async def get_user_quota(
    current_user: User = Depends(get_current_user)
):
    """
    Get quota information for the current user
    """
    return QuotaResponse(
        total_cpu=current_user.quota_cpu,
        total_memory=current_user.quota_memory,
        used_cpu=current_user.used_cpu,
        used_memory=current_user.used_memory,
        available_cpu=current_user.quota_cpu - current_user.used_cpu,
        available_memory=current_user.quota_memory - current_user.used_memory
    )


@router.get("/", response_model=List[UserResponse])
async def list_users(
    db: Session = Depends(get_db)
):
    """
    List all users (admin operation - in production, add admin auth)
    """
    users = db.query(User).all()
    return users

