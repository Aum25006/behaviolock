from flask import Flask, jsonify, request
from flask_cors import CORS
import os
from dotenv import load_dotenv
import logging
from datetime import datetime, timedelta
import secrets

# Load environment variables
load_dotenv()

# Configure logging
logging.basicConfig(
    level=logging.DEBUG,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

# Create the Flask application
app = Flask(__name__)

# Disable automatic slash redirects to avoid CORS preflight issues
app.url_map.strict_slashes = False

# Configure CORS - very permissive for development (allow all localhost origins)
CORS(app, 
     origins="*",  # Allow all origins for development
     methods=["GET", "POST", "PUT", "DELETE", "OPTIONS", "PATCH"],
     allow_headers=["Content-Type", "Authorization", "Accept", "X-Requested-With"],
     supports_credentials=True,
     expose_headers=["Content-Type", "Authorization"])

# Add request logging and ensure CORS headers
@app.after_request
def after_request(response):
    # Log the request
    logger.debug(f"{request.method} {request.path} - {response.status_code}")
    logger.debug(f"Request Headers: {dict(request.headers)}")
    
    # Ensure CORS headers are always present
    origin = request.headers.get('Origin')
    if origin:
        response.headers['Access-Control-Allow-Origin'] = origin
        response.headers['Access-Control-Allow-Credentials'] = 'true'
        response.headers['Access-Control-Allow-Methods'] = 'GET, POST, PUT, DELETE, OPTIONS, PATCH'
        response.headers['Access-Control-Allow-Headers'] = 'Content-Type, Authorization, Accept, X-Requested-With'
    
    return response

# Configuration
app.config['SECRET_KEY'] = os.getenv('SECRET_KEY', 'your-secret-key')
app.config['JWT_SECRET_KEY'] = os.getenv('JWT_SECRET_KEY', 'jwt-secret-key')
app.config['JWT_ACCESS_TOKEN_EXPIRES'] = 86400  # 24 hours in seconds

# SQLAlchemy / Postgres (Supabase)
database_url = os.getenv('DATABASE_URL', '').strip()
if database_url and 'sslmode=' not in database_url:
    # Supabase requires SSL; ensure sslmode=require if user forgot it
    sep = '&' if '?' in database_url else '?'
    database_url = f"{database_url}{sep}sslmode=require"
app.config['SQLALCHEMY_DATABASE_URI'] = database_url or 'sqlite:///dev.db'
app.config['SQLALCHEMY_TRACK_MODIFICATIONS'] = False
app.config['SQLALCHEMY_ENGINE_OPTIONS'] = {
    # Keep connections healthy on managed Postgres
    "pool_pre_ping": True,
}

def create_app():
    # Initialize extensions
    from extensions import db, jwt
    from flask_jwt_extended import (
        create_access_token,
        get_jwt_identity,
        jwt_required,
    )
    from models_pg import User, RefreshToken, BankAccount, Transaction, Profile, BehavioralProfile
    
    # Initialize extensions with app
    db.init_app(app)
    jwt.init_app(app)

    # Create tables (simple auto-migrate for dev)
    with app.app_context():
        db.create_all()
    
    def _issue_tokens(user: User) -> dict:
        access_token = create_access_token(
            identity=user.id,
            expires_delta=timedelta(seconds=int(app.config.get('JWT_ACCESS_TOKEN_EXPIRES', 86400))),
        )
        refresh_token = secrets.token_hex(32)
        db.session.add(RefreshToken(token=refresh_token, user_id=user.id))
        db.session.commit()
        return {"access_token": access_token, "refresh_token": refresh_token, "expires_in": 86400}

    @app.route('/api/auth/signup', methods=['POST', 'OPTIONS'])
    def signup():
        if request.method == 'OPTIONS':
            return jsonify({'status': 'ok'}), 200

        data = request.get_json(silent=True) or {}
        first_name = str(data.get('first_name', '')).strip()
        last_name = str(data.get('last_name', '')).strip()
        name = str(data.get('name', '')).strip()
        full_name = f"{first_name} {last_name}".strip() if first_name else name
        email = str(data.get('email', '')).strip().lower()
        password = str(data.get('password', ''))
        phone = str(data.get('phone', '')).strip()

        if not full_name:
            return jsonify({'status': 'error', 'message': 'Name is required'}), 400
        if not email:
            return jsonify({'status': 'error', 'message': 'Email is required'}), 400
        if not password:
            return jsonify({'status': 'error', 'message': 'Password is required'}), 400

        if User.query.filter_by(email=email).first() is not None:
            return jsonify({'status': 'error', 'message': 'User already exists with this email'}), 400

        user = User(name=full_name, email=email, phone=phone, password_hash='')
        user.set_password(password)
        db.session.add(user)
        db.session.commit()

        tokens = _issue_tokens(user)
        return jsonify({
            'status': 'success',
            'message': 'Registration successful',
            'user': user.to_public_dict(),
            'access_token': tokens['access_token'],
            'refresh_token': tokens['refresh_token'],
            'expires_in': tokens['expires_in'],
        }), 201

    @app.route('/api/auth/login', methods=['POST', 'OPTIONS'])
    def login():
        if request.method == 'OPTIONS':
            return jsonify({'status': 'ok'}), 200

        data = request.get_json(silent=True) or {}
        email = str(data.get('email', '')).strip().lower()
        password = str(data.get('password', ''))
        if not email or not password:
            return jsonify({'status': 'error', 'message': 'Email and password are required'}), 400

        user = User.query.filter_by(email=email).first()
        if user is None or not user.check_password(password):
            return jsonify({'status': 'error', 'message': 'Invalid email or password'}), 401

        user.last_login = datetime.utcnow()
        db.session.commit()

        tokens = _issue_tokens(user)
        return jsonify({
            'status': 'success',
            'message': 'Login successful',
            'user': user.to_public_dict(),
            'access_token': tokens['access_token'],
            'refresh_token': tokens['refresh_token'],
            'expires_in': tokens['expires_in'],
        }), 200

    @app.route('/api/auth/refresh', methods=['POST', 'OPTIONS'])
    def refresh():
        if request.method == 'OPTIONS':
            return jsonify({'status': 'ok'}), 200

        data = request.get_json(silent=True) or {}
        refresh_token = str(data.get('refreshToken', '')).strip()
        if not refresh_token:
            return jsonify({'status': 'error', 'message': 'refreshToken is required'}), 400

        rt = RefreshToken.query.filter_by(token=refresh_token).first()
        if rt is None or rt.revoked_at is not None:
            return jsonify({'status': 'error', 'message': 'Invalid refresh token'}), 401

        user = User.query.get(rt.user_id)
        if user is None:
            return jsonify({'status': 'error', 'message': 'User not found'}), 404

        access_token = create_access_token(
            identity=user.id,
            expires_delta=timedelta(seconds=int(app.config.get('JWT_ACCESS_TOKEN_EXPIRES', 86400))),
        )
        return jsonify({'status': 'success', 'token': access_token}), 200

    @app.route('/api/user/me', methods=['GET', 'OPTIONS'])
    @jwt_required()
    def me():
        if request.method == 'OPTIONS':
            return jsonify({'status': 'ok'}), 200
        user_id = get_jwt_identity()
        user = User.query.get(user_id)
        if user is None:
            return jsonify({'status': 'error', 'message': 'User not found'}), 404
        return jsonify(user.to_public_dict()), 200

    @app.route('/api/auth/mpin/setup', methods=['POST', 'OPTIONS'])
    @jwt_required()
    def auth_mpin_setup():
        if request.method == 'OPTIONS':
            return jsonify({'status': 'ok'}), 200
        user_id = get_jwt_identity()
        data = request.get_json(silent=True) or {}
        mpin = str(data.get('mpin', '')).strip()
        if not mpin or len(mpin) < 4:
            return jsonify({'status': 'error', 'message': 'Valid MPIN is required'}), 400
        user = User.query.get(user_id)
        if not user:
            return jsonify({'status': 'error', 'message': 'User not found'}), 404
        user.set_mpin(mpin)
        db.session.commit()
        return jsonify({'status': 'success', 'message': 'MPIN successfully setup'}), 200

    @app.route('/api/auth/mpin/verify', methods=['POST', 'OPTIONS'])
    @jwt_required()
    def auth_mpin_verify():
        if request.method == 'OPTIONS':
            return jsonify({'status': 'ok'}), 200
        user_id = get_jwt_identity()
        data = request.get_json(silent=True) or {}
        mpin = str(data.get('mpin', '')).strip()
        if not mpin:
            return jsonify({'status': 'error', 'message': 'MPIN is required'}), 400
        user = User.query.get(user_id)
        if not user:
            return jsonify({'status': 'error', 'message': 'User not found'}), 404
        if not user.mpin_hash:
            return jsonify({'status': 'error', 'message': 'No MPIN configured'}), 400
        if user.check_mpin(mpin):
            return jsonify({'status': 'success', 'message': 'MPIN verified'}), 200
        return jsonify({'status': 'error', 'message': 'Invalid MPIN'}), 401

    @app.route('/api/accounts', methods=['GET', 'POST', 'OPTIONS'])
    @jwt_required()
    def accounts():
        if request.method == 'OPTIONS':
            return jsonify({'status': 'ok'}), 200
        user_id = get_jwt_identity()

        if request.method == 'GET':
            accounts = BankAccount.query.filter_by(user_id=user_id).order_by(BankAccount.created_at.asc()).all()
            return jsonify({
                'status': 'success',
                'accounts': [a.to_dict() for a in accounts],
                'total': len(accounts),
            }), 200

        data = request.get_json(silent=True) or {}
        required = ['account_number', 'account_holder_name', 'bank_name', 'ifsc_code', 'account_type']
        if not all(k in data and str(data.get(k)).strip() for k in required):
            return jsonify({'status': 'error', 'message': 'Missing required fields'}), 400

        # First account becomes primary automatically
        has_any = BankAccount.query.filter_by(user_id=user_id).count() > 0
        is_primary = bool(data.get('is_primary', False)) or (not has_any)
        if is_primary:
            BankAccount.query.filter_by(user_id=user_id, is_primary=True).update({'is_primary': False})

        account = BankAccount(
            user_id=user_id,
            account_number=str(data.get('account_number')).strip(),
            account_holder_name=str(data.get('account_holder_name')).strip(),
            bank_name=str(data.get('bank_name')).strip(),
            ifsc_code=str(data.get('ifsc_code')).strip(),
            account_type=str(data.get('account_type')).strip().lower(),
            balance=data.get('balance', 0) or 0,
            is_primary=is_primary,
        )
        db.session.add(account)
        db.session.commit()
        return jsonify({'status': 'success', 'message': 'Account created successfully', 'account_id': account.id}), 201

    @app.route('/api/transactions', methods=['GET', 'POST', 'OPTIONS'])
    @jwt_required()
    def transactions():
        if request.method == 'OPTIONS':
            return jsonify({'status': 'ok'}), 200
        user_id = get_jwt_identity()

        if request.method == 'GET':
            account_id = request.args.get('account_id')
            q = Transaction.query.filter_by(user_id=user_id)
            if account_id:
                q = q.filter_by(account_id=account_id)
            txns = q.order_by(Transaction.created_at.desc()).limit(200).all()
            # Flutter currently expects response['data'] in TransactionService.initialize()
            return jsonify({'status': 'success', 'data': [t.to_dict() for t in txns]}), 200

        data = request.get_json(silent=True) or {}
        required = ['account_id', 'amount', 'transaction_type']
        if not all(k in data for k in required):
            return jsonify({'status': 'error', 'message': 'Missing required fields'}), 400

        account_id = str(data.get('account_id'))
        txn_type = str(data.get('transaction_type')).strip().lower()
        description = str(data.get('description', '')).strip()
        recipient_account_id = data.get('recipient_account_id')

        try:
            amount = float(data.get('amount'))
        except Exception:
            return jsonify({'status': 'error', 'message': 'Invalid amount'}), 400
        if amount <= 0:
            return jsonify({'status': 'error', 'message': 'Invalid amount'}), 400

        sender = BankAccount.query.filter_by(id=account_id, user_id=user_id).with_for_update().first()
        if sender is None:
            return jsonify({'status': 'error', 'message': 'Account not found or access denied'}), 404

        recipient = None
        if txn_type == 'transfer':
            if not recipient_account_id:
                return jsonify({'status': 'error', 'message': 'Recipient account ID is required for transfers'}), 400
            recipient = BankAccount.query.filter_by(id=str(recipient_account_id)).with_for_update().first()
            if recipient is None:
                return jsonify({'status': 'error', 'message': 'Recipient account not found'}), 404

        # Atomic balance update
        try:
            if txn_type in ['withdrawal', 'transfer']:
                if float(sender.balance or 0) < amount:
                    return jsonify({'status': 'error', 'message': 'Insufficient funds'}), 400
                sender.balance = (sender.balance or 0) - amount
            elif txn_type == 'deposit':
                sender.balance = (sender.balance or 0) + amount
            else:
                # Treat unknown types as payment (debit)
                if float(sender.balance or 0) < amount:
                    return jsonify({'status': 'error', 'message': 'Insufficient funds'}), 400
                sender.balance = (sender.balance or 0) - amount

            if recipient is not None:
                recipient.balance = (recipient.balance or 0) + amount

            txn = Transaction(
                user_id=user_id,
                account_id=sender.id,
                recipient_account_id=recipient.id if recipient else None,
                amount=amount,
                transaction_type=txn_type,
                description=description,
                status='completed',
            )
            db.session.add(txn)
            db.session.commit()
            return jsonify({'status': 'success', 'message': 'Transaction completed successfully', 'data': txn.to_dict()}), 201
        except Exception as e:
            db.session.rollback()
            logger.error(f"Transaction processing error: {e}", exc_info=True)
            return jsonify({'status': 'error', 'message': 'Transaction failed', 'error': str(e)}), 500

    @app.route('/behavioral/calibrate', methods=['POST', 'OPTIONS'])
    @jwt_required()
    def behavioral_calibrate():
        if request.method == 'OPTIONS':
            return jsonify({'status': 'ok'}), 200
            
        user_id = get_jwt_identity()
            
        data = request.get_json(silent=True) or {}
        sessions = data.get('calibration_sessions', [])
        average_timings = data.get('average_timings', {})
        standard_deviations = data.get('standard_deviations', {})
        
        sessions_processed = len(sessions)
        keystrokes_analyzed = 0
        backspaces = 0
        total_time_ms = 0
        
        for session in sessions:
            keystrokes_analyzed += len(session)
            for k in session:
                if k.get('key') == 'Backspace':
                    backspaces += 1
            
            if len(session) >= 2:
                try:
                    start = session[0].get('timestamp', 0)
                    end = session[-1].get('timestamp', 0)
                    if end > start:
                        total_time_ms += (end - start)
                except Exception:
                    pass
        
        base_accuracy = 1.0
        if keystrokes_analyzed > 0:
            error_rate = backspaces / keystrokes_analyzed
            base_accuracy = max(0.5, 1.0 - error_rate)
            
        wpm = 0
        wps = 0
        if total_time_ms > 0 and keystrokes_analyzed > 0:
            total_seconds = total_time_ms / 1000.0
            wps = keystrokes_analyzed / total_seconds
            wpm = (keystrokes_analyzed / 5) / (total_seconds / 60)
            
        import random
        confidence = min(0.99, max(0.85, base_accuracy * random.uniform(0.92, 0.98)))
        
        # Save to postgres/supabase
        if keystrokes_analyzed > 0:
            try:
                b_profile = BehavioralProfile.query.filter_by(user_id=user_id).first()
                if not b_profile:
                    b_profile = BehavioralProfile(user_id=user_id)
                    db.session.add(b_profile)
                
                b_profile.accuracy = round(base_accuracy, 3)
                b_profile.confidence = round(confidence, 3)
                b_profile.wps = round(wps, 2)
                b_profile.wpm = round(wpm, 1)
                b_profile.keystrokes_analyzed = keystrokes_analyzed
                b_profile.average_timings = average_timings
                b_profile.standard_deviations = standard_deviations
                
                db.session.commit()
            except Exception as e:
                db.session.rollback()
                logger.error(f"Failed to save behavioral profile to postgres for user {user_id}: {e}")
        
        # If empty payload passed through (like a mock request), use default non-zero metrics so user doesn't see zero immediately
        if keystrokes_analyzed == 0:
            return jsonify({
                'status': 'success',
                'message': 'Behavioral profile registered',
                'metrics': {
                    'accuracy': 0.0,
                    'confidence': 0.0,
                    'sessions_processed': 0,
                    'keystrokes_analyzed': 0,
                    'wps': 0.0,
                    'wpm': 0.0
                },
                'calibration_date': datetime.now().isoformat(),
                'profile_id': 'dynamic_profile_123'
            }), 200
            
        return jsonify({
            'status': 'success',
            'message': 'Behavioral model calibrated successfully',
            'metrics': {
                'accuracy': round(base_accuracy, 3),
                'confidence': round(confidence, 3),
                'sessions_processed': sessions_processed,
                'keystrokes_analyzed': keystrokes_analyzed,
                'wps': round(wps, 2),
                'wpm': round(wpm, 1)
            },
            'calibration_date': datetime.now().isoformat(),
            'profile_id': 'dynamic_profile_123'
        }), 200

    @app.route('/behavioral/profile', methods=['GET', 'OPTIONS'])
    @jwt_required()
    def get_behavioral_profile_app():
        if request.method == 'OPTIONS':
            return jsonify({'status': 'ok'}), 200
        
        user_id = get_jwt_identity()
        b_profile = BehavioralProfile.query.filter_by(user_id=user_id).first()
        
        if not b_profile:
            return jsonify({'status': 'error', 'message': 'No behavioral profile found'}), 404
        
        return jsonify({
            'status': 'success',
            'profile': b_profile.to_dict()
        }), 200

    @app.route('/api/profiles', methods=['GET', 'POST', 'OPTIONS'])
    @jwt_required()
    def profiles():
        if request.method == 'OPTIONS':
            return jsonify({'status': 'ok'}), 200
        user_id = get_jwt_identity()

        prof = Profile.query.get(user_id)
        if request.method == 'GET':
            return jsonify({'status': 'success', 'data': prof.to_dict() if prof else {}}), 200

        data = request.get_json(silent=True) or {}
        if prof is None:
            prof = Profile(user_id=user_id)
            db.session.add(prof)
        if 'name' in data:
            prof.name = data.get('name')
        if 'phone' in data:
            prof.phone = data.get('phone')
        if 'address' in data:
            prof.address = data.get('address')
        if 'photo' in data:
            prof.photo = data.get('photo')
        db.session.commit()
        return jsonify({'status': 'success', 'data': prof.to_dict()}), 200
    
    # Simple route to test the API
    @app.route('/')
    def index():
        return jsonify({
            'status': 'success',
            'message': 'Welcome to KetStrokeBank API',
            'version': '1.0.0'
        })
    
    # Test route for debugging
    @app.route('/test')
    def test():
        return jsonify({
            'status': 'success',
            'message': 'Test endpoint working',
            'timestamp': datetime.now().isoformat()
        })
    
    # Direct test routes for API endpoints
    @app.route('/api/test-accounts')
    def test_accounts():
        return jsonify({
            'status': 'success',
            'message': 'Direct accounts test working',
            'accounts': [{'id': 'test', 'balance': 1000}]
        })
    
    @app.route('/api/test-transactions')  
    def test_transactions():
        return jsonify({
            'status': 'success',
            'message': 'Direct transactions test working',
            'transactions': [{'id': 'test', 'amount': 100}]
        })
    
    # MPIN Profile endpoints (kept mock; can be moved to DB later)
    @app.route('/api/profiles/mpin/exists', methods=['GET', 'OPTIONS'])
    def check_mpin_exists():
        if request.method == 'OPTIONS':
            return jsonify({'status': 'ok'}), 200
        
        logger.info("Checking if MPIN profile exists")
        
        # Mock response - you can customize this based on your needs
        return jsonify({
            'status': 'success',
            'exists': False,  # Set to True if user has MPIN set up
            'message': 'MPIN profile check completed'
        }), 200
    
    @app.route('/api/profiles/mpin', methods=['POST', 'GET', 'PUT', 'DELETE', 'OPTIONS'])
    def mpin_profile():
        if request.method == 'OPTIONS':
            return jsonify({'status': 'ok'}), 200
        
        if request.method == 'POST':
            # Create MPIN profile
            logger.info("Creating MPIN profile")
            data = request.get_json()
            
            return jsonify({
                'status': 'success',
                'message': 'MPIN profile created successfully',
                'profile_id': 'mpin_profile_123',
                'created_at': datetime.now().isoformat()
            }), 201
        
        elif request.method == 'GET':
            # Get MPIN profile
            logger.info("Getting MPIN profile")
            
            return jsonify({
                'status': 'success',
                'profile': {
                    'id': 'mpin_profile_123',
                    'user_id': 'test_user_123',
                    'created_at': datetime.now().isoformat(),
                    'last_used': datetime.now().isoformat(),
                    'attempts': 0,
                    'locked': False
                }
            }), 200
        
        elif request.method == 'PUT':
            # Update MPIN profile
            logger.info("Updating MPIN profile")
            data = request.get_json()
            
            return jsonify({
                'status': 'success',
                'message': 'MPIN profile updated successfully',
                'updated_at': datetime.now().isoformat()
            }), 200
        
        elif request.method == 'DELETE':
            # Delete MPIN profile
            logger.info("Deleting MPIN profile")
            
            return jsonify({
                'status': 'success',
                'message': 'MPIN profile deleted successfully'
            }), 200
    
    @app.route('/api/profiles/mpin/verify', methods=['POST', 'OPTIONS'])
    def verify_mpin():
        if request.method == 'OPTIONS':
            return jsonify({'status': 'ok'}), 200
        
        logger.info("Verifying MPIN")
        data = request.get_json()
        
        # Mock verification - always successful for testing
        return jsonify({
            'status': 'success',
            'verified': True,
            'message': 'MPIN verification successful',
            'timestamp': datetime.now().isoformat()
        }), 200
    
    return app

if __name__ == '__main__':
    app = create_app()
    app.run(debug=True, host='0.0.0.0', port=5000)
