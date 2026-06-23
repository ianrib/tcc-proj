import logging
from typing import Dict, Any, Tuple

logger = logging.getLogger(__name__)

class TCCFlows:
    """
    Gerenciador dos fluxos estruturados de Terapia Cognitivo-Comportamental (TCC).
    Mantém a lógica da máquina de estados do Questionamento Socrático.
    """
    def __init__(self):
        # Definição dos diálogos de cada passo do Questionamento Socrático
        self.socratic_steps = {
            1: "Entendi que você está lidando com um pensamento difícil. Vamos investigar isso juntos através de algumas perguntas? Qual é o pensamento automático ou preocupação que está passando pela sua cabeça agora?",
            2: "Ok, anotei seu pensamento. Agora me diga: quais são as evidências reais de que esse pensamento é verdadeiro? E quais evidências mostram que ele pode não ser totalmente real?",
            3: "Entendo. Pensando de forma ampla: qual seria o pior cenário se esse pensamento se confirmasse? E qual seria o melhor cenário possível?",
            4: "E o que é mais provável de acontecer na realidade, longe dos extremos?",
            5: "Com base em tudo o que analisamos, como você poderia reescrever esse pensamento de uma forma mais realista e acolhedora?",
            6: "Excelente exercício! Esse registro foi consolidado e guardado no seu diário emocional para acompanhar sua reestruturação cognitiva. Como você está se sentindo agora comparado a quando começamos?"
        }

    def process_socratic_step(self, flow_state: Dict[str, Any], user_message: str) -> Tuple[str, Dict[str, Any], bool]:
        """
        Processa a mensagem do usuário no fluxo de Questionamento Socrático.
        Retorna:
          - A mensagem de resposta a ser enviada ao usuário.
          - O estado do fluxo atualizado.
          - Um booleano indicando se o exercício foi concluído.
        """
        step = flow_state.get("step", 1)
        data = flow_state.get("data", {})

        # Armazena os dados coletados de acordo com o passo que o usuário acabou de responder
        if step == 1:
            data["pensamento_original"] = user_message
            next_step = 2
        elif step == 2:
            data["evidencias"] = user_message
            next_step = 3
        elif step == 3:
            data["pior_melhor_cenario"] = user_message
            next_step = 4
        elif step == 4:
            data["probabilidade_real"] = user_message
            next_step = 5
        elif step == 5:
            data["pensamento_reestruturado"] = user_message
            next_step = 6
        else:
            next_step = 6

        # Atualiza o estado
        updated_state = {
            "exercise": "questionamento_socratico",
            "step": next_step,
            "data": data
        }

        # Resgate da fala para o próximo passo
        response_msg = self.socratic_steps.get(next_step, "Exercício finalizado.")
        
        # Se for o passo final (6), sinaliza conclusão
        is_completed = (next_step == 6)

        return response_msg, updated_state, is_completed
