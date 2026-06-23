from fastapi import APIRouter, Depends, Header, HTTPException
from pydantic import BaseModel
from typing import Optional, List, Dict, Any
from datetime import datetime
import uuid

from app.core.config import settings
from app.core.database import get_db
from app.services.risk_detector import RiskDetector
from app.services.classifier import IntentionClassifier
from app.services.openai_service import OpenAIService
from app.services.validator import ResponseValidator
from app.services.tcc_flows import TCCFlows
from app.services.mindfulness import MindfulnessFlows
from app.services.conversational import ConversationalManager
from openai import OpenAI

router = APIRouter()

# Inicialização dos serviços (compartilhados ou instanciados sob demanda)
openai_client = None
if settings.OPENAI_API_KEY:
    openai_client = OpenAI(api_key=settings.OPENAI_API_KEY)

risk_detector = RiskDetector(openai_client)
intent_classifier = IntentionClassifier(openai_client)
openai_service = OpenAIService(openai_client)
response_validator = ResponseValidator()
tcc_flows = TCCFlows()
mindfulness_flows = MindfulnessFlows()

conversational_manager = ConversationalManager(
    risk_detector=risk_detector,
    classifier=intent_classifier,
    openai_service=openai_service,
    validator=response_validator,
    tcc_flows=tcc_flows,
    mindfulness_flows=mindfulness_flows
)

# Mock in-memory database para desenvolvimento offline (caso Firestore não esteja configurado)
mock_sessions: Dict[str, Dict[str, Any]] = {}
mock_messages: Dict[str, List[Dict[str, Any]]] = {}
mock_moods: Dict[str, List[int]] = {}

class MessageRequest(BaseModel):
    session_id: str
    content: str

# Dependência simples para obter o ID do usuário (Auth)
def get_current_user_id(authorization: Optional[str] = Header(None)) -> str:
    """
    Dependency para extrair o uid do usuário do token Firebase.
    Se estiver em modo DEBUG e sem cabeçalho, retorna um UID de teste padrão.
    """
    if not authorization:
        if settings.DEBUG:
            return "user_teste_local"
        raise HTTPException(status_code=401, detail="Header de Autorização não fornecido.")
    
    # Exemplo simples de extração Bearer token
    if authorization.startswith("Bearer "):
        token = authorization.split(" ")[1]
        # Em produção: usar firebase_admin.auth.verify_id_token(token)
        # Para fins acadêmicos e dev rápido:
        if token == "mock-token":
            return "user_teste_local"
        return token  # Usando o próprio token/UID direto se mockado
        
    return "user_teste_local"

@router.post("/message")
async def send_message(
    payload: MessageRequest,
    user_id: str = Depends(get_current_user_id)
):
    """
    Recebe mensagem do usuário, processa toda a lógica híbrida de IA,
    salva no Firestore (ou Mock local) e retorna o feedback do assistente.
    """
    db = get_db()
    session_id = payload.session_id
    content = payload.content

    # 1. Carrega dados recentes e histórico
    history: List[Dict[str, Any]] = []
    session_state = {"exercise": None, "step": 1, "data": {}}
    recent_moods: List[int] = []
    recent_risks: List[int] = []

    if db:
        try:
            # Carrega estado da sessão do Firestore
            session_ref = db.collection("chat_sessions").document(session_id)
            session_doc = session_ref.get()
            if session_doc.exists:
                session_state = session_doc.to_dict().get("state", session_state)
            
            # Carrega histórico de mensagens da sessão (últimas 10)
            messages_ref = db.collection("chat_messages")\
                .where("sessionId", "==", session_id)\
                .order_by("timestamp", direction="ASCENDING")\
                .limit(10)
            
            for m_doc in messages_ref.stream():
                m_data = m_doc.to_dict()
                history.append({
                    "sender": m_data.get("sender"),
                    "content": m_data.get("content")
                })
                recent_risks.append(m_data.get("riskLevel", 0))

            # Carrega humores recentes do usuário
            mood_ref = db.collection("mood_entries")\
                .where("userId", "==", user_id)\
                .order_by("timestamp", direction="DESCENDING")\
                .limit(3)
            for m_doc in mood_ref.stream():
                recent_moods.append(m_doc.to_dict().get("score", 5))

        except Exception as e:
            print(f"Erro ao carregar dados do Firestore: {e}. Usando fallback mock.")
            db = None  # Força fallback mock em caso de erro de conexão ou permissão

    # Fallback Mock se Firestore offline ou não configurado
    if not db:
        session_state = mock_sessions.get(session_id, {"exercise": None, "step": 1, "data": {}})
        history = mock_messages.get(session_id, [])
        recent_moods = mock_moods.get(user_id, [5, 6, 7])
        recent_risks = [msg.get("riskLevel", 0) for msg in history[-5:]]

    # 2. Processa a mensagem no ConversationalManager
    response_data, updated_state = await conversational_manager.process_message(
        message=content,
        history=history,
        session_state=session_state,
        recent_mood_scores=recent_moods,
        recent_risk_levels=recent_risks
    )

    # 3. Salva os registros e atualiza o estado
    timestamp_now = datetime.utcnow()
    user_msg_doc = {
        "sessionId": session_id,
        "userId": user_id,
        "sender": "user",
        "content": content,
        "timestamp": timestamp_now,
        "riskLevel": response_data["risk_level"],
        "intent": response_data["intent"]
    }
    
    assistant_msg_doc = {
        "sessionId": session_id,
        "userId": user_id,
        "sender": "assistant",
        "content": response_data["content"],
        "timestamp": timestamp_now,
        "riskLevel": response_data["risk_level"],
        "intent": response_data["intent"],
        "structuredAction": response_data.get("action")
    }

    if db:
        try:
            # Salva mensagens no Firestore
            db.collection("chat_messages").add(user_msg_doc)
            db.collection("chat_messages").add(assistant_msg_doc)
            
            # Atualiza ou cria a sessão no Firestore
            db.collection("chat_sessions").document(session_id).set({
                "userId": user_id,
                "updatedAt": timestamp_now,
                "state": updated_state,
                "lastRiskLevel": response_data["risk_level"]
            }, merge=True)
        except Exception as e:
            print(f"Erro ao salvar dados no Firestore: {e}")
    else:
        # Salva no Mock em memória
        if session_id not in mock_messages:
            mock_messages[session_id] = []
        mock_messages[session_id].append(user_msg_doc)
        mock_messages[session_id].append(assistant_msg_doc)
        mock_sessions[session_id] = updated_state

    # 4. Retorna a resposta final formatada para o aplicativo Flutter
    return {
        "id": str(uuid.uuid4()),
        "sender": "assistant",
        "content": response_data["content"],
        "timestamp": timestamp_now.isoformat(),
        "risk_level": response_data["risk_level"],
        "intent": response_data["intent"],
        "structured_action": response_data.get("action"),
        "emergency_numbers": response_data.get("emergency_numbers")
    }

@router.get("/sessions")
async def get_user_sessions(user_id: str = Depends(get_current_user_id)):
    """
    Retorna a lista de sessões de chat do usuário.
    """
    db = get_db()
    sessions = []

    if db:
        try:
            session_ref = db.collection("chat_sessions")\
                .where("userId", "==", user_id)\
                .order_by("updatedAt", direction="DESCENDING")
            for doc in session_ref.stream():
                s_data = doc.to_dict()
                sessions.append({
                    "id": doc.id,
                    "updatedAt": s_data.get("updatedAt").isoformat() if s_data.get("updatedAt") else None,
                    "lastRiskLevel": s_data.get("lastRiskLevel", 0)
                })
        except Exception as e:
            print(f"Erro ao carregar sessões do Firestore: {e}")
            db = None

    if not db:
        # Fallback Mock
        sessions = [
            {
                "id": s_id,
                "updatedAt": datetime.utcnow().isoformat(),
                "lastRiskLevel": 0
            }
            for s_id in mock_sessions.keys()
        ]
        if not sessions:
            # Adiciona uma sessão padrão de mock se estiver vazio
            sessions = [{"id": "sessao_teste_1", "updatedAt": datetime.utcnow().isoformat(), "lastRiskLevel": 0}]

    return {"sessions": sessions}
