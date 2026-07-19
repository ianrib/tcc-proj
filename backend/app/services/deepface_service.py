import logging
from typing import Dict, Any, Tuple
import numpy as np
import cv2

try:
    from deepface import DeepFace
    DEEPFACE_AVAILABLE = True
except ImportError:
    DeepFace = None
    DEEPFACE_AVAILABLE = False
    logging.warning("A biblioteca DeepFace não está instalada. Operando em modo de simulação.")

logger = logging.getLogger(__name__)

class DeepFaceService:
    """
    Serviço local de processamento de Visão Computacional usando DeepFace.
    Garante conformidade com a LGPD e privacidade (Privacy by Design) ao
    processar 100% dos dados em memória e evitar tráfego em nuvens de terceiros.
    """

    def __init__(self):
        if DEEPFACE_AVAILABLE:
            logger.info("Serviço DeepFace inicializado com sucesso.")
        else:
            logger.warning("DeepFace indisponível. Usando simulação para testes locais.")

    async def detect_emotion(self, image_bytes: bytes) -> Dict[str, Any]:
        """
        Detecta e classifica a emoção facial a partir dos bytes de imagem.
        
        REGRA DE PRIVACIDADE E CONFORMIDADE LGPD (Privacy by Design):
        1. A imagem é recebida apenas em memória RAM.
        2. Decodificamos os bytes para um array NumPy e depois em formato de imagem do OpenCV (cv2)
           completamente em memória RAM. NUNCA salvamos a foto em disco ou banco de dados.
        3. A inferência é feita localmente na infraestrutura interna, sem enviar a dados de terceiros.
        4. O objeto NumPy é destruído assim que o método retorna, limpando a memória imediatamente.
        """
        if not image_bytes:
            raise ValueError("Os bytes da imagem estão vazios.")

        # Se o DeepFace não estiver instalado no ambiente local, executa simulação para testes
        if not DEEPFACE_AVAILABLE:
            logger.warning("DeepFace não disponível localmente. Gerando mock simulado.")
            return self._generate_simulated_emotion()

        import asyncio
        return await asyncio.to_thread(self._detect_emotion_sync, image_bytes)

    def _detect_emotion_sync(self, image_bytes: bytes) -> Dict[str, Any]:
        """
        Executa a decodificação da imagem e a inferência de expressão de forma síncrona.
        Feito para rodar em thread em background via asyncio.to_thread.
        """
        try:
            # REGRA DE PRIVACIDADE: Converte bytes diretamente em um array NumPy
            np_arr = np.frombuffer(image_bytes, np.uint8)
            
            # Decodifica o array NumPy em uma matriz de imagem colorida (BGR) do OpenCV
            # Nenhuma escrita de arquivo físico ocorre no HD/SSD do servidor
            img = cv2.imdecode(np_arr, cv2.IMREAD_COLOR)

            if img is None:
                raise ValueError("Não foi possível decodificar os bytes da imagem.")

            # Executa a análise local de expressões faciais do DeepFace
            # Passamos a matriz de imagem do OpenCV (img) diretamente.
            # actions=['emotion'] foca apenas na extração emocional.
            # enforce_detection=True garante a validação clínica de presença de rosto.
            logger.info("Executando inferência local com DeepFace.analyze em thread separada...")
            results = DeepFace.analyze(img_path=img, actions=['emotion'], enforce_detection=True)

            # O DeepFace retorna uma lista nas versões mais recentes. Extraímos a primeira face detectada.
            if isinstance(results, list):
                result = results[0]
            else:
                result = results

            # Extração de resultados
            dominant_key = result.get("dominant_emotion")
            emotion_scores = result.get("emotion", {})
            
            if not dominant_key or not emotion_scores:
                raise ValueError("Nenhum metadado emocional pôde ser extraído do rosto detectado.")

            # Normaliza a confiança para escala de 0.0 a 1.0 (DeepFace retorna de 0 a 100)
            raw_confidence = emotion_scores.get(dominant_key, 0.0)
            confidence = raw_confidence / 100.0 if raw_confidence > 1.0 else raw_confidence

            # Tradução e mapeamento para manter consistência com o frontend Flutter
            dominant_pt, conf = self._map_emotion_data(dominant_key, confidence)

            # Converte os scores de 0-100 do DeepFace para 0.0-1.0
            normalized_scores = {}
            for k, v in emotion_scores.items():
                normalized_scores[k] = v / 100.0 if v > 1.0 else v

            # Retorno estruturado e higienizado
            return {
                "provedor": "DeepFace Local (Open-Source)",
                "emocao_dominante": dominant_pt,
                "confianca": round(conf, 4),
                "scores": normalized_scores
            }

        except Exception as e:
            error_str = str(e)
            logger.warning(f"Falha na inferência local do DeepFace: {error_str}")
            # Se for um erro de detecção de rosto específico do DeepFace
            if "face could not be detected" in error_str.lower() or "face_detect" in error_str.lower():
                raise ValueError("Nenhum rosto detectado na imagem tirada.")
            raise RuntimeError(f"Erro interno no processamento do DeepFace: {error_str}")

    def _map_emotion_data(self, key_en: str, confidence: float) -> Tuple[str, float]:
        """
        Traduz a emoção dominante do inglês para o português.
        """
        translation = {
            "angry": "Raiva",
            "disgust": "Nojo",
            "fear": "Medo",
            "happy": "Felicidade",
            "sad": "Tristeza",
            "surprise": "Surpresa",
            "neutral": "Neutro"
        }
        
        dominant_pt = translation.get(key_en.lower(), key_en.capitalize())
        return dominant_pt, confidence

    def _generate_simulated_emotion(self) -> Dict[str, Any]:
        """
        Mock realista de teste caso o pacote DeepFace ainda esteja compilando ou sem hardware compatível.
        """
        import random
        emotions = ["happy", "neutral", "sad", "surprise", "angry", "fear"]
        chosen = random.choice(emotions)
        
        scores = {e: 0.0 for e in ["angry", "disgust", "fear", "happy", "sad", "surprise", "neutral"]}
        
        confidence = round(random.uniform(0.75, 0.98), 2)
        scores[chosen] = confidence
        
        remaining = 1.0 - confidence
        other_keys = [k for k in scores.keys() if k != chosen]
        for key in other_keys[:-1]:
            val = round(random.uniform(0.0, remaining), 3)
            scores[key] = val
            remaining -= val
        scores[other_keys[-1]] = round(max(0.0, remaining), 3)

        dominant_pt, conf = self._map_emotion_data(chosen, confidence)

        return {
            "provedor": "DeepFace Local (Simulação)",
            "emocao_dominante": dominant_pt,
            "confianca": conf,
            "scores": scores
        }
