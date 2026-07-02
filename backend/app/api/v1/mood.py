from fastapi import APIRouter, Depends, Header, HTTPException
from pydantic import BaseModel
from typing import Optional, List
from datetime import datetime
import uuid

from app.core.database import get_db
from app.api.v1.chat import get_current_user_id

router = APIRouter()

# Schema para criação de registro de humor
class MoodEntryRequest(BaseModel):
    score: int
    emoji: str
    description: str
    tags: List[str]

# Mock local em memória para desenvolvimento offline
mock_mood_entries = []

@router.get("/")
async def get_mood_entries(user_id: str = Depends(get_current_user_id)):
    """
    Recupera o histórico de humor do usuário logado.
    """
    db = get_db()
    entries = []

    if db:
        try:
            # Busca registros de humor do usuário
            mood_ref = db.collection("mood_entries")\
                .where("userId", "==", user_id)
            for doc in mood_ref.stream():
                m_data = doc.to_dict()
                entries.append({
                    "id": doc.id,
                    "userId": m_data.get("userId"),
                    "score": m_data.get("score"),
                    "emoji": m_data.get("emoji"),
                    "description": m_data.get("description", ""),
                    "tags": m_data.get("tags", []),
                    "timestamp": m_data.get("timestamp").isoformat() if m_data.get("timestamp") else None
                })
            # Ordena decrescentemente em memória (mais recente primeiro)
            entries.sort(key=lambda x: x["timestamp"] or "", reverse=True)
        except Exception as e:
            print(f"Erro ao carregar humores do Firestore: {e}")
            db = None

    if not db:
        # Fallback Mock
        entries = [
            e for e in mock_mood_entries if e["userId"] == user_id
        ]
        entries.sort(key=lambda x: x["timestamp"] or "", reverse=True)

    return {"entries": entries}

@router.post("/")
async def create_mood_entry(
    payload: MoodEntryRequest,
    user_id: str = Depends(get_current_user_id)
):
    """
    Cria um novo registro de humor para o usuário logado.
    """
    db = get_db()
    timestamp_now = datetime.utcnow()
    
    entry_doc = {
        "userId": user_id,
        "score": payload.score,
        "emoji": payload.emoji,
        "description": payload.description,
        "tags": payload.tags,
        "timestamp": timestamp_now
    }

    entry_id = str(uuid.uuid4())

    if db:
        try:
            db.collection("mood_entries").document(entry_id).set(entry_doc)
        except Exception as e:
            print(f"Erro ao salvar humor no Firestore: {e}")
            db = None

    # Se falhou ou não tem Firestore, usa Mock
    if not db:
        entry_doc_mock = entry_doc.copy()
        entry_doc_mock["id"] = entry_id
        entry_doc_mock["timestamp"] = timestamp_now.isoformat()
        mock_mood_entries.append(entry_doc_mock)
        
    return {
        "id": entry_id,
        "timestamp": timestamp_now.isoformat(),
        **payload.model_dump() # Pydantic v2 compatível. No Pydantic v1, payload.dict() também funciona, mas model_dump() é preferido.
    }
