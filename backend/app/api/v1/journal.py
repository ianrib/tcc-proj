from fastapi import APIRouter

router = APIRouter()

@router.get("/")
def get_journal_entries():
    """Recupera entradas do diário do usuário."""
    return {"entries": []}
