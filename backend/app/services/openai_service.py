from openai import OpenAI
from app.core.config import settings

class OpenAIService:
    """
    Interface para chamadas à API da OpenAI (GPT-4o-mini).
    """
    def __init__(self):
        self.client = None
        if settings.OPENAI_API_KEY:
            self.client = OpenAI(api_key=settings.OPENAI_API_KEY)

    async def generate_response(self, system_prompt: str, user_message: str, history: list) -> str:
        """
        Gera resposta conversacional empática.
        """
        if not self.client:
            return "Estou em modo offline/desenvolvimento. Como posso ajudar você hoje?"
            
        # Em breve implementaremos a chamada de chat completion
        return "Resposta da inteligência artificial."
