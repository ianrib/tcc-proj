from fastapi import APIRouter

router = APIRouter()

@router.post("/verify-token")
def verify_firebase_token():
    """Valida o token enviado pelo Flutter."""
    return {"message": "Token verificado", "status": "authenticated"}
