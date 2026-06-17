from pydantic import BaseModel
from datetime import datetime
from typing import Optional, List

class ChatMessageBase(BaseModel):
    content: str

class ChatMessageCreate(ChatMessageBase):
    pass

class ChatMessageResponse(ChatMessageBase):
    id: str
    sender: str  # "user" ou "assistant"
    timestamp: datetime
    risk_level: int
    intent: Optional[str] = None
    structured_action: Optional[str] = None
