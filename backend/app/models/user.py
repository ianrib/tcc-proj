from pydantic import BaseModel, Field
from typing import Optional

class EmergencyContact(BaseModel):
    name: str
    phone: str
    relation: str
    consent_granted: bool = Field(default=False)

class UserProfileBase(BaseModel):
    name: str
    email: str
    emergency_contact: Optional[EmergencyContact] = None
    consent_lgpd: bool = False

class UserProfileCreate(UserProfileBase):
    uid: str

class UserProfileResponse(UserProfileBase):
    uid: str
