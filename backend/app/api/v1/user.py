from fastapi import APIRouter

router = APIRouter()

@router.get("/profile")
def get_user_profile():
    """Recupera perfil do usuário, contatos de emergência e consentimentos."""
    return {"user": {}}
