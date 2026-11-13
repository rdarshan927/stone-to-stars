from fastapi import FastAPI

app = FastAPI(
    title="Stone to Stars API",
    description="Earth system trend investigation API",
    version="0.1.0",
)


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