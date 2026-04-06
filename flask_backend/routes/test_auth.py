from flask import Blueprint, request, jsonify
from flask_jwt_extended import create_access_token
from datetime import datetime, timedelta
import logging

logger = logging.getLogger(__name__)

# Create test auth blueprint
test_auth_bp = Blueprint('test_auth', __name__)

@test_auth_bp.route('/login', methods=['POST', 'OPTIONS'])
def test_login():
    """Simplified login for testing without MongoDB"""
    
    # Handle preflight CORS request
    if request.method == 'OPTIONS':
        return jsonify({'status': 'ok'}), 200
    
    try:
        data = request.get_json()
        logger.info(f"Test login attempt: {data}")
        
        if not data:
            return jsonify({
                'status': 'error',
                'message': 'No JSON data provided'
            }), 400
        
        email = data.get('email', '').strip().lower()
        password = data.get('password', '')
        
        if not email or not password:
            return jsonify({
                'status': 'error',
                'message': 'Email and password are required'
            }), 400
        
        # Mock authentication - accept any email/password for testing
        logger.info(f"Mock authentication for: {email}")
        
        # Create access token
        access_token = create_access_token(
            identity=email,
            expires_delta=timedelta(hours=24)
        )
        
        # Mock user data
        user_data = {
            'id': 'test_user_123',
            'name': 'Test User',
            'email': email,
            'created_at': datetime.utcnow().isoformat(),
            'last_login': datetime.utcnow().isoformat()
        }
        
        logger.info("Test login successful")
        
        return jsonify({
            'status': 'success',
            'message': 'Login successful',
            'access_token': access_token,
            'user': user_data,
            'expires_in': 86400  # 24 hours in seconds
        }), 200
        
    except Exception as e:
        logger.error(f"Test login error: {str(e)}", exc_info=True)
        return jsonify({
            'status': 'error',
            'message': f'Login failed: {str(e)}'
        }), 500

@test_auth_bp.route('/register', methods=['POST', 'OPTIONS'])
def test_register():
    """Simplified register for testing without MongoDB"""
    
    # Handle preflight CORS request
    if request.method == 'OPTIONS':
        return jsonify({'status': 'ok'}), 200
    
    try:
        data = request.get_json()
        logger.info(f"Test register attempt: {data}")
        
        if not data:
            return jsonify({
                'status': 'error',
                'message': 'No JSON data provided'
            }), 400
        
        # Handle both name formats (Flutter sends first_name/last_name)
        first_name = data.get('first_name', '').strip()
        last_name = data.get('last_name', '').strip()
        name = data.get('name', '').strip()
        
        # Use first_name + last_name if available, otherwise use name
        if first_name:
            full_name = f"{first_name} {last_name}".strip()
        else:
            full_name = name
        
        email = data.get('email', '').strip().lower()
        password = data.get('password', '')
        phone = data.get('phone', '').strip()
        
        logger.info(f"Parsed data - first_name: '{first_name}', last_name: '{last_name}', full_name: '{full_name}', email: '{email}', phone: '{phone}'")
        
        if not full_name:
            logger.error("Name is missing or empty")
            return jsonify({
                'status': 'error',
                'message': 'Name is required'
            }), 400
            
        if not email:
            logger.error("Email is missing or empty")
            return jsonify({
                'status': 'error',
                'message': 'Email is required'
            }), 400
            
        if not password:
            logger.error("Password is missing or empty")
            return jsonify({
                'status': 'error',
                'message': 'Password is required'
            }), 400
        
        # Mock registration - always successful for testing
        logger.info(f"Mock registration for: {email}")
        
        # Create access token
        access_token = create_access_token(
            identity=email,
            expires_delta=timedelta(hours=24)
        )
        
        # Mock user data
        user_data = {
            'id': 'test_user_123',
            'name': full_name,
            'email': email,
            'phone': phone,
            'created_at': datetime.utcnow().isoformat(),
            'last_login': datetime.utcnow().isoformat()
        }
        
        logger.info("Test registration successful")
        
        return jsonify({
            'status': 'success',
            'message': 'Registration successful',
            'access_token': access_token,
            'user': user_data,
            'expires_in': 86400  # 24 hours in seconds
        }), 201
        
    except Exception as e:
        logger.error(f"Test register error: {str(e)}", exc_info=True)
        return jsonify({
            'status': 'error',
            'message': f'Registration failed: {str(e)}'
        }), 500

@test_auth_bp.route('/signup', methods=['POST', 'OPTIONS'])
def test_signup():
    """Alias for register - matches Flutter app expectations"""
    print(f"=== SIGNUP ROUTE HIT === Method: {request.method}")
    logger.info(f"=== SIGNUP ROUTE HIT === Method: {request.method}")
    return test_register()
