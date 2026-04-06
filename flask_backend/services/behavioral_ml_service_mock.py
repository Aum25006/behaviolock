"""
Mock Behavioral ML Service for Testing
This provides the same interface but returns mock responses for quick testing
"""

import logging
from datetime import datetime
from typing import List, Dict, Optional
import os
import json
import random

logger = logging.getLogger(__name__)

class BehavioralMLModel:
    """Mock Machine Learning model for behavioral authentication"""
    
    def __init__(self, model_path: str = "models/behavioral_model.joblib"):
        self.model_path = model_path
        self.is_trained = True  # Always trained in mock mode
        self.feature_names = ['avg_dwell_time', 'avg_flight_time', 'typing_speed']
        
        # Create models directory if it doesn't exist
        os.makedirs(os.path.dirname(model_path), exist_ok=True)
    
    def train_user_model(self, user_keystroke_data: List[List[Dict]], 
                        impostor_data: Optional[List[List[Dict]]] = None) -> Dict[str, float]:
        """Mock training - always returns success"""
        logger.info(f"Mock training with {len(user_keystroke_data)} user sessions")
        
        return {
            'user_avg_score': 0.85,
            'user_std_score': 0.12,
            'accuracy': 0.95,
            'training_sessions': len(user_keystroke_data)
        }
    
    def authenticate(self, keystroke_data: List[Dict]) -> Dict[str, float]:
        """Mock authentication - returns random but realistic results"""
        if not keystroke_data:
            return {
                'authenticated': False,
                'confidence': 0.0,
                'anomaly_score': -2.0,
                'classification_score': 0.0,
                'error': 'No keystroke data'
            }
        
        # Generate realistic mock scores
        base_confidence = random.uniform(0.7, 0.95)  # Usually high for legitimate users
        anomaly_score = random.uniform(-0.5, 1.5)
        classification_score = random.uniform(0.6, 0.9)
        
        # Occasionally simulate suspicious activity
        if random.random() < 0.1:  # 10% chance of suspicious activity
            base_confidence = random.uniform(0.3, 0.6)
            anomaly_score = random.uniform(-2.0, -0.5)
            classification_score = random.uniform(0.2, 0.5)
        
        authenticated = base_confidence > 0.5 and anomaly_score > -1.0
        
        result = {
            'authenticated': authenticated,
            'confidence': base_confidence,
            'anomaly_score': anomaly_score,
            'classification_score': classification_score,
            'is_inlier': authenticated,
            'feature_count': len(keystroke_data)
        }
        
        logger.info(f"Mock authentication result: {result}")
        return result
    
    def update_model(self, new_keystroke_data: List[Dict], is_legitimate: bool = True):
        """Mock model update"""
        logger.info(f"Mock model update: legitimate={is_legitimate}")
    
    def save_model(self):
        """Mock save"""
        logger.info("Mock model saved")
    
    def load_model(self):
        """Mock load"""
        logger.info("Mock model loaded")

class BehavioralAuthService:
    """Mock service for managing behavioral authentication"""
    
    def __init__(self):
        self.models = {}  # user_id -> BehavioralMLModel
        self.user_data = {}  # user_id -> List[keystroke_sessions]
    
    def get_or_create_model(self, user_id: str) -> BehavioralMLModel:
        """Get or create ML model for a user"""
        if user_id not in self.models:
            model_path = f"models/behavioral_model_{user_id}.joblib"
            self.models[user_id] = BehavioralMLModel(model_path)
        return self.models[user_id]
    
    def train_user_model(self, user_id: str, calibration_sessions: List[List[Dict]]) -> Dict[str, float]:
        """Train behavioral model for a user"""
        model = self.get_or_create_model(user_id)
        
        # Store user data for future retraining
        self.user_data[user_id] = calibration_sessions
        
        return model.train_user_model(calibration_sessions)
    
    def authenticate_user(self, user_id: str, keystroke_data: List[Dict]) -> Dict[str, float]:
        """Authenticate user based on keystroke behavior"""
        model = self.get_or_create_model(user_id)
        return model.authenticate(keystroke_data)
    
    def update_user_model(self, user_id: str, keystroke_data: List[Dict], is_legitimate: bool = True):
        """Update user model with new data"""
        model = self.get_or_create_model(user_id)
        model.update_model(keystroke_data, is_legitimate)
    
    def get_user_stats(self, user_id: str) -> Dict[str, any]:
        """Get behavioral statistics for a user"""
        model = self.get_or_create_model(user_id)
        user_sessions = self.user_data.get(user_id, [])
        
        return {
            'user_id': user_id,
            'is_trained': model.is_trained,
            'training_sessions': len(user_sessions),
            'feature_count': len(model.feature_names),
            'model_path': model.model_path
        }

# Global service instance
behavioral_auth_service = BehavioralAuthService()
