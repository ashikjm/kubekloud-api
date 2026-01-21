#!/usr/bin/env python3
"""
Database initialization script
Creates tables and optionally adds a default admin user
"""
import sys
from pathlib import Path

# Add parent directory to path
sys.path.append(str(Path(__file__).parent.parent))

from app.database import init_db, SessionLocal
from app.models import User


def create_admin_user():
    """Create a default admin user"""
    db = SessionLocal()
    try:
        # Check if admin user already exists
        admin = db.query(User).filter(User.username == "admin").first()
        if admin:
            print("Admin user already exists")
            return
        
        # Create admin user
        admin_user = User(
            username="admin",
            token="admin-token-change-me",
            quota_cpu=100.0,
            quota_memory=500.0,
            used_cpu=0.0,
            used_memory=0.0
        )
        db.add(admin_user)
        db.commit()
        print("✓ Admin user created successfully")
        print("  Username: admin")
        print("  Token: admin-token-change-me")
        print("  Quota: 100 CPU cores, 500 GB memory")
        print("\n⚠️  WARNING: Change the admin token in production!")
    except Exception as e:
        print(f"Error creating admin user: {e}")
        db.rollback()
    finally:
        db.close()


def main():
    print("Initializing database...")
    
    # Create tables
    init_db()
    print("✓ Database tables created")
    
    # Create admin user
    response = input("\nCreate default admin user? (y/n): ")
    if response.lower() == 'y':
        create_admin_user()
    
    print("\n✓ Database initialization complete!")


if __name__ == "__main__":
    main()

