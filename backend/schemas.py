from pydantic import BaseModel, Field
from typing import Optional, List, Dict

class TransactionBase(BaseModel):
    amount: float
    type: str = Field(description="Must be 'income' or 'expense'")
    category: str = Field(default="Other")
    description: Optional[str] = None
    date: str = Field(description="Format: YYYY-MM-DD")
    payment_method: Optional[str] = "Other"
    raw_text: Optional[str] = None

class TransactionCreate(TransactionBase):
    pass

class Transaction(TransactionBase):
    id: int

    class Config:
        from_attributes = True

class ChatRequest(BaseModel):
    message: str
    history: Optional[List[Dict[str, str]]] = []  # Array of {"role": "user"/"assistant", "content": "..."}

class ChatResponse(BaseModel):
    reply: str
    parsed_transaction: Optional[TransactionBase] = None  # If AI detects bookkeeping intent

class ParseRequest(BaseModel):
    text: str

class ParseResponse(BaseModel):
    success: bool
    data: Optional[TransactionBase] = None
    error: Optional[str] = None

class CategorySummary(BaseModel):
    category: str
    amount: float
    percentage: float

class DailySummary(BaseModel):
    date: str
    income: float
    expense: float

class StatsResponse(BaseModel):
    total_income: float
    total_expense: float
    net_savings: float
    category_expenses: List[CategorySummary]
    category_incomes: List[CategorySummary]
    daily_trend: List[DailySummary]
