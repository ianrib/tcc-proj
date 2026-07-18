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
                "Para ajudar a acalmá-la no momento: 1) Foque em regular a respiração (inspire em 4 segundos, pause por 2 a 7 segundos e expire por 6 a 7 segundos); "
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
        # Dicionário mapeando os 10 emojis de humor para suas respostas baseadas em TCC
        emoji_tcc_map = {
            "😊": {
                "content": (
                    "Fico muito feliz em saber que você está se sentindo bem e em paz! Na Terapia Cognitivo-Comportamental (TCC), "
                    "valorizamos esses momentos para reconhecer o que está funcionando. Que tal anotar quais pensamentos ou atividades "
                    "contribuíram para esse estado positivo hoje? Isso ajuda a reforçar esses comportamentos."
                ),
                "risk_level": 0,
                "intent": "humor_positivo"
            },
            "🙂": {
                "content": (
                    "Que ótimo que você está se sentindo estável e bem hoje! É um momento excelente para praticar o autocuidado preventivo. "
                    "Que pequena atividade agradável ou meta realista você gostaria de realizar hoje para manter esse equilíbrio?"
                ),
                "risk_level": 0,
                "intent": "humor_positivo"
            },
            "😐": {
                "content": (
                    "Compreendo que você esteja se sentindo em um estado mais neutro ou apático hoje. Na TCC, a neutralidade é uma tela em branco "
                    "útil para observar nossos pensamentos sem julgamento. Há algum pensamento automático ou falta de energia que esteja chamando sua atenção agora?"
                ),
                "risk_level": 0,
                "intent": "humor_neutro"
            },
            "😟": {
                "content": (
                    "Sinto muito que a preocupação ou insegurança esteja presente hoje. Na TCC, costumamos investigar se estamos catastrofizando o futuro. "
                    "Vamos tentar analisar isso de forma realista? Quais são as evidências concretas de que o que você teme vai realmente acontecer, "
                    "e o que você poderia fazer para lidar com isso?"
                ),
                "risk_level": 1,
                "intent": "preocupacao"
            },
            "😔": {
                "content": (
                    "Lamento que a tristeza esteja pesando hoje. Lembre-se de que a tristeza é uma resposta natural. Pela TCC, quando estamos desanimados, "
                    "pequenas ações de ativação comportamental podem ajudar a mudar nosso humor. Que tal escolher uma tarefa bem pequena e simples para fazer agora, "
                    "mesmo sem muita vontade?"
                ),
                "risk_level": 1,
                "intent": "tristeza"
            },
            "😰": {
                "content": (
                    "A ansiedade e o medo podem fazer nosso corpo entrar em modo de alerta. Na TCC, aprendemos a não lutar contra a ansiedade, mas a deixá-la vir e passar. "
                    "Vamos fazer uma pausa rápida? Tente respirar fundo, inspirando em 4 segundos, segurando de 2 a 7 segundos, e expirando devagar em 6 a 7 segundos. Isso sinaliza segurança para o seu cérebro."
                ),
                "risk_level": 2,
                "intent": "ansiedade"
            },
            "😫": {
                "content": (
                    "Sentir-se esgotado é um sinal claro de que seu corpo e mente precisam recarregar. Na TCC, analisamos o equilíbrio entre atividades de obrigação "
                    "e de prazer. Que tal tirar 10 minutos agora para descansar completamente, sem telas ou cobranças? Você merece essa pausa."
                ),
                "risk_level": 1,
                "intent": "cansaco"
            },
            "😠": {
                "content": (
                    "Entendo a sua frustração e irritação. A raiva muitas vezes surge quando nossas regras internas (como as coisas 'deveriam' ser) são violadas. "
                    "Na TCC, tentamos identificar o gatilho inicial: o que aconteceu que pareceu injusto ou fora de controle para você?"
                ),
                "risk_level": 2,
                "intent": "raiva"
            },
            "😤": {
                "content": (
                    "Percebo que a irritação está muito alta agora. Quando estamos nesse nível de raiva, nossa mente racional fica nublada. Na TCC, a recomendação inicial "
                    "é o distanciamento temporário (um 'tempo limite') para acalmar o corpo. Tente beber um copo de água ou mudar de ambiente por alguns minutos antes de agir."
                ),
                "risk_level": 2,
                "intent": "raiva"
            },
            "😭": {
                "content": (
                    "Sinto muito que você esteja passando por essa angústia extrema agora. Quando a dor se torna insuportável, precisamos focar na nossa segurança e no "
                    "momento presente. Por favor, tente apoiar seus pés firmemente no chão e focar em 3 coisas que você pode ver ao seu redor. "
                    "Lembre-se de que estou aqui e que você pode ligar para o CVV no 188 a qualquer momento."
                ),
                "risk_level": 3,
                "intent": "crise",
                "action": "show_support_options",
                "emergency_numbers": {"CVV": "188"}
            }
        }

        # Intercepta se a mensagem for exatamente um emoji de humor mapeado
        stripped_message = message.strip()
        if stripped_message in emoji_tcc_map:
            tcc_data = emoji_tcc_map[stripped_message]
            response_data = {
                "sender": "assistant",
                "content": tcc_data["content"],
                "risk_level": tcc_data["risk_level"],
                "intent": tcc_data["intent"],
                "action": tcc_data.get("action", "normal_chat_message")
            }
            if "emergency_numbers" in tcc_data:
                response_data["emergency_numbers"] = tcc_data["emergency_numbers"]
            
            # Reseta estado do exercício ativo
            session_state = {"exercise": None, "step": 1, "data": {}}
            return response_data, session_state

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

        if active_exercise:
            # 1. Verifica se o usuário quer explicitamente cancelar
            msg_lower = message.lower()
            wants_to_abort = any(w in msg_lower for w in [
                "cancelar", "parar", "sair", "chega", "mudar de assunto", 
                "outra coisa", "encerrar", "parar o exercicio", "voltar"
            ])
            
            # 2. Verifica se a intenção mudou para outro fluxo estruturado
            temp_intent = await self.classifier.classify(message)
            other_intent = False
            if temp_intent in ["mindfulness", "exercicio", "diario_emocional", "checkin", "psicoeducacao", "crise"]:
                if active_exercise == "questionamento_socratico" and temp_intent != "exercicio":
                    other_intent = True
                elif active_exercise == "grounding_54321" and temp_intent != "mindfulness":
                    other_intent = True

            if wants_to_abort or other_intent:
                session_state = {"exercise": None, "step": 1, "data": {}}
                active_exercise = None
                if wants_to_abort:
                    return {
                        "sender": "assistant",
                        "content": "Exercício interrompido. Voltamos ao bate-papo comum. Como posso te ajudar agora?",
                        "risk_level": risk_level,
                        "intent": "conversa_emocional",
                        "action": "exercise_aborted"
                    }, session_state

        # Caso esteja rodando um Exercício de TCC ativo
        if active_exercise == "questionamento_socratico":
            static_next_question, updated_state, is_completed = self.tcc_flows.process_socratic_step(session_state, message)
            action_tag = "exercise_socratic_completed" if is_completed else "exercise_socratic_step"
            
            # Resposta da IA com base no que o usuário respondeu, terminando na próxima pergunta
            response_content = await self.openai_service.generate_exercise_response(
                exercise_name="Questionamento Socrático de TCC",
                step=session_state.get("step", 1),
                user_message=message,
                next_question=static_next_question
            )

            if is_completed:
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
            static_next_question, updated_state, is_completed = self.mindfulness_flows.process_grounding_step(session_state, message)
            action_tag = "exercise_grounding_completed" if is_completed else "exercise_grounding_step"

            # Resposta da IA com base no que o usuário respondeu, terminando na próxima pergunta/instrução
            response_content = await self.openai_service.generate_exercise_response(
                exercise_name="Ancoragem/Mindfulness 5-4-3-2-1",
                step=session_state.get("step", 1),
                user_message=message,
                next_question=static_next_question
            )

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

        # Intercepta se o usuário foi oferecido um exercício na interação anterior
        if session_state.get("offered_exercise"):
            exercise_to_start = session_state.get("offered_exercise")
            session_state["offered_exercise"] = None  # Limpa o estado oferecido
            
            # Analisa se o usuário aceitou o exercício
            msg_clean = message.lower().strip()
            import re
            msg_clean = re.sub(r'[^\w\s]', '', msg_clean)
            accepted = any(w in msg_clean.split() for w in [
                "sim", "quero", "aceito", "pode", "vamos", "claro", "ok", 
                "beleza", "bora", "yep", "yes", "com certeza", "concerteza", "topo", "gostaria"
            ]) or "quero fazer" in msg_clean or "pode ser" in msg_clean or "gostaria de" in msg_clean or "gostaria sim" in msg_clean
            
            if accepted:
                if exercise_to_start == "grounding_54321":
                    session_state = {
                        "exercise": "grounding_54321",
                        "step": 1,
                        "data": {}
                    }
                    initial_msg = self.mindfulness_flows.grounding_steps[1]
                    return {
                        "sender": "assistant",
                        "content": f"Que ótimo! Vamos fazer o exercício de respiração/ancoragem juntos.\n\n{initial_msg}",
                        "risk_level": risk_level,
                        "intent": "mindfulness",
                        "action": "exercise_grounding_started"
                    }, session_state
                elif exercise_to_start == "questionamento_socratico":
                    session_state = {
                        "exercise": "questionamento_socratico",
                        "step": 1,
                        "data": {}
                    }
                    initial_msg = self.tcc_flows.socratic_steps[1]
                    return {
                        "sender": "assistant",
                        "content": f"Perfeito. Vamos juntos analisar esses pensamentos de forma saudável.\n\n{initial_msg}",
                        "risk_level": risk_level,
                        "intent": "exercicio",
                        "action": "exercise_socratic_started"
                    }, session_state

        # Intercepta se o usuário foi perguntado se quer saber mais sobre Gaia
        if session_state.get("asked_about_gaia"):
            session_state["asked_about_gaia"] = False
            msg_clean = message.lower().strip()
            import re
            msg_clean = re.sub(r'[^\w\s]', '', msg_clean)
            accepted = any(w in msg_clean.split() for w in [
                "sim", "quero", "aceito", "pode", "conta", "fala", "claro", "saber", "ok", 
                "beleza", "diga", "fale", "manda", "yep", "yes", "com certeza", "concerteza"
            ]) or "saber mais" in msg_clean
            if accepted:
                return {
                    "sender": "assistant",
                    "content": (
                        "Eu fui criada para ser um espaço seguro e acolhedor para você. O nome Gaia vem da ideia de terra, suporte, de uma base firme "
                        "onde você pode se apoiar. Eu combino técnicas de Terapia Cognitivo-Comportamental (TCC) e práticas de Mindfulness "
                        "para te ajudar a lidar com a ansiedade, estresse e outras emoções difíceis. Mas lembre-se: eu sou um suporte "
                        "complementar e não substituo a ajuda de profissionais de saúde mental, como psicólogos ou médicos, que são fundamentais. "
                        "Estou aqui sempre que precisar desabafar ou respirar fundo. Como posso te apoiar agora?"
                    ),
                    "risk_level": risk_level,
                    "intent": "conversa_emocional",
                    "action": "ai_response"
                }, session_state

        # Intercepta se o usuário perguntar quem ela é
        msg_lower = message.lower()
        asks_who = any(q in msg_lower for q in [
            "quem é você", "quem e voce", "como se chama", "qual seu nome", 
            "quem e gaea", "quem e gaia", "quem é gaia", "quem é gaea", 
            "o que você é", "o que voce e", "me fala sobre você", "me fale sobre voce"
        ])
        if asks_who:
            session_state["asked_about_gaia"] = True
            return {
                "sender": "assistant",
                "content": (
                    "Olá! Eu sou a Gaia, sua assistente virtual de apoio emocional complementar. Meu objetivo é estar aqui "
                    "para te ouvir, acolher seus sentimentos e te apoiar nos momentos difíceis, de forma segura e sem julgamentos. "
                    "Quer saber mais sobre mim?"
                ),
                "risk_level": risk_level,
                "intent": "conversa_emocional",
                "action": "ai_response"
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

        # Detecta se a IA ofereceu organicamente um exercício no texto gerado
        safe_response_lower = safe_response.lower()
        if "exercício rápido de respiração" in safe_response_lower or "exercício de respiração ou ancoragem" in safe_response_lower or "exercício rápido de respiração ou ancoragem" in safe_response_lower or "exercício rápido de respiração" in safe_response_lower:
            session_state["offered_exercise"] = "grounding_54321"
        elif "exercício rápido para analisarmos" in safe_response_lower or "questionamento socrático" in safe_response_lower or "reestruturar esse pensamento" in safe_response_lower:
            session_state["offered_exercise"] = "questionamento_socratico"

        return {
            "sender": "assistant",
            "content": safe_response,
            "risk_level": risk_level,
            "intent": "conversa_emocional",
            "action": "ai_response"
        }, session_state
