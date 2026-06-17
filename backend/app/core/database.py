import firebase_admin
from firebase_admin import credentials, firestore
from app.core.config import settings

db = None

def init_firebase():
    """
    Inicializa o Firebase Admin SDK usando o arquivo de credenciais.
    """
    global db
    try:
        # Se as credenciais estiverem configuradas e o arquivo existir
        import os
        if os.path.exists(settings.FIREBASE_CREDENTIALS_PATH):
            cred = credentials.Certificate(settings.FIREBASE_CREDENTIALS_PATH)
            firebase_admin.initialize_app(cred)
            db = firestore.client()
            print("Firebase Admin SDK inicializado com sucesso.")
        else:
            print("Aviso: Arquivo de credenciais Firebase não encontrado. Operando em modo Mock/Desenvolvimento.")
    except Exception as e:
        print(f"Erro ao inicializar Firebase: {e}")

# Para fins de desenvolvimento inicial, caso db seja None, podemos usar mocks
def get_db():
    return db
