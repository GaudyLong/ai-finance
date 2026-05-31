from fastapi import FastAPI, Depends, HTTPException, status
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy.orm import Session
from typing import List, Optional
from datetime import datetime, timedelta

from backend.database import engine, Base, get_db
from backend.models import Transaction as DBTransaction
from backend import schemas
from core.gemma_agent.agent import GemmaAgent

# Initialize DB tables
Base.metadata.create_all(bind=engine)

app = FastAPI(title="AI Finance Backend", version="1.0.0")

# Enable CORS for local testing and iOS Simulator connections
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

agent = GemmaAgent()

@app.get("/")
def read_root():
    return {"status": "running", "agent_available": agent.is_ollama_available()}

@app.post("/api/chat", response_model=schemas.ChatResponse)
def chat_with_advisor(request: schemas.ChatRequest):
    reply, parsed_txn = agent.chat_with_advisor(request.message, request.history)
    return schemas.ChatResponse(
        reply=reply,
        parsed_transaction=schemas.TransactionBase(**parsed_txn) if parsed_txn else None
    )

@app.post("/api/parse", response_model=schemas.ParseResponse)
def parse_text(request: schemas.ParseRequest):
    try:
        parsed_txn = agent.parse_transaction(request.text)
        return schemas.ParseResponse(
            success=True,
            data=schemas.TransactionBase(**parsed_txn)
        )
    except Exception as e:
        return schemas.ParseResponse(
            success=False,
            error=str(e)
        )

# --- TRANSACTION CRUD ---

@app.post("/api/transactions", response_model=schemas.Transaction)
def create_transaction(txn: schemas.TransactionCreate, db: Session = Depends(get_db)):
    db_txn = DBTransaction(
        amount=txn.amount,
        type=txn.type,
        category=txn.category,
        description=txn.description,
        date=txn.date,
        payment_method=txn.payment_method,
        raw_text=txn.raw_text
    )
    db.add(db_txn)
    db.commit()
    db.refresh(db_txn)
    return db_txn

@app.get("/api/transactions", response_model=List[schemas.Transaction])
def get_transactions(
    type: Optional[str] = None,
    category: Optional[str] = None,
    db: Session = Depends(get_db)
):
    query = db.query(DBTransaction)
    if type:
        query = query.filter(DBTransaction.type == type)
    if category:
        query = query.filter(DBTransaction.category == category)
    # Order by date descending, then ID descending
    return query.order_by(DBTransaction.date.desc(), DBTransaction.id.desc()).all()

@app.delete("/api/transactions/{txn_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_transaction(txn_id: int, db: Session = Depends(get_db)):
    db_txn = db.query(DBTransaction).filter(DBTransaction.id == txn_id).first()
    if not db_txn:
        raise HTTPException(status_code=404, detail="Transaction not found")
    db.delete(db_txn)
    db.commit()
    return None

# --- DASHBOARD STATISTICS ---

@app.get("/api/stats", response_model=schemas.StatsResponse)
def get_stats(db: Session = Depends(get_db)):
    txns = db.query(DBTransaction).all()
    
    total_income = sum(t.amount for t in txns if t.type == "income")
    total_expense = sum(t.amount for t in txns if t.type == "expense")
    net_savings = total_income - total_expense

    # Expense breakdown by category
    expense_cats = {}
    income_cats = {}
    for t in txns:
        if t.type == "expense":
            expense_cats[t.category] = expense_cats.get(t.category, 0.0) + t.amount
        else:
            income_cats[t.category] = income_cats.get(t.category, 0.0) + t.amount

    category_expenses = []
    for cat, amt in expense_cats.items():
        pct = (amt / total_expense * 100) if total_expense > 0 else 0
        category_expenses.append(schemas.CategorySummary(category=cat, amount=amt, percentage=round(pct, 1)))
    # Sort by amount descending
    category_expenses.sort(key=lambda x: x.amount, reverse=True)

    category_incomes = []
    for cat, amt in income_cats.items():
        pct = (amt / total_income * 100) if total_income > 0 else 0
        category_incomes.append(schemas.CategorySummary(category=cat, amount=amt, percentage=round(pct, 1)))
    category_incomes.sort(key=lambda x: x.amount, reverse=True)

    # Daily Trend (last 7 days by default, or all days in db sorted)
    # To ensure we have data, we'll collect all distinct dates with transactions
    daily_data = {}
    
    # Pre-populate last 7 days to show a beautiful graph even if sparse
    today = datetime.now()
    for i in range(6, -1, -1):
        d_str = (today - timedelta(days=i)).strftime("%Y-%m-%d")
        daily_data[d_str] = {"income": 0.0, "expense": 0.0}

    for t in txns:
        if t.date not in daily_data:
            # Only add older dates if they exist in the DB
            daily_data[t.date] = {"income": 0.0, "expense": 0.0}
        
        if t.type == "income":
            daily_data[t.date]["income"] += t.amount
        else:
            daily_data[t.date]["expense"] += t.amount

    daily_trend = []
    for d_str, vals in sorted(daily_data.items()):
        daily_trend.append(schemas.DailySummary(date=d_str, income=vals["income"], expense=vals["expense"]))

    # Sort trend by date
    daily_trend.sort(key=lambda x: x.date)

    return schemas.StatsResponse(
        total_income=total_income,
        total_expense=total_expense,
        net_savings=net_savings,
        category_expenses=category_expenses,
        category_incomes=category_incomes,
        daily_trend=daily_trend
    )
