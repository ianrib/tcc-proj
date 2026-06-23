import logging
from typing import Dict, Any, List, Optional, Tuple
from app.services.risk_detector import RiskDetector
from app.services.classifier import IntentionClassifier
from app.services.openai_service import OpenAIService
from app.services.validator import ResponseValidator
from app.services.tcc_flows import TCCFlows
from app.services.mindfulness import MindfulnessFlows

logger = logging.getLogger(__name__)

class ConversationalManager:
    """
    Gerenciador Conversacional Híbrido.
    Integra detector de risco, classificador de intenções, fluxos estruturados e IA.
    """
    def __init__(
        self,
        risk_detector: RiskDetector,
        classifier: IntentionClassifier,
        openai_service: OpenAIService,
        validator: ResponseValidator,
        tcc_flows: TCCFlows,
        mindfulness_flows: MindfulnessFlows
    ):
        self.risk_detector = risk_detector
        self.classifier = classifier
        self.openai_service = openai_service
        self.validator = validator
        self.tcc_flows = tcc_flows
        self.mindfulness_flows = mindfulness_flows

        # Textos psicoeducativos estáticos para regulação rápida e segurança
        self.psicoeducacao_conteudos = {
            "ansiedade": (
                "A ansiedade é uma resposta natural do nosso corpo ao estresse, uma espécie de 'alarme' interno. "
                "Para ajudar a acalmá-la no momento: 1) Foque em alongar a sua expiração (respire em 4 tempos e solte o ar em 6 tempos); "
                "2) Observe os objetos ao seu redor para ancorar sua mente no presente; 3) Escreva o que está sentindo para externar a preocupação. "
                "Se a ansiedade for muito frequente, é importante conversar com um terapeuta ou médico."
            ),
            "estresse": (
                "O estresse excessivo surge quando sentimos que as demandas externas superam nossa capacidade de lidar com elas. "
                "Praticar pequenas pausas durante o dia, fazer atividades físicas leves e priorizar tarefas podem ajudar a reduzir a tensão física e mental."
            ),
            "sono": (
                "Para melhorar o sono (Higiene do Sono): tente dormir e acordar sempre no mesmo horário; evite telas (celular/computador) "
                "pelo menos 1 hora antes de deitar; mantenha o quarto escuro e silencioso; e evite cafeína ou refeições pesadas à noite."
            ),
            "default": (
                "Cuidar das nossas emoções envolve autocompaixão e o reconhecimento de que todos nós passamos por momentos desafiadores. "
                "Lembre-se de respirar fundo, ser gentil consigo mesmo e não hesitar em pedir ajuda a amigos, familiares ou profissionais."
            )
        }

    async def process_message(
        self,
        message: str,
        history: List[Dict[str, Any]],
        session_state: Dict[str, Any],
        recent_mood_scores: List[int],
        recent_risk_levels: List[int]
    ) -> Tuple[Dict[str, Any], Dict[str, Any]]:
        """
        Orquestra toda a lógica do chat em cada interação.
        Retorna:
          - Um dicionário contendo a resposta para o usuário e metadados.
          - O estado da sessão de chat atualizado.
        """
        # 1. Executa a Detecção de Risco nas 3 camadas
        risk_result = await self.risk_detector.detect_risk(
            message=message,
            recent_mood_scores=recent_mood_scores,
            recent_risk_levels=recent_risk_levels
        )
        risk_level = risk_result["risk_level"]
        logger.info(f"Processando mensagem. Risco detectado: {risk_level} ({risk_result['reason']})")

        # Tratamento de Crise Extrema (Nível 4 - Crise Aguda)
        if risk_level == 4:
            response_data = {
                "sender": "assistant",
                "content": (
                    "Detectamos que você pode estar passando por um momento de sofrimento extremo. "
                    "Por favor, não passe por isso sozinho. Recomendamos fortemente entrar em contato com "
                    "os serviços de apoio de emergência imediatamente."
                ),
                "risk_level": 4,
                "intent": "crise",
                "action": "show_emergency_screen",
                "emergency_numbers": {"CVV": "188", "SAMU": "192"}
            }
            # Força o reset de qualquer exercício ativo na sessão
            session_state = {"exercise": None, "step": 1, "data": {}}
            return response_data, session_state

        # Tratamento de Alto Risco (Nível 3)
        if risk_level == 3:
            response_data = {
                "sender": "assistant",
                "content": (
                    "Sinto muito que você esteja se sentindo dessa forma. Quero te lembrar que sua vida é importante "
                    "e há ajuda disponível. Que tal conversar com o Centro de Valorização da Vida (CVV - 188) ou "
                    "entrar em contato com o seu contato de confiança cadastrado? Estou aqui para te ouvir também."
                ),
                "risk_level": 3,
                "intent": "crise",
                "action": "show_support_options",
                "emergency_numbers": {"CVV": "188"}
            }
            # Reseta estado do exercício ativo
            session_state = {"exercise": None, "step": 1, "data": {}}
            return response_data, session_state

        # 2. Roteamento Conversacional para Risco <= 2
        active_exercise = session_state.get("exercise")

        # Caso esteja rodando um Exercício de TCC ativo
        if active_exercise == "questionamento_socratico":
            if "cancelar" in message.lower() or "sair do exercício" in message.lower() or "parar" in message.lower():
                session_state = {"exercise": None, "step": 1, "data": {}}
                return {
                    "sender": "assistant",
                    "content": "Exercício de TCC interrompido. Voltamos ao bate-papo comum. Como posso te ajudar agora?",
                    "risk_level": risk_level,
                    "intent": "conversa_emocional",
                    "action": "exercise_aborted"
                }, session_state

            response_content, updated_state, is_completed = self.tcc_flows.process_socratic_step(session_state, message)
            
            # Se terminou o exercício de TCC, salvamos os dados no histórico de diário
            action_tag = "exercise_socratic_completed" if is_completed else "exercise_socratic_step"
            if is_completed:
                # O estado é limpo após a conclusão
                session_state = {"exercise": None, "step": 1, "data": {}}
            else:
                session_state = updated_state

            return {
                "sender": "assistant",
                "content": response_content,
                "risk_level": risk_level,
                "intent": "exercicio",
                "action": action_tag
            }, session_state

        # Caso esteja rodando um Exercício de Mindfulness (Grounding) ativo
        if active_exercise == "grounding_54321":
            if "cancelar" in message.lower() or "sair do exercício" in message.lower() or "parar" in message.lower():
                session_state = {"exercise": None, "step": 1, "data": {}}
                return {
                    "sender": "assistant",
                    "content": "Exercício de Mindfulness interrompido. Voltamos ao bate-papo. Como posso te ajudar agora?",
                    "risk_level": risk_level,
                    "intent": "conversa_emocional",
                    "action": "exercise_aborted"
                }, session_state

            response_content, updated_state, is_completed = self.mindfulness_flows.process_grounding_step(session_state, message)
            
            action_tag = "exercise_grounding_completed" if is_completed else "exercise_grounding_step"
            if is_completed:
                session_state = {"exercise": None, "step": 1, "data": {}}
            else:
                session_state = updated_state

            return {
                "sender": "assistant",
                "content": response_content,
                "risk_level": risk_level,
                "intent": "mindfulness",
                "action": action_tag
            }, session_state

        # 3. Caso não haja exercício ativo, classifica a nova intenção da mensagem
        intent = await self.classifier.classify(message)
        logger.info(f"Intenção classificada: {intent}")

        # Roteamento baseado em novas intenções detectadas
        if intent == "mindfulness":
            # Inicializa o exercício de Grounding 5-4-3-2-1
            session_state = {
                "exercise": "grounding_54321",
                "step": 1,
                "data": {}
            }
            initial_msg = self.mindfulness_flows.grounding_steps[1]
            return {
                "sender": "assistant",
                "content": initial_msg,
                "risk_level": risk_level,
                "intent": "mindfulness",
                "action": "exercise_grounding_started"
            }, session_state

        elif intent == "exercicio":
            # Inicializa o Questionamento Socrático de TCC
            session_state = {
                "exercise": "questionamento_socratico",
                "step": 1,
                "data": {}
            }
            initial_msg = self.tcc_flows.socratic_steps[1]
            return {
                "sender": "assistant",
                "content": initial_msg,
                "risk_level": risk_level,
                "intent": "exercicio",
                "action": "exercise_socratic_started"
            }, session_state

        elif intent == "psicoeducacao":
            # Retorna conteúdo teórico validado de regulação emocional
            content = self.psicoeducacao_conteudos.get("default")
            msg_lower = message.lower()
            for key in self.psicoeducacao_conteudos.keys():
                if key in msg_lower:
                    content = self.psicoeducacao_conteudos[key]
                    break
                    
            return {
                "sender": "assistant",
                "content": content,
                "risk_level": risk_level,
                "intent": "psicoeducacao",
                "action": "show_psychoeducation"
            }, session_state

        elif intent == "diario_emocional":
            return {
                "sender": "assistant",
                "content": "Percebi que você quer escrever em seu diário. Você pode registrar suas ideias e humor diretamente no menu 'Diário' para guardarmos suas reflexões de forma segura.",
                "risk_level": risk_level,
                "intent": "diario_emocional",
                "action": "suggest_journal_tab"
            }, session_state

        elif intent == "checkin":
            return {
                "sender": "assistant",
                "content": "Como está o seu humor hoje? Você pode registrá-lo rapidamente selecionando a nota e o emoji adequado no seu Painel Principal.",
                "risk_level": risk_level,
                "intent": "checkin",
                "action": "suggest_checkin_tab"
            }, session_state

        # Fallback padrão: Conversa aberta empática (IA Generativa)
        ai_response = await self.openai_service.generate_response(
            user_message=message,
            history=history
        )

        # 4. Executa o Validador de Segurança Failsafe na saída da IA
        safe_response = self.validator.validate_and_sanitize(ai_response)

        return {
            "sender": "assistant",
            "content": safe_response,
            "risk_level": risk_level,
            "intent": "conversa_emocional",
            "action": "ai_response"
        }, session_state
