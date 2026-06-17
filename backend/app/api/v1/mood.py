from fastapi import APIRouter

router = APIRouter()

@router.get("/")
def get_mood_entries():
    """Recupera histórico de humor do usuário."""
    return {"entries": []}
