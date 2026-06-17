from pydantic import BaseModel
from datetime import datetime
from typing import Optional

class JournalEntryBase(BaseModel):
    content: str
    mood_score: int  # Escala de 1 a 10
    associated_emoji: Optional[str] = None

class JournalEntryCreate(JournalEntryBase):
    pass

class JournalEntryResponse(JournalEntryBase):
    id: str
    timestamp: datetime
