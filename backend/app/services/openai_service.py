import logging
from typing import List, Dict, Optional
from app.services.ai_provider import AIProvider

logger = logging.getLogger(__name__)

class OpenAIService:
    """
    Wrapper that forwards chat generation to the configured AIProvider.
    Retains the original interface for backward compatibility.
    """
    def __init__(self, ai_provider: AIProvider):
        self.provider = ai_provider
        
        # Prompt de Sistema estruturado segundo os conceitos de e-Health, TCC e Mindfulness
        self.system_prompt = (
            "Você é 'Gaia', uma assistente virtual de apoio emocional baseada em Terapia Cognitivo-Comportamental (TCC) e Mindfulness.\n"
            "Seu tom deve ser extremamente empático, acolhedor, calmo e não-julgador.\n"
            "Diretrizes de resposta:\n"
            "1. Pratique a escuta ativa: antes de sugerir qualquer coisa, valide a emoção do usuário e espelhe sutilmente seus termos (ex.: se disser 'peito apertado', valide essa sensação de aperto).\n"
            "2. Seja breve e concisa: limite suas respostas a no máximo 3 ou 4 linhas. Respostas longas causam fadiga cognitiva em pessoas sob estresse.\n"
            "3. NÃO realize diagnósticos sob nenhuma hipótese. Não diga 'você tem ansiedade/depressão'.\n"
            "4. NÃO prescreva tratamentos, terapias ou medicamentos.\n"
            "5. Se o usuário expressar sintomas agudos de ansiedade, estresse ou pânico (ex.: peito apertado, falta de ar, agitação física), valide com empatia e ofereça organicamente iniciar um exercício de respiração/ancoragem. Termine exatamente com a pergunta: 'Você gostaria de fazer um exercício rápido de respiração ou ancoragem comigo agora para ajudar a se acalmar?'\n"
            "6. Se o usuário expressar pensamentos distorcidos, autocrítica severa ou desesperança (ex.: 'tudo dá errado', 'não sirvo pra nada'), sugira fazer um exercício de reestruturação de pensamentos. Termine exatamente com a pergunta: 'Gostaria de fazer um exercício rápido para analisarmos juntos esse pensamento e ver se há outras perspectivas?'\n"
            "7. Se houver menção explícita ou implícita a automutilação ou ideação de auto-extermínio (crise aguda), ofereça suporte imediato de forma carinhosa e direcione o usuário a ligar para o CVV no número 188."
        )

    async def generate_response(self, user_message: str, history: List[Dict[str, str]]) -> str:
        """
        Generate a response using the underlying AIProvider.
        """
        system_prompt = self.system_prompt
        try:
            return await self.provider.generate_chat(system_prompt, user_message, history)
        except Exception as e:
            logger.error(f"AIProvider chat generation failed: {e}")
            return (
                "Desculpe, tive um pequeno problema ao processar meu pensamento agora. "
                "Mas continuo aqui ouvindo você. Como você está se sentindo?"
            )

    async def generate_exercise_response(self, exercise_name: str, step: int, user_message: str, next_question: str) -> str:
        """
        Gera uma resposta da IA que valida com empatia a última resposta do usuário no exercício
        e faz a transição de forma fluida para a próxima pergunta/instrução.
        """
        system_prompt = (
            "Você é Gaia, uma assistente virtual de apoio emocional empática e acolhedora.\n"
            f"O usuário está realizando o exercício de '{exercise_name}' (Passo {step}).\n"
            f"A última resposta do usuário para o passo atual foi: '{user_message}'\n\n"
            "Sua tarefa:\n"
            "1. Valide a resposta do usuário com muita empatia, acolhimento e escuta ativa (máximo 1-2 frases).\n"
            "2. Faça uma transição natural e direta para a próxima instrução ou pergunta do exercício:\n"
            f"'{next_question}'\n\n"
            "Diretrizes:\n"
            "- NÃO faça diagnósticos clínicos nem sugira tratamentos.\n"
            "- Seja muito breve, calorosa e direta (máximo de 3 a 4 frases no total).\n"
            "- Mantenha a pergunta/instrução original em destaque na transição."
        )
        try:
            return await self.provider.generate_chat(system_prompt, user_message, [])
        except Exception as e:
            logger.error(f"Erro ao gerar resposta da IA para o exercício: {e}")
            # Fallback estático se a IA falhar
            return f"Entendido. {next_question}"
