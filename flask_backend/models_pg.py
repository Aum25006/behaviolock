from __future__ import annotations

from datetime import datetime
from typing import Optional
import uuid

from werkzeug.security import generate_password_hash, check_password_hash

from extensions import db


class User(db.Model):
    __tablename__ = "users"

    id = db.Column(db.String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    name = db.Column(db.String(200), nullable=False)
    email = db.Column(db.String(320), unique=True, index=True, nullable=False)
    phone = db.Column(db.String(50), nullable=True)
    password_hash = db.Column(db.String(255), nullable=False)
    mpin_hash = db.Column(db.String(255), nullable=True)
    created_at = db.Column(db.DateTime, nullable=False, default=datetime.utcnow)
    last_login = db.Column(db.DateTime, nullable=True)

    def set_password(self, password: str) -> None:
        self.password_hash = generate_password_hash(password)

    def check_password(self, password: str) -> bool:
        return check_password_hash(self.password_hash, password)

    def set_mpin(self, mpin: str) -> None:
        self.mpin_hash = generate_password_hash(mpin)

    def check_mpin(self, mpin: str) -> bool:
        if not self.mpin_hash:
            return False
        return check_password_hash(self.mpin_hash, mpin)

    def to_public_dict(self) -> dict:
        return {
            "id": self.id,
            "name": self.name,
            "email": self.email,
            "phone": self.phone or "",
            "created_at": self.created_at.isoformat() if self.created_at else None,
            "last_login": self.last_login.isoformat() if self.last_login else None,
            "has_mpin": bool(self.mpin_hash)
        }


class RefreshToken(db.Model):
    __tablename__ = "refresh_tokens"

    token = db.Column(db.String(64), primary_key=True)
    user_id = db.Column(db.String(36), db.ForeignKey("users.id"), nullable=False, index=True)
    created_at = db.Column(db.DateTime, nullable=False, default=datetime.utcnow)
    revoked_at = db.Column(db.DateTime, nullable=True)


class BankAccount(db.Model):
    __tablename__ = "bank_accounts"

    id = db.Column(db.String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    user_id = db.Column(db.String(36), db.ForeignKey("users.id"), nullable=False, index=True)

    account_number = db.Column(db.String(50), nullable=False)
    account_holder_name = db.Column(db.String(200), nullable=False)
    bank_name = db.Column(db.String(200), nullable=False)
    ifsc_code = db.Column(db.String(50), nullable=False)
    account_type = db.Column(db.String(50), nullable=False)  # savings/checking/etc

    balance = db.Column(db.Numeric(18, 2), nullable=False, default=0)
    is_primary = db.Column(db.Boolean, nullable=False, default=False)

    created_at = db.Column(db.DateTime, nullable=False, default=datetime.utcnow)
    updated_at = db.Column(db.DateTime, nullable=False, default=datetime.utcnow, onupdate=datetime.utcnow)

    def to_dict(self) -> dict:
        return {
            "id": self.id,
            "account_number": self.account_number,
            "account_type": self.account_type,
            "bank_name": self.bank_name,
            "balance": float(self.balance or 0),
            "currency": "USD",
            "is_primary": bool(self.is_primary),
            "created_at": self.created_at.isoformat() if self.created_at else None,
        }


class Transaction(db.Model):
    __tablename__ = "transactions"

    id = db.Column(db.String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    user_id = db.Column(db.String(36), db.ForeignKey("users.id"), nullable=False, index=True)

    account_id = db.Column(db.String(36), db.ForeignKey("bank_accounts.id"), nullable=False, index=True)
    recipient_account_id = db.Column(db.String(36), db.ForeignKey("bank_accounts.id"), nullable=True)

    amount = db.Column(db.Numeric(18, 2), nullable=False)
    transaction_type = db.Column(db.String(50), nullable=False)  # deposit/withdrawal/transfer/payment
    description = db.Column(db.String(500), nullable=True)
    status = db.Column(db.String(50), nullable=False, default="completed")

    created_at = db.Column(db.DateTime, nullable=False, default=datetime.utcnow)

    def to_dict(self) -> dict:
        return {
            "id": self.id,
            "type": self.transaction_type,
            "amount": float(self.amount or 0),
            "description": self.description or "",
            "date": self.created_at.isoformat() if self.created_at else None,
            "account_id": self.account_id,
            "recipient_account_id": self.recipient_account_id,
            "status": self.status,
        }


class Profile(db.Model):
    __tablename__ = "profiles"

    user_id = db.Column(db.String(36), db.ForeignKey("users.id"), primary_key=True)
    name = db.Column(db.String(200), nullable=True)
    phone = db.Column(db.String(50), nullable=True)
    address = db.Column(db.String(500), nullable=True)
    photo = db.Column(db.Text, nullable=True)  # base64 string
    updated_at = db.Column(db.DateTime, nullable=False, default=datetime.utcnow, onupdate=datetime.utcnow)

    def to_dict(self) -> dict:
        return {
            "name": self.name or "",
            "phone": self.phone or "",
            "address": self.address or "",
            "photo": self.photo or "",
            "updated_at": self.updated_at.isoformat() if self.updated_at else None,
        }

class BehavioralProfile(db.Model):
    __tablename__ = "behavioral_profiles"

    user_id = db.Column(db.String(36), db.ForeignKey("users.id"), primary_key=True)
    accuracy = db.Column(db.Numeric(5, 3), nullable=False)
    confidence = db.Column(db.Numeric(5, 3), nullable=False)
    wps = db.Column(db.Numeric(8, 2), nullable=False)
    wpm = db.Column(db.Numeric(8, 1), nullable=False)
    keystrokes_analyzed = db.Column(db.Integer, nullable=False)
    average_timings = db.Column(db.JSON, nullable=True)
    standard_deviations = db.Column(db.JSON, nullable=True)
    created_at = db.Column(db.DateTime, nullable=False, default=datetime.utcnow)
    updated_at = db.Column(db.DateTime, nullable=False, default=datetime.utcnow, onupdate=datetime.utcnow)

    def to_dict(self) -> dict:
        return {
            "user_id": self.user_id,
            "accuracy": float(self.accuracy or 0),
            "confidence": float(self.confidence or 0),
            "wps": float(self.wps or 0),
            "wpm": float(self.wpm or 0),
            "keystrokes_analyzed": self.keystrokes_analyzed or 0,
            "average_timings": self.average_timings or {},
            "standard_deviations": self.standard_deviations or {},
            "created_at": self.created_at.isoformat() if self.created_at else None,
            "updated_at": self.updated_at.isoformat() if self.updated_at else None,
        }

