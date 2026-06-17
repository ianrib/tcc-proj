class MindfulnessFlows:
    """
    Técnicas estruturadas de Mindfulness:
    - Respiração guiada
    - Grounding (Técnica 5-4-3-2-1)
    - Exercícios de Atenção Plena
    """
    def __init__(self):
        pass

    def get_grounding_step(self, step: int) -> str:
        """Retorna a instrução para o passo da técnica 5-4-3-2-1."""
        steps = {
            5: "Observe 5 coisas ao seu redor que você possa ver.",
            4: "Toque em 4 coisas que você possa sentir fisicamente.",
            3: "Ouça 3 sons diferentes ao seu redor.",
            2: "Identifique 2 cheiros diferentes.",
            1: "Saboreie ou sinta 1 sabor na boca."
        }
        return steps.get(step, "Exercício concluído.")
