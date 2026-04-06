from flask_jwt_extended import JWTManager
from flask_sqlalchemy import SQLAlchemy

# Initialize extensions
db = SQLAlchemy()
jwt = JWTManager()

def init_app(app):
    # Initialize Postgres (SQLAlchemy) + JWT
    db.init_app(app)
    jwt.init_app(app)
    return app
