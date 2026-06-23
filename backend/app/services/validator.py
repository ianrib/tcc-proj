import re
import logging

logger = logging.getLogger(__name__)

class ResponseValidator:
    """
    Validador Failsafe de Respostas de Inteligência Artificial.
    Garante que termos clínicos proibidos, diagnósticos ou indicações farmacológicas sejam filtrados.
    """
    def __init__(self):
        # Padrões Regex para detecção de termos diagnósticos ou medicamentos
        self.meds_regex = re.compile(
            r"\b(fluoxetina|sertralina|rivotril|clonazepam|diazepam|amitriptilina|paroxetina|venlafaxina|escitalopram|quetiapina|risperidona|haloperidol|alprazolam|medicar|remedio|remédio|receitar|prescrever|tomar dose|receito)\b",
            re.IGNORECASE
        )
        
        self.diag_regex = re.compile(
            r"\b(voce tem depressao|você tem depressão|transtorno de|diagnostico|diagnóstico|patologia|síndrome de|clinicamente|sintomas de esquizofrenia|bipolaridade)\b",
            re.IGNORECASE
        )
        
        self.failsafe_msg = (
            "Compreendo o que você está compartilhando, mas como um assistente virtual complementar, "
            "não posso fornecer diagnósticos, aconselhamento clínico ou indicações de medicamentos. "
            "Se você estiver sentindo que esses sintomas estão atrapalhando sua rotina, recomendo fortemente "
            "conversar com um psicólogo ou médico psiquiatra para receber o acolhimento profissional adequado."
        )

    def validate_and_sanitize(self, response: str) -> str:
        """
        Analisa a resposta gerada. Se houver alguma violação ética de e-Health,
        bloqueia a mensagem e retorna o aviso de failsafe.
        """
        # Checa se há menção a medicamentos ou atos médicos de prescrição
        if self.meds_regex.search(response):
            logger.warning(f"Resposta sanitizada: Detecção de termos medicamentosos/receitas.")
            return self.failsafe_msg

        # Checa se há emissão de diagnósticos
        if self.diag_regex.search(response):
            logger.warning(f"Resposta sanitizada: Detecção de afirmação diagnóstica.")
            return self.failsafe_msg

        return response
