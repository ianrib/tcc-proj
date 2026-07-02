import re
import json
import logging
from typing import List, Dict, Any, Optional
from app.services.ai_provider import AIProvider
from app.core.config import settings

logger = logging.getLogger(__name__)

class RiskDetector:
    """
    Detector de Risco em 3 Camadas para suporte emocional complementar.
    """
    def __init__(self, ai_provider: Optional[AIProvider] = None):
        self.provider = ai_provider
        
        # Expressões regulares para detecção imediata de termos graves (Camada 1)
        self.critical_regex_level_4 = re.compile(
            r"\b(me matar|suicidio|suicídio|tirar minha vida|dar um fim na minha vida|me cortar|auto mutilar|automutilar|me enforcar|planejando morrer|tomar todos os remedios|vou acabar com tudo hoje|vou fazer isso hoje)\b",
            re.IGNORECASE
        )
        
        self.critical_regex_level_3 = re.compile(
            r"\b(queria desaparecer|melhor nao acordar|queria nao existir|dor insuportavel|nao aguento mais viver|queria dormir e nao acordar|desespero total|vontade de sumir)\b",
            re.IGNORECASE
        )

    def _check_camada_1_rules(self, message: str) -> Optional[Dict[str, Any]]:
        """
        Camada 1: Validação determinística rápida baseada em palavras-chave críticas.
        """
        # Checa termos de Nível 4 (Imediato / Plano / Ação)
        if self.critical_regex_level_4.search(message):
            return {
                "risk_level": 4,
                "confidence": 1.0,
                "reason": "Termos críticos de auto-extermínio ou automutilação imediata detectados na mensagem."
            }
            
        # Checa termos de Nível 3 (Sofrimento Severo / Ideação passiva)
        if self.critical_regex_level_3.search(message):
            return {
                "risk_level": 3,
                "confidence": 0.9,
                "reason": "Termos de ideação passiva ou sofrimento psíquico grave detectados."
            }
            
        return None

    async def _check_camada_2_llm(self, message: str) -> Dict[str, Any]:
        """
        Camada 2: Classificação semântica via OpenAI GPT-4o-mini com retorno estruturado.
        """
        if not self.provider or not getattr(self.provider, "_provider", None):
            # Fallback seguro caso não haja provedor de IA
            logger.warning("Provedor de IA não disponível no RiskDetector. Analisando apenas por palavras-chave locais.")
            return {
                "risk_level": 0,
                "confidence": 0.5,
                "reason": "Fallback local: Nenhuma palavra-chave de risco crítica detectada."
            }

        # Camada 2 – delega ao AIProvider
        result = await self.provider.classify_risk(message)
        return result

    def _apply_camada_3_history(
        self,
        current_risk: int,
        recent_mood_scores: List[int],
        recent_risk_levels: List[int]
    ) -> int:
        """
        Camada 3: Ajuste baseado no histórico de humor recente e conversações anteriores.
        Bumpeia o risco se houver um padrão de vulnerabilidade crítica prolongada.
        """
        # Se já estiver no nível de crise máxima (4), não precisamos ajustar
        if current_risk >= 4:
            return current_risk

        # Se houver histórico de humor recente e a média for menor que 3.0 (sofrimento moderado/severo)
        avg_mood = sum(recent_mood_scores) / len(recent_mood_scores) if recent_mood_scores else 10.0
        
        # Se o usuário esteve frequentemente em sofrimento moderado ou alto risco nas últimas conversas
        severe_past_risk = sum(1 for r in recent_risk_levels if r >= 2)
        
        # Ajustes de mitigação preventiva
        if current_risk < 3:
            # Caso a média de humor recente seja alarmante ou haja múltiplos riscos passados, promovemos em +1
            if avg_mood <= 3.0 or severe_past_risk >= 2:
                logger.info(f"Camada 3 ativada: Risco ajustado de {current_risk} para {current_risk + 1} devido ao histórico emocional.")
                return current_risk + 1

        return current_risk

    async def detect_risk(
        self,
        message: str,
        recent_mood_scores: Optional[List[int]] = None,
        recent_risk_levels: Optional[List[int]] = None
    ) -> Dict[str, Any]:
        """
        Executa a detecção de risco nas 3 camadas integradas.
        """
        # 1. Executa a Camada 1 (Regras determinísticas de segurança rápida)
        camada1_res = self._check_camada_1_rules(message)
        if camada1_res:
            logger.info(f"Risco detectado na Camada 1: Nível {camada1_res['risk_level']}")
            return camada1_res

        # 2. Executa a Camada 2 (Classificação semântica baseada em LLM)
        camada2_res = await self._check_camada_2_llm(message)
        
        # 3. Executa a Camada 3 (Ajuste por histórico emocional)
        original_risk = camada2_res["risk_level"]
        adjusted_risk = self._apply_camada_3_history(
            current_risk=original_risk,
            recent_mood_scores=recent_mood_scores or [],
            recent_risk_levels=recent_risk_levels or []
        )
        
        if adjusted_risk != original_risk:
            camada2_res["risk_level"] = adjusted_risk
            camada2_res["reason"] += " (Ajustado com base no histórico recente)."

        return camada2_res
