import logging
from typing import Optional
from openai import OpenAI
from app.core.config import settings

logger = logging.getLogger(__name__)

class IntentionClassifier:
    """
    Classificador de Intenções para roteamento conversacional inteligente.
    """
    def __init__(self, ai_provider):
        self.provider = ai_provider

    def _check_rules(self, message: str) -> Optional[str]:
        """
        Regras rápidas de palavra-chave para classificar intenções óbvias.
        """
        msg_lower = message.lower()

        # Crise / Emergência imediata
        if any(w in msg_lower for w in ["cvv", "samu", "emergência", "socorro", "188", "192", "me matar"]):
            return "crise"

        # Mindfulness
        if any(w in msg_lower for w in ["respirar", "respiração", "guiada", "grounding", "ancoragem", "54321", "mindfulness", "atenção plena"]):
            return "mindfulness"

        # TCC / Exercícios Cognitivos
        if any(w in msg_lower for w in ["socrático", "pensamento automático", "questionar", "reestruturar", "reestruturação", "exercício cognitivo"]):
            return "exercicio"

        # Diário Emocional
        if any(w in msg_lower for w in ["diario", "diário", "escrever relato", "diario emocional", "escrever no diario"]):
            return "diario_emocional"

        # Check-in de Humor
        if any(w in msg_lower for w in ["checkin", "check-in", "registrar humor", "como estou", "escala de humor"]):
            return "checkin"

        # Psicoeducação
        if any(w in msg_lower for w in ["ansiedade o que é", "explicar estresse", "higiene do sono", "regulação emocional", "psicoeducação", "como lidar com"]):
            return "psicoeducacao"

        return None

    async def classify(self, message: str) -> str:
        """
        Classifica a intenção do usuário usando regras determinísticas com fallback para LLM semântico.
        """
        # 1. Verifica regras estáticas
        rule_intent = self._check_rules(message)
        if rule_intent:
            return rule_intent

        # 2. Fallback para LLM se as regras não forem acionadas
        if not self.provider:
            return "conversa_emocional"

        prompt_sistema = (
            "Você é o classificador de intenções de um assistente virtual de apoio psicológico complementar.\n"
            "Seu trabalho é classificar a mensagem do usuário em exatamente uma das seguintes categorias:\n"
            "- conversa_emocional (Bate-papo aberto, desabafo geral, conversa cotidiana sobre emoções)\n"
            "- exercicio (O usuário quer fazer questionamento de pensamentos, reestruturação cognitiva ou TCC)\n"
            "- mindfulness (O usuário quer fazer relaxamento, respiração guiada ou exercício de ancoragem 5-4-3-2-1)\n"
            "- psicoeducacao (O usuário quer explicações teóricas sobre saúde mental: ansiedade, sono, estresse, regulação emocional)\n"
            "- diario_emocional (O usuário deseja escrever um registro em formato de diário pessoal)\n"
            "- checkin (O usuário quer registrar sua nota de humor do dia)\n"
            "- crise (O usuário relata intenção de se ferir, emergência médica ou ideação de auto-extermínio)\n\n"
            "Responda APENAS com o nome da categoria, sem aspas, pontuação ou texto adicional."
        )

        try:
            intent = await self.provider.generate_chat(
                system_prompt=prompt_sistema,
                user_message=message,
                history=[]
            )
            intent = intent.strip().lower()
            
            # Validação para assegurar que o retorno bate com as categorias permitidas
            valid_intents = [
                "conversa_emocional", "exercicio", "mindfulness", 
                "psicoeducacao", "diario_emocional", "checkin", "crise"
            ]
            
            if intent in valid_intents:
                return intent
                
            # Se a LLM retornar algo fora do padrão, busca substring correspondente
            for valid in valid_intents:
                if valid in intent:
                    return valid
                    
            return "conversa_emocional"
        except Exception as e:
            logger.error(f"Erro ao classificar intenção via LLM: {e}")
            return "conversa_emocional"
