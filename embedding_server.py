import os
import torch
import torch.nn.functional as F
from fastapi import FastAPI, HTTPException, Security
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from pydantic import BaseModel
from transformers import AutoTokenizer, AutoModel

MODEL_ID = os.environ.get("MODEL_ID", "Qwen/Qwen3-Embedding-4B")
API_KEY = os.environ.get("API_KEY", "")
HF_TOKEN = os.environ.get("HF_TOKEN") or os.environ.get("HUGGING_FACE_HUB_TOKEN")

app = FastAPI()
security = HTTPBearer(auto_error=False)

print(f"Loading {MODEL_ID} on CPU...")
tokenizer = AutoTokenizer.from_pretrained(MODEL_ID, trust_remote_code=True, token=HF_TOKEN)
model = AutoModel.from_pretrained(
    MODEL_ID, trust_remote_code=True, torch_dtype=torch.float32, token=HF_TOKEN
)
model.eval()
print("Ready.")


def _pool(last_hidden: torch.Tensor, mask: torch.Tensor) -> torch.Tensor:
    # last-token pooling (correct for Qwen3-Embedding decoder models)
    left_pad = mask[:, -1].sum() == mask.shape[0]
    if left_pad:
        return last_hidden[:, -1]
    seq_lens = mask.sum(dim=1) - 1
    return last_hidden[torch.arange(mask.shape[0]), seq_lens]


class EmbedRequest(BaseModel):
    input: str | list[str]
    model: str = ""
    dimensions: int | None = None  # MRL truncation; None = full 2560-dim


@app.get("/health")
def health():
    return {"status": "ok"}


@app.post("/v1/embeddings")
def embeddings(
    req: EmbedRequest,
    credentials: HTTPAuthorizationCredentials = Security(security),
):
    if API_KEY and (not credentials or credentials.credentials != API_KEY):
        raise HTTPException(status_code=401, detail="Unauthorized")
    texts = req.input if isinstance(req.input, list) else [req.input]
    enc = tokenizer(texts, padding=True, truncation=True, max_length=8192, return_tensors="pt")
    with torch.no_grad():
        out = model(**enc)
    vecs = F.normalize(_pool(out.last_hidden_state, enc["attention_mask"]), p=2, dim=1)
    if req.dimensions and req.dimensions < vecs.shape[1]:
        vecs = F.normalize(vecs[:, : req.dimensions], p=2, dim=1)
    vecs = vecs.tolist()
    return {
        "object": "list",
        "data": [{"object": "embedding", "index": i, "embedding": v} for i, v in enumerate(vecs)],
        "model": MODEL_ID,
        "usage": {"prompt_tokens": 0, "total_tokens": 0},
    }
