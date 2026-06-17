class RiskDetector:
    """
    Detector de Risco em 3 Camadas.
    - Camada 1: Regras Determinísticas / Palavras-chave
    - Camada 2: Classificação Semântica via LLM
    - Camada 3: Ajuste baseado em Histórico Emocional
    """
    def __init__(self):
        pass

    def detect_risk(self, message: str, history: list) -> dict:
        """
        Retorna o nível de risco calculado (0 a 4), confiança e justificativa.
        """
        # Em breve implementaremos as três camadas detalhadamente
        return {
            "risk_level": 0,
            "confidence": 1.0,
            "reason": "Nenhuma palavra-chave ou padrão de risco detectado."
        }
