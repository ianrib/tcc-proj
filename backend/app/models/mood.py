from pydantic import BaseModel
from datetime import datetime
from typing import Optional, List

class MoodEntryBase(BaseModel):
    score: int  # Escala de 1 a 10
    emoji: str
    tags: Optional[List[str]] = []

class MoodEntryCreate(MoodEntryBase):
    pass

class MoodEntryResponse(MoodEntryBase):
    id: str
    timestamp: datetime
