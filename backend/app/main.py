from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from app.core.config import settings
from app.core.database import init_firebase
from app.api.router import api_router

# Inicializar Firebase
init_firebase()

app = FastAPI(
    title="Plataforma de Apoio Psicológico Complementar API",
    description="API de suporte emocional, TCC, mindfulness e detecção de crises.",
    version="1.0.0"
)

# Configurando CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # No ambiente de produção, restringir às origens permitidas
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Registrar rotas
app.include_router(api_router, prefix="/api/v1")

@app.get("/")
def read_root():
    return {
        "status": "online",
        "service": "Apoio Psicológico Complementar API",
        "version": "1.0.0"
    }
