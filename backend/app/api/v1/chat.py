from fastapi import APIRouter, Depends, Header, HTTPException
from pydantic import BaseModel
from typing import Optional, List, Dict, Any
from datetime import datetime, timedelta
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
from app.services.ai_provider import AIProvider

ai_provider = AIProvider()

risk_detector = RiskDetector(ai_provider)
intent_classifier = IntentionClassifier()  # fallback to rule‑based classification when no OpenAI key
openai_service = OpenAIService(ai_provider)
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

    title = None
    if db:
        try:
            # Carrega estado da sessão do Firestore
            session_ref = db.collection("chat_sessions").document(session_id)
            session_doc = session_ref.get()
            if session_doc.exists:
                doc_data = session_doc.to_dict()
                session_state = doc_data.get("state", session_state)
                title = doc_data.get("title")
            
            if not title:
                title = content[:35] + ("..." if len(content) > 35 else "")
            
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
        sess_data = mock_sessions.get(session_id)
        if sess_data and isinstance(sess_data, dict) and "state" in sess_data:
            session_state = sess_data["state"]
            title = sess_data.get("title")
        else:
            session_state = {"exercise": None, "step": 1, "data": {}}
            title = content[:35] + ("..." if len(content) > 35 else "")
        
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
                "lastRiskLevel": response_data["risk_level"],
                "title": title
            }, merge=True)
        except Exception as e:
            print(f"Erro ao salvar dados no Firestore: {e}")
    else:
        # Salva no Mock em memória
        if session_id not in mock_messages:
            mock_messages[session_id] = []
        mock_messages[session_id].append(user_msg_doc)
        mock_messages[session_id].append(assistant_msg_doc)
        mock_sessions[session_id] = {
            "userId": user_id,
            "updatedAt": timestamp_now,
            "state": updated_state,
            "lastRiskLevel": response_data["risk_level"],
            "title": title
        }

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

    db = get_db()
    sessions = []
    thirty_days_ago = datetime.utcnow() - timedelta(days=30)

    if db:
        try:
            session_ref = db.collection("chat_sessions")\
                .where("userId", "==", user_id)
            for doc in session_ref.stream():
                s_data = doc.to_dict()
                updated_at = s_data.get("updatedAt")
                if updated_at:
                    # Filtra em memória para evitar a necessidade de índice composto
                    if updated_at >= thirty_days_ago:
                        sessions.append({
                            "id": doc.id,
                            "title": s_data.get("title", "Sessão de Chat"),
                            "updatedAt": updated_at.isoformat(),
                            "lastRiskLevel": s_data.get("lastRiskLevel", 0)
                        })
            # Ordena do mais recente para o mais antigo
            sessions.sort(key=lambda x: x["updatedAt"], reverse=True)
        except Exception as e:
            print(f"Erro ao carregar sessões do Firestore: {e}")
            db = None

    if not db:
        # Fallback Mock com filtro de 30 dias
        for s_id, s_data in mock_sessions.items():
            if s_data.get("userId") == user_id:
                dt = s_data.get("updatedAt", datetime.utcnow())
                if isinstance(dt, str):
                    dt = datetime.fromisoformat(dt)
                if dt >= thirty_days_ago:
                    sessions.append({
                        "id": s_id,
                        "title": s_data.get("title", "Sessão de Chat"),
                        "updatedAt": dt.isoformat(),
                        "lastRiskLevel": s_data.get("lastRiskLevel", 0)
                    })
        sessions.sort(key=lambda x: x["updatedAt"], reverse=True)

        if not sessions:
            sessions = [{"id": "sessao_teste_1", "title": "Sessão de Teste Inicial", "updatedAt": datetime.utcnow().isoformat(), "lastRiskLevel": 0}]

    return {"sessions": sessions}

@router.get("/session/{session_id}/messages")
async def get_session_messages(
    session_id: str,
    user_id: str = Depends(get_current_user_id)
):
    """
    Retorna as mensagens de uma sessão de chat específica.
    """
    db = get_db()
    messages = []

    if db:
        try:
            messages_ref = db.collection("chat_messages")\
                .where("sessionId", "==", session_id)\
                .order_by("timestamp", direction="ASCENDING")
            for doc in messages_ref.stream():
                m_data = doc.to_dict()
                if m_data.get("userId") == user_id:
                    messages.append({
                        "sender": m_data.get("sender"),
                        "content": m_data.get("content"),
                        "riskLevel": m_data.get("riskLevel", 0),
                        "timestamp": m_data.get("timestamp").isoformat() if m_data.get("timestamp") else None
                    })
        except Exception as e:
            print(f"Erro ao carregar mensagens do Firestore: {e}")
            db = None

    if not db:
        # Fallback Mock
        mock_list = mock_messages.get(session_id, [])
        messages = [
            {
                "sender": msg.get("sender"),
                "content": msg.get("content"),
                "riskLevel": msg.get("riskLevel", 0),
                "timestamp": msg.get("timestamp").isoformat() if isinstance(msg.get("timestamp"), datetime) else msg.get("timestamp")
            }
            for msg in mock_list
        ]

    return {"messages": messages}

@router.delete("/session/{session_id}")
async def delete_session(
    session_id: str,
    user_id: str = Depends(get_current_user_id)
):
    """
    Exclui uma sessão de chat e todas as mensagens associadas.
    """
    db = get_db()

    if db:
        try:
            session_ref = db.collection("chat_sessions").document(session_id)
            session_doc = session_ref.get()
            if session_doc.exists and session_doc.to_dict().get("userId") == user_id:
                session_ref.delete()
                
                # Deleta mensagens
                messages_ref = db.collection("chat_messages").where("sessionId", "==", session_id)
                for doc in messages_ref.stream():
                    doc.reference.delete()
        except Exception as e:
            print(f"Erro ao deletar do Firestore: {e}")
            db = None

    if not db:
        if session_id in mock_sessions:
            del mock_sessions[session_id]
        if session_id in mock_messages:
            del mock_messages[session_id]

    return {"status": "success"}
