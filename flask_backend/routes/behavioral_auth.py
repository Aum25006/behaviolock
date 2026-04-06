from flask import Blueprint, request, jsonify
from flask_jwt_extended import jwt_required, get_jwt_identity
import logging
from datetime import datetime
from services.behavioral_ml_service_mock import behavioral_auth_service

logger = logging.getLogger(__name__)

behavioral_auth_bp = Blueprint('behavioral_auth', __name__)

@behavioral_auth_bp.route('/calibrate', methods=['POST', 'OPTIONS'])
def calibrate_behavioral_model():
    """Mock behavioral calibration endpoint"""
    
    # Handle OPTIONS preflight request
    if request.method == 'OPTIONS':
        return jsonify({'status': 'ok'}), 200
    
    try:
        data = request.get_json()
        
        logger.info(f"Received behavioral calibration request")
        logger.info(f"Data keys: {list(data.keys()) if data else 'No data'}")
        
        # Mock successful calibration
        return jsonify({
            'status': 'success',
            'message': 'Behavioral model calibrated successfully',
            'metrics': {
                'accuracy': 0.95,
                'confidence': 0.87,
                'sessions_processed': 5,
                'keystrokes_analyzed': 150
            },
            'calibration_date': datetime.now().isoformat(),
            'profile_id': 'mock_profile_123'
        }), 200
        
    except Exception as e:
        logger.error(f"Error during behavioral calibration: {e}", exc_info=True)
        return jsonify({
            'status': 'error',
            'message': f'Calibration failed: {str(e)}'
        }), 500

@behavioral_auth_bp.route('/authenticate', methods=['POST', 'OPTIONS'])
def authenticate_behavior():
    """Mock behavioral authentication endpoint"""
    
    # Handle OPTIONS preflight request
    if request.method == 'OPTIONS':
        return jsonify({'status': 'ok'}), 200
    
    try:
        data = request.get_json()
        
        logger.info(f"Received behavioral authentication request")
        
        # Mock successful authentication
        return jsonify({
            'status': 'success',
            'authentication_result': {
                'authenticated': True,
                'confidence': 0.89,
                'risk_score': 0.11,
                'match_percentage': 89.5
            },
            'timestamp': datetime.now().isoformat()
        }), 200
        
    except Exception as e:
        logger.error(f"Error during behavioral authentication: {e}", exc_info=True)
        return jsonify({
            'status': 'error',
            'message': f'Authentication failed: {str(e)}'
        }), 500

@behavioral_auth_bp.route('/feedback', methods=['POST', 'OPTIONS'])
def provide_feedback():
    """Mock behavioral feedback endpoint"""
    
    # Handle OPTIONS preflight request
    if request.method == 'OPTIONS':
        return jsonify({'status': 'ok'}), 200
    
    try:
        data = request.get_json()
        
        logger.info(f"Received behavioral feedback")
        
        # Mock successful feedback processing
        return jsonify({
            'status': 'success',
            'message': 'Feedback processed successfully',
            'timestamp': datetime.now().isoformat()
        }), 200
        
    except Exception as e:
        logger.error(f"Error processing behavioral feedback: {e}", exc_info=True)
        return jsonify({
            'status': 'error',
            'message': f'Feedback processing failed: {str(e)}'
        }), 500

@behavioral_auth_bp.route('/profile', methods=['GET', 'OPTIONS'])
def get_behavioral_profile():
    """Mock behavioral profile endpoint"""
    
    # Handle OPTIONS preflight request
    if request.method == 'OPTIONS':
        return jsonify({'status': 'ok'}), 200
    
    try:
        logger.info(f"Retrieving behavioral profile")
        
        # Mock profile statistics
        return jsonify({
            'status': 'success',
            'profile': {
                'user_id': 'mock_user',
                'created_date': '2024-01-01T00:00:00Z',
                'last_updated': datetime.now().isoformat(),
                'calibration_sessions': 5,
                'total_keystrokes': 150,
                'accuracy': 0.95,
                'confidence_score': 0.87
            }
        }), 200
        
    except Exception as e:
        logger.error(f"Error retrieving behavioral profile: {e}", exc_info=True)
        return jsonify({
            'status': 'error',
            'message': f'Profile retrieval failed: {str(e)}'
        }), 500

@behavioral_auth_bp.route('/reset', methods=['POST', 'OPTIONS'])
def reset_behavioral_model():
    """Mock behavioral reset endpoint"""
    
    # Handle OPTIONS preflight request
    if request.method == 'OPTIONS':
        return jsonify({'status': 'ok'}), 200
    
    try:
        logger.info(f"Resetting behavioral model")
        
        # Mock successful reset
        return jsonify({
            'status': 'success',
            'message': 'Behavioral model reset successfully',
            'timestamp': datetime.now().isoformat()
        }), 200
        
    except Exception as e:
        logger.error(f"Error resetting behavioral model: {e}", exc_info=True)
        return jsonify({
            'status': 'error',
            'message': f'Model reset failed: {str(e)}'
        }), 500

@behavioral_auth_bp.route('/health', methods=['GET'])
def health_check():
    """Health check for behavioral authentication service"""
    return jsonify({
        'status': 'success',
        'service': 'behavioral_authentication',
        'timestamp': datetime.now().isoformat(),
        'active_models': len(behavioral_auth_service.models)
    })

# Error handlers
@behavioral_auth_bp.errorhandler(400)
def bad_request(error):
    return jsonify({
        'status': 'error',
        'message': 'Bad request',
        'timestamp': datetime.now().isoformat()
    }), 400

@behavioral_auth_bp.errorhandler(401)
def unauthorized(error):
    return jsonify({
        'status': 'error',
        'message': 'Unauthorized',
        'timestamp': datetime.now().isoformat()
    }), 401

@behavioral_auth_bp.errorhandler(500)
def internal_error(error):
    return jsonify({
        'status': 'error',
        'message': 'Internal server error',
        'timestamp': datetime.now().isoformat()
    }), 500
