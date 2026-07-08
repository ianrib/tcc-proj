from fastapi import APIRouter
from app.api.v1 import auth, chat, journal, mood, user, visao

api_router = APIRouter()

api_router.include_router(auth.router, prefix="/auth", tags=["auth"])
api_router.include_router(chat.router, prefix="/chat", tags=["chat"])
api_router.include_router(journal.router, prefix="/journal", tags=["journal"])
api_router.include_router(mood.router, prefix="/mood", tags=["mood"])
api_router.include_router(user.router, prefix="/user", tags=["user"])
api_router.include_router(visao.router, prefix="/visao", tags=["visao"])

