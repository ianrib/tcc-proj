class ResponseValidator:
    """
    Validador de Respostas da IA.
    Garante que a IA não faça afirmações clínicas, diagnósticos ou prescrições.
    Caso detecte, substitui por uma resposta de segurança/failsafe.
    """
    def __init__(self):
        # Lista de termos bloqueados/frases que indicam diagnóstico/prescrição indesejável
        self.risk_keywords = ["prescrever", "diagnóstico é", "recomendo tomar", "receito"]

    def validate_and_sanitize(self, response: str) -> str:
        """
        Valida a resposta gerada pela LLM.
        Se violar regras éticas de e-health, sanitiza ou retorna um texto alternativo seguro.
        """
        for word in self.risk_keywords:
            if word in response.lower():
                return (
                    "Compreendo sua situação, mas lembre-se de que sou apenas um assistente complementar "
                    "e não posso realizar diagnósticos ou indicar tratamentos médicos. Recomendo que "
                    "busque a avaliação de um profissional de saúde qualificado."
                )
        return response
