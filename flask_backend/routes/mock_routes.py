from flask import Blueprint, request, jsonify
from datetime import datetime
import logging

logger = logging.getLogger(__name__)

# Mock accounts blueprint
mock_accounts_bp = Blueprint('mock_accounts', __name__)

@mock_accounts_bp.route('', methods=['GET', 'OPTIONS'])
@mock_accounts_bp.route('/', methods=['GET', 'OPTIONS'])
def get_accounts():
    """Mock accounts endpoint"""
    if request.method == 'OPTIONS':
        return jsonify({'status': 'ok'}), 200
    
    # Mock account data
    mock_accounts = [
        {
            'id': 'acc_001',
            'account_number': '1234567890',
            'account_type': 'savings',
            'bank_name': 'BehavioLock Bank',
            'balance': 25000.50,
            'currency': 'USD',
            'is_primary': True,
            'created_at': datetime.utcnow().isoformat()
        },
        {
            'id': 'acc_002', 
            'account_number': '0987654321',
            'account_type': 'checking',
            'bank_name': 'BehavioLock Bank',
            'balance': 5500.75,
            'currency': 'USD',
            'is_primary': False,
            'created_at': datetime.utcnow().isoformat()
        }
    ]
    
    return jsonify({
        'status': 'success',
        'accounts': mock_accounts,
        'total': len(mock_accounts)
    }), 200

# Mock transactions blueprint
mock_transactions_bp = Blueprint('mock_transactions', __name__)

@mock_transactions_bp.route('', methods=['GET', 'OPTIONS'])
@mock_transactions_bp.route('/', methods=['GET', 'OPTIONS'])
def get_transactions():
    """Mock transactions endpoint"""
    if request.method == 'OPTIONS':
        return jsonify({'status': 'ok'}), 200
    
    # Mock transaction data
    mock_transactions = [
        {
            'id': 'txn_001',
            'type': 'credit',
            'amount': 1000.00,
            'description': 'Salary Credit',
            'date': datetime.utcnow().isoformat(),
            'account_id': 'acc_001',
            'status': 'completed'
        },
        {
            'id': 'txn_002',
            'type': 'debit', 
            'amount': 250.00,
            'description': 'Grocery Shopping',
            'date': datetime.utcnow().isoformat(),
            'account_id': 'acc_001',
            'status': 'completed'
        },
        {
            'id': 'txn_003',
            'type': 'transfer',
            'amount': 500.00,
            'description': 'Transfer to Savings',
            'date': datetime.utcnow().isoformat(),
            'account_id': 'acc_002',
            'status': 'completed'
        }
    ]
    
    return jsonify({
        'status': 'success',
        'transactions': mock_transactions,
        'total': len(mock_transactions)
    }), 200
