import logging
from typing import Optional
from app.core.config import settings

logger = logging.getLogger(__name__)

def verify_firebase_token(token: str) -> Optional[dict]:
    """
    Verifica e decodifica o token JWT enviado pelo Flutter via Firebase Auth.
    Retorna um dict com 'uid' e 'email' se válido, ou None se inválido.
    
    Em modo DEBUG sem credenciais Firebase, permite tokens mock para dev local.
    """
    # Tokens de desenvolvimento local (apenas em modo DEBUG)
    if settings.DEBUG and token in ("mock-token", "user_teste_local"):
        logger.warning("Usando token mock de desenvolvimento — não use em produção.")
        return {"uid": "user_teste_local", "email": "dev@teste.local"}

    try:
        import firebase_admin.auth as fb_auth
        decoded = fb_auth.verify_id_token(token)
        return {
            "uid": decoded.get("uid") or decoded.get("user_id"),
            "email": decoded.get("email", ""),
        }
    except Exception as e:
        logger.warning(f"Falha ao verificar token Firebase: {e}")
        # Em modo DEBUG, aceita o token como UID direto (fallback dev)
        if settings.DEBUG:
            logger.warning("Modo DEBUG ativo: aceitando token como UID sem verificação.")
            return {"uid": token, "email": ""}
        return None
