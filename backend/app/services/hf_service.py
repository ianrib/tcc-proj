# backend/app/services/hf_service.py
import json, logging, requests
from typing import Optional
from app.core.config import settings as config

log = logging.getLogger(__name__)

class HFService:
    """Minimal wrapper for Hugging Face Inference API."""
    def __init__(self, token: Optional[str] = None, model: Optional[str] = None):
        self.token = token or config.HF_TOKEN
        self.model = model or config.HF_MODEL
        self.url = f"https://router.huggingface.co/hf-inference/models/{self.model}"
        if not self.token:
            log.warning("HF token not configured – inference disabled.")

    def infer(self, prompt: str) -> str:
        if not self.token:
            raise RuntimeError("HF token missing.")
        headers = {"Authorization": f"Bearer {self.token}"}
        payload = {"inputs": prompt, "parameters": {"max_new_tokens": 256}}
        resp = requests.post(self.url, headers=headers, json=payload, timeout=30)
        if resp.status_code != 200:
            log.error(f"Hugging Face API failed with status {resp.status_code}: {resp.text}")
        resp.raise_for_status()
        data = resp.json()
        if isinstance(data, list) and data and isinstance(data[0], dict):
            return data[0].get("generated_text", "")
        return json.dumps(data)
