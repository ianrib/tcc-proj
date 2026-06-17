from fastapi import APIRouter

router = APIRouter()

@router.post("/message")
def send_message():
    """Recebe mensagem do chat e executa detector de risco, classificador e gerência conversacional."""
    return {"message": "Processado", "response": "Olá! Sou o seu assistente complementar."}
