from fastapi import APIRouter, File, UploadFile, HTTPException, Depends
from typing import Dict, Any
import logging

from app.services.deepface_service import DeepFaceService
from app.api.v1.chat import get_current_user_id

router = APIRouter()
deepface_service = DeepFaceService()
logger = logging.getLogger(__name__)


@router.post("/detectar-emocao")
async def detectar_emocao(
    file: UploadFile = File(...),
    user_id: str = Depends(get_current_user_id)
) -> Dict[str, Any]:
    """
    Endpoint para detecção e reconhecimento de emoções faciais a partir de imagem.
    
    CONFORMIDADE LGPD (Privacy by Design):
    1. A imagem é enviada como MultipartForm e recebida pelo FastAPI diretamente em memória.
    2. Usamos 'file.read()' para ler os bytes na memória RAM sem salvar no disco (sem diretórios temp).
    3. Os bytes são encaminhados ao Azure Face API / OpenAI Fallback.
    4. Ao concluir, as referências em memória da imagem são excluídas e limpas pelo Garbage Collector.
    5. Nenhuma gravação em arquivos, banco de dados ou logs do arquivo bruto ocorre.
    """
    # Validando se o arquivo enviado é de fato uma imagem
    if not file.content_type or not file.content_type.startswith("image/"):
        raise HTTPException(
            status_code=400,
            detail="Arquivo inválido. Por favor, envie uma imagem nos formatos suportados (JPEG/PNG/WebP)."
        )

    try:
        # REGRA DE PRIVACIDADE: Lendo o buffer na RAM
        image_bytes = await file.read()
        
        if not image_bytes:
            raise HTTPException(status_code=400, detail="O arquivo de imagem enviado está vazio.")
            
        # Invoca o processamento volátil em memória
        resultado = await deepface_service.detect_emotion(image_bytes)

        
        # GARANTIA DE PRIVACIDADE LGPD:
        # Deletamos explicitamente a variável de bytes para forçar liberação do heap do python
        # e evitar retenção prolongada em memória.
        del image_bytes
        
        return resultado

    except ValueError as ve:
        # Exceções como "nenhum rosto detectado" ou "formato inválido"
        logger.warning(f"Erro ao processar imagem para detecção facial: {ve}")
        raise HTTPException(
            status_code=422,
            detail=str(ve)
        )
    except Exception as e:
        # Trata falhas de rede, problemas com a API Azure, etc.
        logger.error(f"Erro na integração com serviço de Visão Computacional: {e}")
        raise HTTPException(
            status_code=502,
            detail=f"Erro de comunicação com o provedor de visão computacional: {str(e)}"
        )
