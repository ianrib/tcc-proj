import pytest
from app.services.risk_detector import RiskDetector
from app.services.validator import ResponseValidator
from app.services.tcc_flows import TCCFlows
from app.services.mindfulness import MindfulnessFlows

import asyncio

def test_risk_detector_layer_1_crisis():
    detector = RiskDetector()
    
    # Teste de crise imediata (Nível 4)
    res_4 = asyncio.run(detector.detect_risk("eu decidi me matar hoje à noite"))
    assert res_4["risk_level"] == 4
    assert "auto-extermínio" in res_4["reason"]

    # Teste de ideação passiva (Nível 3)
    res_3 = asyncio.run(detector.detect_risk("queria desaparecer e nunca mais acordar"))
    assert res_3["risk_level"] == 3
    assert "ideação passiva" in res_3["reason"]

    # Teste de mensagem neutra (Nível 0)
    res_0 = asyncio.run(detector.detect_risk("olá, tudo bem com você?"))
    assert res_0["risk_level"] == 0

def test_response_validator_meds():
    validator = ResponseValidator()
    
    # Teste de resposta limpa
    clean_msg = "Eu entendo que é difícil. Que tal respirarmos juntos?"
    assert validator.validate_and_sanitize(clean_msg) == clean_msg

    # Teste com indicação de medicamento restrito
    meds_msg = "Recomendo tomar Fluoxetina 20mg para aliviar."
    sanitized = validator.validate_and_sanitize(meds_msg)
    assert sanitized != meds_msg
    assert "como um assistente virtual complementar" in sanitized
    assert "não posso fornecer diagnósticos" in sanitized

def test_response_validator_diagnosis():
    validator = ResponseValidator()
    
    # Teste com emissão de diagnóstico clínico
    diag_msg = "Seus sintomas indicam que você tem depressão maior grave."
    sanitized = validator.validate_and_sanitize(diag_msg)
    assert sanitized != diag_msg
    assert "não posso fornecer diagnósticos" in sanitized

def test_tcc_socratic_flow_progression():
    tcc = TCCFlows()
    
    # Inicia estado padrão
    state = {"exercise": "questionamento_socratico", "step": 1, "data": {}}
    
    # Passo 1
    response, next_state, completed = tcc.process_socratic_step(state, "Acho que vou falhar no meu TCC")
    assert next_state["step"] == 2
    assert next_state["data"]["pensamento_original"] == "Acho que vou falhar no meu TCC"
    assert "evidências reais" in response
    assert not completed

def test_mindfulness_grounding_flow_progression():
    mind = MindfulnessFlows()
    
    # Inicia estado padrão
    state = {"exercise": "grounding_54321", "step": 1, "data": {}}
    
    # Passo 1
    response, next_state, completed = mind.process_grounding_step(state, "Vejo o celular, mesa, copo, caneta e monitor")
    assert next_state["step"] == 2
    assert next_state["data"]["visao_5_itens"] == "Vejo o celular, mesa, copo, caneta e monitor"
    assert "tocar ou sentir" in response
    assert not completed

def test_slang_normalization():
    from app.services.conversational import ConversationalManager
    manager = ConversationalManager(None, None, None, None, None, None)
    
    assert manager._normalize_input("tô mto triste hj") == "estou muito triste hj"
    assert manager._normalize_input("gnt vc tá c/ vtd de sumir?") == "gente você está com vontade de sumir?"
    assert manager._normalize_input("pq suicdio ou autoexterminio") == "porque suicídio ou auto-extermínio"

def test_risk_detector_crisis_interception_regex():
    detector = RiskDetector()
    
    res = asyncio.run(detector.detect_risk("eu quero me matar"))
    assert res["risk_level"] == 4
    
    res_l3 = asyncio.run(detector.detect_risk("estou com vontade de sumir"))
    assert res_l3["risk_level"] == 3

@pytest.mark.anyio
async def test_conversational_manager_risk_level_3_goes_to_ai():
    from unittest.mock import AsyncMock, MagicMock
    from app.services.conversational import ConversationalManager
    
    # Setup mocks
    risk_detector = MagicMock()
    classifier = AsyncMock()
    classifier.classify.return_value = "conversa_emocional"
    
    openai_service = AsyncMock()
    openai_service.generate_response.return_value = {
        "content": "Estou aqui ouvindo você.",
        "suggestions": []
    }
    
    validator = MagicMock()
    validator.validate_and_sanitize.side_effect = lambda x: x
    
    tcc_flows = MagicMock()
    mindfulness_flows = MagicMock()
    
    manager = ConversationalManager(
        risk_detector=risk_detector,
        classifier=classifier,
        openai_service=openai_service,
        validator=validator,
        tcc_flows=tcc_flows,
        mindfulness_flows=mindfulness_flows
    )
    
    # Process message with pre-defined risk level 3
    response, session_state = await manager.process_message(
        message="Estou me sentindo muito mal, desespero total",
        history=[],
        session_state={"exercise": None, "step": 1, "data": {}},
        recent_mood_scores=[],
        recent_risk_levels=[],
        risk_level=3
    )
    
    # Check that openai_service was called (went to AI processing)
    openai_service.generate_response.assert_called_once()
    
    # Check response fields
    assert response["risk_level"] == 3
    assert response["content"] == "Estou aqui ouvindo você."
    assert response["intent"] == "conversa_emocional"

@pytest.mark.anyio
async def test_ai_provider_fallback_openai_to_hf():
    from app.services.ai_provider import AIProvider
    from unittest.mock import AsyncMock, MagicMock
    
    provider = AIProvider.__new__(AIProvider)
    provider._type = "openai"
    
    # Mock methods representing OpenAI and HF generation
    provider._openai_client = AsyncMock()
    provider._hf_client = MagicMock()
    
    provider._generate_openai = AsyncMock(side_effect=Exception("OpenAI Error (Timeout/5xx/Cota)"))
    provider._generate_hf = AsyncMock(return_value="Response from HuggingFace")
    provider._generate_local_fallback = MagicMock()
    
    res = await provider.generate_chat("System prompt", "User message", [])
    
    # OpenAI is tried first, fails, then HuggingFace is tried
    provider._generate_openai.assert_called_once()
    provider._generate_hf.assert_called_once()
    assert res == "Response from HuggingFace"

def test_send_message_endpoint_crisis_interception_level_4():
    from fastapi.testclient import TestClient
    from app.main import app
    from app.api.v1.chat import get_current_user_id
    
    # Override authentication dependency
    app.dependency_overrides[get_current_user_id] = lambda: "test_user_id"
    
    client = TestClient(app)
    
    payload = {
        "session_id": "test_session_123",
        "content": "eu decidi me matar hoje à noite"
    }
    
    response = client.post("/api/v1/chat/message", json=payload)
    assert response.status_code == 200
    data = response.json()
    
    assert data["risk_level"] == 4
    assert data["intent"] == "crise"
    assert data["structured_action"] == "show_emergency_screen"
    assert "SAMU" in data["emergency_numbers"]
    assert "CVV" in data["emergency_numbers"]
    assert "Detectamos que você pode estar passando por um momento de sofrimento extremo" in data["content"]
    
    # Cleanup dependency overrides
    app.dependency_overrides.clear()
