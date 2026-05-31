from datetime import datetime
from sqlalchemy import Column, Integer, Float, String, DateTime
from backend.database import Base

class Transaction(Base):
    __tablename__ = "transactions"

    id = Column(Integer, primary_key=True, index=True)
    amount = Column(Float, nullable=False)
    type = Column(String, nullable=False)  # 'income' or 'expense'
    category = Column(String, nullable=False, default="Other")
    description = Column(String, nullable=True)
    date = Column(String, nullable=False)  # Format: YYYY-MM-DD
    payment_method = Column(String, nullable=True, default="Other")
    raw_text = Column(String, nullable=True)  # Store original AI prompt
    created_at = Column(DateTime, default=datetime.utcnow)
