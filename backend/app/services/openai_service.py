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
        
        # Prompt de Sistema estruturado segundo os conceitos de e-Health e Psicologia Rogers/Empatia
        self.system_prompt = (
            "Você é um assistente virtual complementar de apoio emocional chamado 'Gaia'.\n"
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
        Generate a response using the underlying AIProvider.
        """
        system_prompt = (
            "Você é um assistente virtual complementar de apoio emocional chamado 'Gaia'.\n"
            "Seu papel é oferecer escuta ativa, validação e acolhimento empático para o usuário.\n"
            "Importante: Você opera sob restrições severas de e-health acadêmico e ética:\n"
            "1. NÃO realize diagnósticos sob nenhuma circunstância. Não diga coisas como 'você tem depressão/ansiedade'.\n"
            "2. NÃO prescreva tratamentos, terapias ou medicamentos (ex.: Fluoxetina, ansiolíticos).\n"
            "3. NÃO aja como psicólogo clínico primário ou terapeuta. Esclareça que é um canal de suporte complementar.\n"
            "4. Pratique escuta ativa rogeriana: reformule sentimentos, demonstre empatia e faça perguntas abertas reflexivas que ajudem o usuário a se compreender melhor.\n"
            "5. Incentive a busca por suporte profissional (psicólogos, psiquiatras ou rede de apoio) de forma natural sempre que o usuário relatar sofrimento moderado a grave.\n"
            "6. Seja breve, caloroso, direto e evite respostas extremamente longas ou excesso de formatação."
        )
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
