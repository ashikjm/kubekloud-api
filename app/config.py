from pydantic_settings import BaseSettings
from typing import Optional


class Settings(BaseSettings):
    DATABASE_URL: str = "sqlite:///./cmp.db"
    K8S_NAMESPACE: str = "default"
    K8S_CONFIG_PATH: Optional[str] = None  # Path to kubeconfig, None uses default
    
    class Config:
        env_file = ".env"


settings = Settings()

