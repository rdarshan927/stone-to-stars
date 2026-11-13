from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.analysis_api import router as analysis_router
from app.climate import router as climate_router

app = FastAPI(
    title="Stone to Stars API",
    description="Earth system trend investigation API",
    version="0.1.0",
)

# Allow Flutter Web running on any localhost/127.0.0.1 port (dev only).
# The regex matches http://localhost, http://localhost:5000,
# http://127.0.0.1:36459, etc. — the dynamic port Flutter Web assigns.
app.add_middleware(
    CORSMiddleware,
    allow_origin_regex=r"^http://(localhost|127\.0\.0\.1)(:\d+)?$",
    allow_methods=["*"],
    allow_headers=["*"],
    allow_credentials=False,
)

app.include_router(climate_router)
app.include_router(analysis_router)


@app.get("/")
async def root():
    return {
        "name": "Stone to Stars",
        "status": "running",
        "version": "0.1.0",
    }


@app.get("/health")
async def health():
    return {"status": "healthy"}