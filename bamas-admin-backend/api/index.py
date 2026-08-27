# Vercel's Python runtime looks for a serverless entry point under /api.
# This just re-exports the real FastAPI app from app/main.py so nothing
# about the app's own code has to change to be deployable on Vercel.
from app.main import app  # noqa: F401
