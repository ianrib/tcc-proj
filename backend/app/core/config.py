import os
from pydantic_settings import BaseSettings
from dotenv import load_dotenv

load_dotenv()

class Settings(BaseSettings):
    PROJECT_NAME: str = "TCC Apoio Psicológico Complementar"
    API_V1_STR: str = "/api/v1"
    
    # Configuração do Servidor
    PORT: int = int(os.getenv("PORT", 8000))
    HOST: str = os.getenv("HOST", "0.0.0.0")
    DEBUG: bool = os.getenv("DEBUG", "True").lower() == "true"
    
    # Credenciais do Firebase Admin
    FIREBASE_CREDENTIALS_PATH: str = os.getenv("FIREBASE_CREDENTIALS_PATH", "secret/firebase-service-account.json")
    
    # OpenAI
    OPENAI_API_KEY: str = os.getenv("OPENAI_API_KEY", "")
    OPENAI_MODEL: str = os.getenv("OPENAI_MODEL", "gpt-4o-mini")
    
    # Segurança
    JWT_SECRET_KEY: str = os.getenv("JWT_SECRET_KEY", "super-secret-default-key-change-it")
    ACCESS_TOKEN_EXPIRE_MINUTES: int = int(os.getenv("ACCESS_TOKEN_EXPIRE_MINUTES", 1440))

    class Config:
        case_sensitive = True

settings = Settings()
