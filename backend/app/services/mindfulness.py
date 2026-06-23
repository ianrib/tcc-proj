import logging
from typing import Dict, Any, Tuple

logger = logging.getLogger(__name__)

class MindfulnessFlows:
    """
    Gerenciador de exercícios de Mindfulness e Relaxamento.
    Mantém a lógica da técnica de Grounding (Ancoragem) 5-4-3-2-1.
    """
    def __init__(self):
        # Diálogos para conduzir o Grounding 5-4-3-2-1
        self.grounding_steps = {
            1: "Vamos praticar a técnica de ancoragem 5-4-3-2-1 para trazer a atenção de volta ao presente. Sente-se confortavelmente e respire fundo. Quando estiver pronto, escreva 5 coisas que você consegue ver ao seu redor agora.",
            2: "Muito bom. Agora, cite 4 coisas que você consegue tocar ou sentir o contato físico (ex. a cadeira onde está sentado, a roupa tocando a pele).",
            3: "Excelente. Agora, concentre-se e cite 3 sons ou barulhos diferentes que você consegue escutar agora.",
            4: "Ótimo. Identifique 2 cheiros ou aromas diferentes que você consegue sentir no ar.",
            5: "Quase lá! Agora diga 1 sabor que sente na boca ou, se preferir, diga algo positivo pelo qual você sente gratidão hoje.",
            6: "Exercício concluído! Você se trouxe de volta ao momento presente. Respire fundo e sinta seu corpo calmo. Como você está se sentindo?"
        }

    def process_grounding_step(self, flow_state: Dict[str, Any], user_message: str) -> Tuple[str, Dict[str, Any], bool]:
        """
        Processa o passo a passo da técnica de Ancoragem 5-4-3-2-1.
        Retorna:
          - Resposta para exibir ao usuário.
          - Estado atualizado.
          - Booleano indicando se o exercício foi concluído.
        """
        step = flow_state.get("step", 1)
        data = flow_state.get("data", {})

        # Coleta os registros de percepções sensoriais
        if step == 1:
            data["visao_5_itens"] = user_message
            next_step = 2
        elif step == 2:
            data["tato_4_itens"] = user_message
            next_step = 3
        elif step == 3:
            data["audicao_3_itens"] = user_message
            next_step = 4
        elif step == 4:
            data["olfato_2_itens"] = user_message
            next_step = 5
        elif step == 5:
            data["paladar_afirmacao_1_item"] = user_message
            next_step = 6
        else:
            next_step = 6

        # Atualiza o estado
        updated_state = {
            "exercise": "grounding_54321",
            "step": next_step,
            "data": data
        }

        # Resgate da fala para o próximo passo
        response_msg = self.grounding_steps.get(next_step, "Exercício finalizado.")
        
        # Conclusão ocorre ao passar do passo 5 para o 6
        is_completed = (next_step == 6)

        return response_msg, updated_state, is_completed
