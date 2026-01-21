from fastapi import FastAPI, Request
from fastapi.responses import JSONResponse
from fastapi.middleware.cors import CORSMiddleware
import logging
import sys
from app.database import init_db
from app.routers import clusters, instances, users

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.StreamHandler(sys.stdout)
    ]
)

logger = logging.getLogger(__name__)

# Create FastAPI app
app = FastAPI(
    title="Cloud Management Platform API",
    description="API for managing VM and container clusters with multi-tenancy and quota management",
    version="1.0.0",
    docs_url="/docs",
    redoc_url="/redoc"
)

# Configure CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # In production, specify allowed origins
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


# Exception handlers
@app.exception_handler(Exception)
async def general_exception_handler(request: Request, exc: Exception):
    logger.error(f"Unhandled exception: {exc}", exc_info=True)
    return JSONResponse(
        status_code=500,
        content={"message": "Internal server error", "detail": str(exc)}
    )


# Startup event
@app.on_event("startup")
async def startup_event():
    logger.info("Starting Cloud Management Platform API...")
    # Initialize database
    init_db()
    logger.info("Database initialized")


# Health check endpoint
@app.get("/", tags=["health"])
async def root():
    return {
        "status": "healthy",
        "service": "Cloud Management Platform API",
        "version": "1.0.0"
    }


@app.get("/health", tags=["health"])
async def health_check():
    return {
        "status": "healthy",
        "database": "connected"
    }


# Include routers
app.include_router(users.router, prefix="/api/v1")
app.include_router(clusters.router, prefix="/api/v1")
app.include_router(instances.router, prefix="/api/v1")


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(
        "main:app",
        host="0.0.0.0",
        port=8000,
        reload=True,
        log_level="info"
    )

