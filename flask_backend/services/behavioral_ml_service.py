# Temporarily disable ML imports for quick testing
# import numpy as np
# import pandas as pd
# from sklearn.ensemble import IsolationForest, RandomForestClassifier
# from sklearn.preprocessing import StandardScaler
# from sklearn.model_selection import train_test_split
# from sklearn.metrics import classification_report, accuracy_score
# import joblib
import logging
from datetime import datetime, timedelta
from typing import List, Dict, Tuple, Optional
import os
import json

logger = logging.getLogger(__name__)

class KeystrokeFeatureExtractor:
    """Extract behavioral features from keystroke timing data"""
    
    @staticmethod
    def extract_features(keystroke_data: List[Dict]) -> Dict[str, float]:
        """
        Extract behavioral features from keystroke timing data
        
        Args:
            keystroke_data: List of keystroke dictionaries with keys:
                - key: character pressed
                - dwellTime: key press duration (ms)
                - flightTime: time between key releases (ms)
                - timestamp: when key was pressed
                - pressure: key pressure (0.0-1.0)
        
        Returns:
            Dictionary of extracted features
        """
        if not keystroke_data:
            return {}
        
        # Convert to DataFrame for easier processing
        df = pd.DataFrame(keystroke_data)
        
        features = {}
        
        # Basic timing features
        features['avg_dwell_time'] = df['dwellTime'].mean()
        features['std_dwell_time'] = df['dwellTime'].std()
        features['min_dwell_time'] = df['dwellTime'].min()
        features['max_dwell_time'] = df['dwellTime'].max()
        
        features['avg_flight_time'] = df['flightTime'].mean()
        features['std_flight_time'] = df['flightTime'].std()
        features['min_flight_time'] = df['flightTime'].min()
        features['max_flight_time'] = df['flightTime'].max()
        
        # Pressure features (if available)
        if 'pressure' in df.columns:
            features['avg_pressure'] = df['pressure'].mean()
            features['std_pressure'] = df['pressure'].std()
        
        # Typing rhythm features
        features['typing_speed'] = len(keystroke_data) / (
            (df['timestamp'].max() - df['timestamp'].min()) / 1000.0 + 1
        )  # characters per second
        
        # Dwell-flight ratio
        features['dwell_flight_ratio'] = (
            features['avg_dwell_time'] / (features['avg_flight_time'] + 1)
        )
        
        # Character-specific features for common keys
        common_keys = ['a', 'e', 'i', 'o', 'u', 's', 't', 'n', 'r', 'l']
        for key in common_keys:
            key_data = df[df['key'] == key]
            if len(key_data) > 0:
                features[f'{key}_avg_dwell'] = key_data['dwellTime'].mean()
                features[f'{key}_avg_flight'] = key_data['flightTime'].mean()
            else:
                features[f'{key}_avg_dwell'] = features['avg_dwell_time']
                features[f'{key}_avg_flight'] = features['avg_flight_time']
        
        # Digraph features (two-character combinations)
        digraphs = []
        for i in range(len(keystroke_data) - 1):
            digraph = keystroke_data[i]['key'] + keystroke_data[i + 1]['key']
            digraphs.append({
                'digraph': digraph,
                'transition_time': keystroke_data[i + 1]['flightTime']
            })
        
        if digraphs:
            digraph_df = pd.DataFrame(digraphs)
            common_digraphs = ['th', 'he', 'in', 'er', 'an', 're', 'ed', 'nd', 'on', 'en']
            
            for digraph in common_digraphs:
                digraph_data = digraph_df[digraph_df['digraph'] == digraph]
                if len(digraph_data) > 0:
                    features[f'{digraph}_transition'] = digraph_data['transition_time'].mean()
                else:
                    features[f'{digraph}_transition'] = features['avg_flight_time']
        
        # Consistency features
        features['dwell_consistency'] = 1.0 / (1.0 + features['std_dwell_time'] / features['avg_dwell_time'])
        features['flight_consistency'] = 1.0 / (1.0 + features['std_flight_time'] / features['avg_flight_time'])
        
        # Replace NaN values with 0
        for key, value in features.items():
            if pd.isna(value):
                features[key] = 0.0
        
        return features

class BehavioralMLModel:
    """Machine Learning model for behavioral authentication (Mock version for testing)"""
    
    def __init__(self, model_path: str = "models/behavioral_model.joblib"):
        self.model_path = model_path
        self.isolation_forest = None
        self.random_forest = None
        self.feature_names = []
        self.is_trained = False
        
        # Create models directory if it doesn't exist
        os.makedirs(os.path.dirname(model_path), exist_ok=True)
        
        # Mock training status
        self.is_trained = True
    
    def train_user_model(self, user_keystroke_data: List[List[Dict]], 
                        impostor_data: Optional[List[List[Dict]]] = None) -> Dict[str, float]:
        """
        Train behavioral model for a specific user
        
        Args:
            user_keystroke_data: List of keystroke sessions from the legitimate user
            impostor_data: Optional list of keystroke sessions from impostors
        
        Returns:
            Training metrics dictionary
        """
        logger.info(f"Training behavioral model with {len(user_keystroke_data)} user sessions")
        
        # Extract features from user data
        user_features = []
        for session in user_keystroke_data:
            features = KeystrokeFeatureExtractor.extract_features(session)
            if features:
                user_features.append(features)
        
        if len(user_features) < 3:
            raise ValueError("Need at least 3 user sessions for training")
        
        # Convert to DataFrame
        user_df = pd.DataFrame(user_features)
        self.feature_names = list(user_df.columns)
        
        # Prepare training data
        X_user = user_df.values
        y_user = np.ones(len(X_user))  # Legitimate user = 1
        
        # Add impostor data if available
        if impostor_data:
            impostor_features = []
            for session in impostor_data:
                features = KeystrokeFeatureExtractor.extract_features(session)
                if features:
                    # Ensure same feature columns
                    feature_dict = {col: features.get(col, 0.0) for col in self.feature_names}
                    impostor_features.append(feature_dict)
            
            if impostor_features:
                impostor_df = pd.DataFrame(impostor_features)
                X_impostor = impostor_df.values
                y_impostor = np.zeros(len(X_impostor))  # Impostor = 0
                
                # Combine user and impostor data
                X = np.vstack([X_user, X_impostor])
                y = np.hstack([y_user, y_impostor])
            else:
                X, y = X_user, y_user
        else:
            X, y = X_user, y_user
        
        # Scale features
        X_scaled = self.scaler.fit_transform(X)
        
        # Train Isolation Forest for anomaly detection (one-class)
        self.isolation_forest = IsolationForest(
            contamination=0.1,  # Expect 10% anomalies
            random_state=42,
            n_estimators=100
        )
        self.isolation_forest.fit(X_scaled[y == 1])  # Train only on legitimate user data
        
        # Train Random Forest if we have impostor data
        metrics = {}
        if impostor_data and len(np.unique(y)) > 1:
            X_train, X_test, y_train, y_test = train_test_split(
                X_scaled, y, test_size=0.2, random_state=42, stratify=y
            )
            
            self.random_forest = RandomForestClassifier(
                n_estimators=100,
                random_state=42,
                class_weight='balanced'
            )
            self.random_forest.fit(X_train, y_train)
            
            # Evaluate model
            y_pred = self.random_forest.predict(X_test)
            metrics['accuracy'] = accuracy_score(y_test, y_pred)
            metrics['classification_report'] = classification_report(y_test, y_pred, output_dict=True)
        
        # Calculate baseline metrics
        user_scores = self.isolation_forest.decision_function(X_scaled[y == 1])
        metrics['user_avg_score'] = float(np.mean(user_scores))
        metrics['user_std_score'] = float(np.std(user_scores))
        
        self.is_trained = True
        self.save_model()
        
        logger.info(f"Model training completed. Metrics: {metrics}")
        return metrics
    
    def authenticate(self, keystroke_data: List[Dict]) -> Dict[str, float]:
        """
        Authenticate user based on keystroke behavior
        
        Args:
            keystroke_data: List of keystroke dictionaries
        
        Returns:
            Authentication result with confidence scores
        """
        if not self.is_trained:
            return {
                'authenticated': False,
                'confidence': 0.0,
                'anomaly_score': 0.0,
                'classification_score': 0.0,
                'error': 'Model not trained'
            }
        
        # Extract features
        features = KeystrokeFeatureExtractor.extract_features(keystroke_data)
        if not features:
            return {
                'authenticated': False,
                'confidence': 0.0,
                'anomaly_score': 0.0,
                'classification_score': 0.0,
                'error': 'No features extracted'
            }
        
        # Ensure same feature columns as training
        feature_vector = np.array([[features.get(col, 0.0) for col in self.feature_names]])
        feature_vector_scaled = self.scaler.transform(feature_vector)
        
        # Get anomaly detection score
        anomaly_score = self.isolation_forest.decision_function(feature_vector_scaled)[0]
        is_inlier = self.isolation_forest.predict(feature_vector_scaled)[0] == 1
        
        # Get classification score if available
        classification_score = 0.5
        if self.random_forest:
            classification_proba = self.random_forest.predict_proba(feature_vector_scaled)[0]
            classification_score = classification_proba[1] if len(classification_proba) > 1 else 0.5
        
        # Combine scores for final confidence
        # Normalize anomaly score to 0-1 range
        normalized_anomaly = 1.0 / (1.0 + np.exp(-anomaly_score))
        
        # Weighted combination of scores
        confidence = (0.6 * normalized_anomaly + 0.4 * classification_score)
        
        # Authentication decision
        authenticated = is_inlier and confidence > 0.5
        
        result = {
            'authenticated': authenticated,
            'confidence': float(confidence),
            'anomaly_score': float(anomaly_score),
            'classification_score': float(classification_score),
            'is_inlier': is_inlier,
            'feature_count': len(features)
        }
        
        logger.info(f"Authentication result: {result}")
        return result
    
    def update_model(self, new_keystroke_data: List[Dict], is_legitimate: bool = True):
        """
        Update model with new keystroke data (incremental learning)
        
        Args:
            new_keystroke_data: New keystroke session data
            is_legitimate: Whether this data is from legitimate user
        """
        if not self.is_trained:
            logger.warning("Cannot update untrained model")
            return
        
        features = KeystrokeFeatureExtractor.extract_features(new_keystroke_data)
        if not features:
            return
        
        # For now, we'll retrain periodically rather than true incremental learning
        # This could be enhanced with online learning algorithms
        logger.info(f"Received feedback for model update: legitimate={is_legitimate}")
    
    def save_model(self):
        """Save trained model to disk"""
        if not self.is_trained:
            return
        
        model_data = {
            'isolation_forest': self.isolation_forest,
            'random_forest': self.random_forest,
            'scaler': self.scaler,
            'feature_names': self.feature_names,
            'is_trained': self.is_trained,
            'timestamp': datetime.now().isoformat()
        }
        
        try:
            joblib.dump(model_data, self.model_path)
            logger.info(f"Model saved to {self.model_path}")
        except Exception as e:
            logger.error(f"Failed to save model: {e}")
    
    def load_model(self):
        """Load trained model from disk"""
        if not os.path.exists(self.model_path):
            logger.info("No existing model found")
            return
        
        try:
            model_data = joblib.load(self.model_path)
            self.isolation_forest = model_data.get('isolation_forest')
            self.random_forest = model_data.get('random_forest')
            self.scaler = model_data.get('scaler')
            self.feature_names = model_data.get('feature_names', [])
            self.is_trained = model_data.get('is_trained', False)
            
            logger.info(f"Model loaded from {self.model_path}")
        except Exception as e:
            logger.error(f"Failed to load model: {e}")
            self.is_trained = False

class BehavioralAuthService:
    """Service for managing behavioral authentication"""
    
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
