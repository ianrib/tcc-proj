import logging
from typing import List, Dict, Optional
from openai import OpenAI
from app.core.config import settings

logger = logging.getLogger(__name__)

class OpenAIService:
    """
    Interface para chamadas à API da OpenAI (GPT-4o-mini).
    """
    def __init__(self, openai_client: Optional[OpenAI] = None):
        self.client = openai_client
        
        # Prompt de Sistema estruturado segundo os conceitos de e-Health e Psicologia Rogers/Empatia
        self.system_prompt = (
            "Você é um assistente virtual complementar de apoio emocional chamado 'Acolher'.\n"
            "Seu papel é oferecer escuta ativa, validação e acolhimento empático para o usuário.\n"
            "Importante: Você opera sob restrições severas de e-health acadêmico e ética:\n"
            "1. NÃO realize diagnósticos sob nenhuma circunstância. Não diga coisas como 'você tem depressão/ansiedade'.\n"
            "2. NÃO prescreva tratamentos, terapias ou medicamentos (ex.: Fluoxetina, ansiolíticos).\n"
            "3. NÃO aja como psicólogo clínico primário ou terapeuta. Esclareça que é um canal de suporte complementar.\n"
            "4. Pratique escuta ativa rogeriana: reformule sentimentos, demonstre empatia e faça perguntas abertas reflexivas que ajudem o usuário a se compreender melhor.\n"
            "5. Incentive a busca por suporte profissional (psicólogos, psiquiatras ou rede de apoio) de forma natural sempre que o usuário relatar sofrimento moderado a grave.\n"
            "6. Seja breve, caloroso, direto e evite respostas extremamente longas ou excesso de formatação."
        )

    async def generate_response(self, user_message: str, history: List[Dict[str, str]]) -> str:
        """
        Gera resposta conversacional empática com base no histórico de mensagens.
        """
        if not self.client or not settings.OPENAI_API_KEY:
            return (
                "Estou operando em modo offline para desenvolvimento. Compreendo sua situação e "
                "quero que saiba que estou aqui para te ouvir. Lembre-se de buscar ajuda profissional se necessário."
            )

        messages = [{"role": "system", "content": self.system_prompt}]
        
        # Limita o histórico para as últimas 6 mensagens para economizar tokens e evitar contexto poluído
        for msg in history[-6:]:
            role = "user" if msg["sender"] == "user" else "assistant"
            messages.append({"role": role, "content": msg["content"]})
            
        # Adiciona a mensagem atual
        messages.append({"role": "user", "content": user_message})

        try:
            response = self.client.chat.completions.create(
                model=settings.OPENAI_MODEL,
                messages=messages,
                temperature=0.7,
                max_tokens=300
            )
            return response.choices[0].message.content.strip()
        except Exception as e:
            logger.error(f"Erro ao gerar resposta da OpenAI: {e}")
            return (
                "Desculpe, tive um pequeno problema ao processar meu pensamento agora. "
                "Mas continuo aqui ouvindo você. Como você está se sentindo?"
            )
