import logging
import json
from typing import Dict, Any

from app.core.config import settings
from app.services.hf_service import HFService
from openai import OpenAI

log = logging.getLogger(__name__)

class AIProvider:
    """Selects and delegates to the active LLM provider (OpenAI or HuggingFace).
    The provider is chosen based on the AI_PROVIDER env var:
      - "openai"      → force OpenAI (requires OPENAI_API_KEY)
      - "huggingface" → force Hugging Face (requires HF_TOKEN)
      - "auto"        → use OpenAI if key present, else Hugging Face.
    All public methods are async for a unified interface.
    """

    def __init__(self):
        self._provider = None
        self._type = None
        self._openai_client = None
        self._hf_client = None
        self._init_provider()

    def _init_provider(self):
        if settings.OPENAI_API_KEY:
            self._openai_client = OpenAI(api_key=settings.OPENAI_API_KEY)
        if settings.HF_TOKEN:
            self._hf_client = HFService()

        provider = settings.AI_PROVIDER
        if provider == "openai":
            if not self._openai_client:
                raise RuntimeError("AI_PROVIDER set to 'openai' but OPENAI_API_KEY is missing")
            self._type = "openai"
        elif provider == "huggingface":
            if not self._hf_client:
                raise RuntimeError("AI_PROVIDER set to 'huggingface' but HF_TOKEN is missing")
            self._type = "huggingface"
        else:  # auto
            if self._openai_client:
                self._type = "openai"
            elif self._hf_client:
                self._type = "huggingface"
            else:
                raise RuntimeError("No AI credentials available (neither OPENAI_API_KEY nor HF_TOKEN) and AI_PROVIDER='auto'.")

        self._provider = self._openai_client if self._type == "openai" else self._hf_client
        log.info(f"AIProvider initialized. Preferred: {self._type}. OpenAI available: {self._openai_client is not None}. HuggingFace available: {self._hf_client is not None}")

    async def _classify_openai(self, message: str) -> Dict[str, Any]:
        system_prompt = (
            "Você é um classificador especializado em detecção de risco de saúde mental para uma plataforma de apoio complementar.\n"
            "Seu papel é analisar a mensagem do usuário e determinar o nível de risco de crise de acordo com os critérios abaixo:\n"
            "0 - BEM-ESTAR: Mensagem neutra, positiva ou de rotina sem sofrimento emocional.\n"
            "1 - SOFRIMENTO LEVE: Ansiedade moderada, estresse do dia a dia, frustração leve.\n"
            "2 - SOFRIMENTO MODERADO: Tristeza profunda, choro frequente, sensação de desamparo, mas sem ideação suicida.\n"
            "3 - ALTO RISCO: Ideação suicida passiva ('queria sumir', 'seria melhor não acordar'), dor emocional extrema.\n"
            "4 - CRISE AGUDA: Intenção suicida explícita, automutilação ativa, menção a métodos, planos ou imediatismo.\n\n"
            "Responda estritamente em formato JSON válido contendo exatamente três campos: risk_level (int), confidence (float), reason (string curta)."
        )
        response = self._openai_client.chat.completions.create(
            model=settings.OPENAI_MODEL,
            messages=[{"role": "system", "content": system_prompt}, {"role": "user", "content": message}],
            response_format={"type": "json_object"},
            temperature=0.0,
        )
        result = json.loads(response.choices[0].message.content)
        risk = int(result.get("risk_level", 0))
        risk = max(0, min(4, risk))
        return {
            "risk_level": risk,
            "confidence": float(result.get("confidence", 0.8)),
            "reason": str(result.get("reason", "Análise semântica realizada.")),
        }

    async def _classify_hf(self, message: str) -> Dict[str, Any]:
        prompt = (
            "Classifique o risco da seguinte mensagem em JSON com os campos risk_level (0-4), confidence (0-1) e reason.\n"
            f"Mensagem: {message}\n"
        )
        raw = self._hf_client.infer(prompt)
        result = json.loads(raw)
        risk = int(result.get("risk_level", 0))
        risk = max(0, min(4, risk))
        return {
            "risk_level": risk,
            "confidence": float(result.get("confidence", 0.8)),
            "reason": str(result.get("reason", "Classificação via HuggingFace")),
        }

    async def classify_risk(self, message: str) -> Dict[str, Any]:
        """Return a dict with keys: risk_level (int), confidence (float), reason (str)."""
        providers_to_try = []
        if self._type == "openai":
            providers_to_try = ["openai", "huggingface"]
        else:
            providers_to_try = ["huggingface", "openai"]

        errors = []
        for name in providers_to_try:
            try:
                if name == "openai":
                    if not self._openai_client:
                        continue
                    return await self._classify_openai(message)
                elif name == "huggingface":
                    if not self._hf_client:
                        continue
                    return await self._classify_hf(message)
            except Exception as e:
                log.warning(f"AIProvider {name} risk classification failed: {e}. Trying fallback if available.")
                errors.append(f"{name}: {e}")

        return {"risk_level": 1, "confidence": 0.5, "reason": f"Erro em todos os provedores: {'; '.join(errors)}"}

    async def _generate_openai(self, system_prompt: str, user_message: str, history: list) -> str:
        messages = [{"role": "system", "content": system_prompt}]
        for msg in history[-6:]:
            role = "assistant" if msg.get("sender") != "user" else "user"
            messages.append({"role": role, "content": msg.get("content", "")})
        messages.append({"role": "user", "content": user_message})
        resp = self._openai_client.chat.completions.create(
            model=settings.OPENAI_MODEL,
            messages=messages,
            temperature=0.7,
            max_tokens=300,
        )
        return resp.choices[0].message.content.strip()

    async def _generate_hf(self, system_prompt: str, user_message: str, history: list) -> str:
        prompt_parts = [system_prompt]
        for msg in history[-6:]:
            prefix = "Usuário:" if msg.get("sender") == "user" else "Assistente:"
            prompt_parts.append(f"{prefix} {msg.get('content', '')}")
        prompt_parts.append(f"Usuário: {user_message}")
        prompt = "\n".join(prompt_parts)
        return self._hf_client.infer(prompt).strip()

    def _generate_local_fallback(self, user_message: str) -> str:
        import re
        msg_lower = user_message.lower()
        
        # 1. Detecção de fora de escopo (ex: Ferrari, Mustang, carros, esportes, etc.)
        out_of_scope_keywords = ["ferrari", "mustang", "carro", "futebol", "política", "politica", "melhor carro", "melhor que", "quem é melhor", "quem e melhor", "preço de", "preco de", "compara", "vs"]
        if any(keyword in msg_lower for keyword in out_of_scope_keywords):
            return (
                "Como Gaia, sua assistente virtual de apoio emocional, meu foco é oferecer escuta ativa, validação e acolhimento nos momentos difíceis. "
                "Por isso, assuntos como esse estão fora do meu escopo e função como ferramenta de apoio. Como você está se sentindo emocionalmente agora?"
            )

        # 2. Fallback de segurança severo
        suicide_terms = ["matar", "suicid", "tirar minha vida", "fim na minha vida", "enforcar", "fim a tudo", "morrer"]
        if any(term in msg_lower for term in suicide_terms):
            return (
                "Percebo que você está passando por uma dor imensa e difícil de suportar, mas quero que saiba que sua vida tem muito valor "
                "e você não está sozinho. Por favor, converse com alguém próximo ou ligue gratuitamente para o Centro de Valorização "
                "da Vida (CVV) pelo número 188. Eles oferecem apoio emocional confidencial 24 horas por dia."
            )
            
        # 3. Saudações e Apresentações
        name_match = re.search(r"\b(?:me chamo|meu nome é|meu nome e|sou o|sou a)\s+([A-Za-zÀ-ÿ\s]+)", user_message, re.IGNORECASE)
        user_name = None
        if name_match:
            raw_name = name_match.group(1).strip().split()[0]
            user_name = re.sub(r'[^\wÀ-ÿ]', '', raw_name)

        is_greeting = any(greet in msg_lower for greet in ["oi", "olá", "ola", "bom dia", "boa tarde", "boa noite", "como vai", "tudo bem"])
        asks_who_bot_is = any(q in msg_lower for q in ["quem é você", "quem e voce", "como se chama", "qual seu nome", "e você", "e voce"])

        if is_greeting or user_name or asks_who_bot_is:
            if user_name:
                response = f"Olá, {user_name}! Muito prazer. Eu me chamo Gaia, seu assistente virtual de apoio emocional complementar. "
            else:
                response = "Olá! Eu me chamo Gaia, seu assistente virtual de apoio emocional complementar. "
            
            if asks_who_bot_is:
                response += "Meu objetivo é oferecer escuta ativa, validação e acolhimento nos momentos difíceis. "
                
            response += "Como você está se sentindo hoje? Se quiser conversar sobre alguma preocupação ou apenas desabafar, estou aqui para te ouvir."
            return response

        # 4. Estados Emocionais - Ansiedade / Pânico
        if "ansia" in msg_lower or "ansioso" in msg_lower or "ansiosa" in msg_lower or "panic" in msg_lower or "pânico" in msg_lower or "peito apertado" in msg_lower or "respirar" in msg_lower or "respiração" in msg_lower:
            return (
                "Entendo perfeitamente o quanto a ansiedade e a sensação física de aperto podem ser desconfortáveis. "
                "Gostaria de realizar uma prática rápida de respiração consciente comigo agora para ajudar a se acalmar? "
                "Basta iniciar no botão abaixo: action:breathing_exercise"
            )
            
        # 5. Estados Emocionais - Lembretes / Medicamentos / Consultas
        elif any(k in msg_lower for k in ["remedio", "remédio", "medicamento", "consulta", "médico", "medico", "psiquiatra", "lembrar", "tomar", "lembrete"]):
            return (
                "Lidar com nossa saúde requer atenção e rotina. Percebi que mencionou algo que pode precisar de um lembrete. "
                "Para te apoiar, você pode agendar um lembrete direto aqui no aplicativo para receber alertas locais. "
                "Clique para cadastrar: action:create_reminder"
            )

        # 6. Estados Emocionais - Tristeza / Desânimo / Choro
        elif "triste" in msg_lower or "tristeza" in msg_lower or "desespero" in msg_lower or "choro" in msg_lower or "chorando" in msg_lower or "desanimad" in msg_lower:
            return (
                "Lamento muito que você esteja sentindo essa tristeza ou desânimo hoje. É perfeitamente humano passar por fases difíceis "
                "e acolher esses sentimentos faz parte do processo de cura. Não seja tão exigente consigo mesmo hoje. "
                "Se fizer sentido para você, quer me contar um pouco mais sobre o que está te deixando assim?"
            )
            
        # 7. Estados Emocionais - Estresse / Cansaço / Exaustão
        elif "estress" in msg_lower or "cansad" in msg_lower or "esgotad" in msg_lower or "exaust" in msg_lower or "preocupação" in msg_lower or "preocupado" in msg_lower or "preocupada" in msg_lower:
            return (
                "Lidar com o estresse e preocupações excessivas pode ser muito exaustivo. "
                "Gostaria de fazer um exercício rápido para analisarmos juntos esse pensamento e ver se há outras perspectivas?"
            )
            
        # 8. Fallback Geral Empático (Rogeriano)
        else:
            return (
                "Agradeço por compartilhar isso comigo. Entendo que lidar com nossas emoções é uma jornada contínua "
                "e cheia de nuances. Estou aqui para te escutar com toda atenção e acolhimento, sem qualquer julgamento. "
                "Se quiser, fique à vontade para me falar mais sobre o que está vivenciando no momento."
            )

    async def generate_chat(self, system_prompt: str, user_message: str, history: list) -> str:
        """Generate a response for the chat flow.
        `history` is a list of dicts with keys `sender` and `content`.
        """
        providers_to_try = []
        if self._type == "openai":
            providers_to_try = ["openai", "huggingface"]
        else:
            providers_to_try = ["huggingface", "openai"]

        for name in providers_to_try:
            try:
                if name == "openai":
                    if not self._openai_client:
                        continue
                    return await self._generate_openai(system_prompt, user_message, history)
                elif name == "huggingface":
                    if not self._hf_client:
                        continue
                    return await self._generate_hf(system_prompt, user_message, history)
            except Exception as e:
                log.warning(f"AIProvider {name} chat generation failed: {e}. Trying fallback if available.")

        # Fallback local psicoeducativo quando todos os provedores externos falham
        log.warning("Todos os provedores de IA externos falharam. Retornando resposta de fallback local.")
        return self._generate_local_fallback(user_message)
