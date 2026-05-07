import logging

from fastapi import Depends, FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from sqlalchemy import text
from sqlalchemy.orm import Session

from app.config import settings
from app.database import Base, engine, get_db
from app.models import Item

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = FastAPI(title=settings.app_name, version="1.0.0")

# CORS — frontend অন্য origin থেকে call করতে পারবে
app.add_middleware(
    CORSMiddleware,
    allow_origins=[o.strip() for o in settings.cors_origins.split(",")],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


class ItemIn(BaseModel):
    name: str
    description: str | None = None


class ItemOut(ItemIn):
    id: int

    class Config:
        from_attributes = True


@app.on_event("startup")
def on_startup() -> None:
    Base.metadata.create_all(bind=engine)
    logger.info("Database tables ensured.")


@app.get("/health", tags=["system"])
def health(db: Session = Depends(get_db)):
    """Liveness + DB connectivity check"""
    try:
        db.execute(text("SELECT 1"))
        return {"status": "ok", "db": "up", "env": settings.app_env}
    except Exception as exc:
        logger.exception("Health check DB error")
        raise HTTPException(status_code=503, detail=f"DB down: {exc}")


@app.get("/ready", tags=["system"])
def ready():
    """Readiness probe — quick check, DB ছাড়া"""
    return {"status": "ready"}


@app.get("/api/items", response_model=list[ItemOut], tags=["items"])
def list_items(db: Session = Depends(get_db)):
    return db.query(Item).order_by(Item.id.desc()).all()


@app.post("/api/items", response_model=ItemOut, status_code=201, tags=["items"])
def create_item(payload: ItemIn, db: Session = Depends(get_db)):
    item = Item(**payload.model_dump())
    db.add(item)
    db.commit()
    db.refresh(item)
    return item


@app.delete("/api/items/{item_id}", status_code=204, tags=["items"])
def delete_item(item_id: int, db: Session = Depends(get_db)):
    item = db.query(Item).filter(Item.id == item_id).first()
    if not item:
        raise HTTPException(status_code=404, detail="Item not found")
    db.delete(item)
    db.commit()
    return None
