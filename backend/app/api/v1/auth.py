from fastapi import APIRouter, Header, HTTPException
from typing import Optional
from app.core.security import verify_firebase_token

router = APIRouter()

@router.post("/verify-token")
def verify_token_endpoint(authorization: Optional[str] = Header(None)):
    """Valida o token enviado pelo Flutter via Firebase Auth."""
    if not authorization or not authorization.startswith("Bearer "):
        raise HTTPException(status_code=401, detail="Header de Autorização ausente ou inválido.")
    
    token = authorization.split(" ", 1)[1]
    user_data = verify_firebase_token(token)
    
    if not user_data:
        raise HTTPException(status_code=401, detail="Token inválido ou expirado.")
    
    return {
        "status": "authenticated",
        "uid": user_data["uid"],
        "email": user_data.get("email", ""),
    }
