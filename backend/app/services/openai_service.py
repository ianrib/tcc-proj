import logging
from typing import List, Dict, Optional, Any
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
            "Seu tom deve ser extremamente empático, acolhedor, natural, fluido e não-julgador. Mantenha conversas naturais e fluidas, demonstrando interesse real e dando continuidade ao assunto.\n"
            "Você DEVE responder exclusivamente em formato JSON válido contendo os seguintes campos:\n"
            "{\n"
            '  "content": "A resposta de apoio emocional contendo no máximo 3 ou 4 linhas. Pratique a escuta ativa: antes de sugerir qualquer coisa, valide a emoção do usuário e espelhe sutilmente seus termos (ex.: se disser \'peito apertado\', valide essa sensação de aperto).",\n'
            '  "suggestions": [\n'
            '     {"title": "Título curto (ex: Iniciar Respiração)", "action": "action:breathing_exercise", "description": "Frase curta explicativa..."}\n'
            '  ]\n'
            "}\n"
            "Forneça no máximo 2 sugestões contextuais no array de 'suggestions'.\n"
            "As ações válidas que você pode sugerir e incluir no campo 'action' são:\n"
            "- 'action:breathing_exercise' (se o usuário relatar ansiedade física, estresse, pânico ou pedir para respirar)\n"
            "- 'action:create_reminder' (se o usuário mencionar consultas, remédios, horários ou tarefas para lembrar)\n"
            "- 'action:socratic_questioning' (se o usuário estiver preso em autocrítica, pensamentos distorcidos, ou desejar fazer reestruturação cognitiva)\n"
            "- 'action:suggest_journal_tab' (se o usuário desejar registrar pensamentos mais longos ou escrever no diário)\n"
            "- 'action:suggest_checkin_tab' (se o usuário quiser registrar humor ou acompanhar seu histórico)\n\n"
            "Regras clínicas rígidas:\n"
            "1. NÃO realize diagnósticos sob nenhuma hipótese. Não diga 'você tem ansiedade/depressão'.\n"
            "2. NÃO prescreva tratamentos, terapias ou medicamentos.\n"
            "3. Se o usuário fizer perguntas fora de seu escopo (como comparações de carros, futebol, política, tecnologia ou perguntas factuais gerais como 'Ferrari é melhor que Mustang?'), recuse educadamente dizendo que isso está fora de sua função como apoio emocional.\n"
            "4. Se houver menção explícita ou implícita a automutilação ou ideação de auto-extermínio (crise aguda), ofereça suporte imediato de forma carinhosa e direcione o usuário a ligar para o CVV no número 188."
        )

    async def generate_response(self, user_message: str, history: List[Dict[str, str]]) -> Dict[str, Any]:
        """
        Generate a response using the underlying AIProvider.
        Returns a dictionary with 'content' and 'suggestions'.
        """
        system_prompt = self.system_prompt
        try:
            raw_response = await self.provider.generate_chat(system_prompt, user_message, history, json_mode=True)
            
            import json
            try:
                data = json.loads(raw_response)
                content = data.get("content", "")
                suggestions = data.get("suggestions", [])
                
                if not isinstance(suggestions, list):
                    suggestions = []
                suggestions = suggestions[:2]
                
                return {
                    "content": content,
                    "suggestions": suggestions
                }
            except json.JSONDecodeError:
                logger.warning(f"Erro ao parsear JSON retornado pela LLM: {raw_response}. Usando fallback.")
                return {
                    "content": raw_response,
                    "suggestions": []
                }
        except Exception as e:
            logger.error(f"AIProvider chat generation failed: {e}")
            return {
                "content": (
                    "Desculpe, tive um pequeno problema ao processar meu pensamento agora. "
                    "Mas continuo aqui ouvindo você. Como você está se sentindo?"
                ),
                "suggestions": []
            }

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
