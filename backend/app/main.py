from fastapi import FastAPI

from app.climate import router as climate_router

app = FastAPI(
    title="Stone to Stars API",
    description="Earth system trend investigation API",
    version="0.1.0",
)

app.include_router(climate_router)


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