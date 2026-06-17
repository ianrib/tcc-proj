# Verificação de tokens do Firebase Authentication
def verify_firebase_token(token: str):
    """
    Decodifica o token JWT enviado pelo frontend Flutter.
    No ambiente real, utiliza o firebase_admin.auth.verify_id_token(token).
    """
    return {"uid": "mock_uid", "email": "mock@usuario.com"}
