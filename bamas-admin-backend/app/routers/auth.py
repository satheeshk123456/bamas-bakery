from fastapi import APIRouter, HTTPException, status

from ..config import settings
from ..models import LoginRequest, TokenResponse
from ..security import create_access_token, verify_password

router = APIRouter(prefix="/auth", tags=["auth"])


@router.post("/login", response_model=TokenResponse)
def login(body: LoginRequest):
    if body.username != settings.admin_username or not verify_password(
        body.password, settings.admin_password_hash
    ):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Incorrect username or password.",
        )
    token = create_access_token(subject=body.username)
    return TokenResponse(access_token=token)
