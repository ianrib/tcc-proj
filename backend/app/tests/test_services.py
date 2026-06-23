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
