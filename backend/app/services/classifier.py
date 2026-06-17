class IntentionClassifier:
    """
    Classificador de Intenção do usuário:
    - conversa_emocional
    - exercicio
    - mindfulness
    - psicoeducacao
    - diario_emocional
    - checkin
    - crise
    """
    def __init__(self):
        pass

    def classify(self, message: str) -> str:
        """
        Classifica a intenção com base no texto enviado.
        """
        # Em breve implementaremos regras e LLM
        return "conversa_emocional"
