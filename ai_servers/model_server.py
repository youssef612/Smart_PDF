"""
Model Server v8 — SmartPDF
يتكلم مع llama.cpp عبر Docker network باسم container: llama:8080
"""

import re
import gc
import asyncio
import os
import uvicorn
import requests as http_requests

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from typing import Optional

# ══════════════════════════════════════════════════════════════
#  الإعدادات
# ══════════════════════════════════════════════════════════════
# داخل Docker network: اسم الـ container مباشرة
LLAMA_BASE_URL = os.getenv("LLAMA_URL", "http://llama:8080")
API_PORT       = int(os.getenv("API_PORT", 8001))
API_HOST       = "0.0.0.0"

TASK_MAX_TOKENS = {
    "summarize": 1500,
    "qa"       : 2000,
    "explain"  : 2000,
    "chat"     : 800,
    "questions": 3000,
    "mindmap"  : 1200,
    "default"  : 1024,
}

# ══════════════════════════════════════════════════════════════
#  Helpers
# ══════════════════════════════════════════════════════════════
def clean_output(text: str) -> str:
    # إزالة أي حروف صينية / يابانية / كورية
    text = re.sub(r"[\u4e00-\u9fff\u3040-\u30ff\uac00-\ud7af]+", "", text)
    # تنظيف المسافات الزائدة
    text = re.sub(r"[^\S\n]+", " ", text)
    # تقليل الأسطر الفارغة الزائدة
    text = re.sub(r"\n{4,}", "\n\n\n", text)
    return text.strip()


def is_repetitive(text: str) -> bool:
    """كشف التكرار المتواصل للكلمات"""
    return bool(re.search(r"(\b\w+\b)(\s+\1){10,}", text, re.IGNORECASE))


# ══════════════════════════════════════════════════════════════
#  Schemas
# ══════════════════════════════════════════════════════════════
class GenerateRequest(BaseModel):
    prompt         : str
    task           : str            = "default"
    temperature    : float          = 0.7
    max_tokens     : Optional[int]  = None
    system_override: Optional[str]  = None


# ══════════════════════════════════════════════════════════════
#  FastAPI
# ══════════════════════════════════════════════════════════════
app = FastAPI(title="SmartPDF Model Server v8")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

# Semaphore: طلب واحد في نفس الوقت عشان LLaMA ما يتحملش أكتر
_semaphore = asyncio.Semaphore(1)


# ──────────────────────────────────────────────────────────────
#  Core generation function (runs in thread pool)
# ──────────────────────────────────────────────────────────────
def _run_generate(req: GenerateRequest) -> dict:
    try:
        max_new = req.max_tokens or TASK_MAX_TOKENS.get(req.task, 1024)

        messages = []
        if req.system_override:
            messages.append({"role": "system", "content": req.system_override})
        messages.append({"role": "user", "content": req.prompt})

        payload = {
            "messages"      : messages,
            "max_tokens"    : max_new,
            "temperature"   : req.temperature,
            "repeat_penalty": 1.15,
            "stop"          : ["<|im_end|>", "<|endoftext|>"],
        }

        resp = http_requests.post(
            f"{LLAMA_BASE_URL}/v1/chat/completions",
            json=payload,
            timeout=300,
        )
        resp.raise_for_status()

        raw    = resp.json()["choices"][0]["message"]["content"]
        result = clean_output(raw)

        if is_repetitive(result):
            return {"success": False, "error": "repetitive_output", "response": ""}

        return {"success": True, "response": result}

    except http_requests.exceptions.ConnectionError:
        return {
            "success" : False,
            "error"   : f"Cannot connect to LLaMA at {LLAMA_BASE_URL} — تأكد إن container 'llama' شغال",
            "response": "",
        }
    except http_requests.exceptions.Timeout:
        return {"success": False, "error": "LLaMA request timed out (>300s)", "response": ""}
    except Exception as e:
        return {"success": False, "error": str(e), "response": ""}
    finally:
        gc.collect()


# ══════════════════════════════════════════════════════════════
#  Endpoints
# ══════════════════════════════════════════════════════════════
@app.get("/")
@app.get("/health")
def health():
    """فحص صحة الـ server والـ LLaMA"""
    llama_status = "unreachable"
    llama_model  = None
    try:
        r = http_requests.get(f"{LLAMA_BASE_URL}/health", timeout=5)
        llama_status = r.json().get("status", "unknown")
    except Exception:
        pass

    # نجرب نجيب اسم الموديل
    try:
        r2 = http_requests.get(f"{LLAMA_BASE_URL}/v1/models", timeout=5)
        models = r2.json().get("data", [])
        if models:
            llama_model = models[0].get("id")
    except Exception:
        pass

    return {
        "status"      : "online",
        "llama_url"   : LLAMA_BASE_URL,
        "llama_server": llama_status,
        "llama_model" : llama_model,
        "queue_locked": _semaphore.locked(),
    }


@app.post("/generate")
async def generate(req: GenerateRequest):
    """توليد نص عبر LLaMA"""
    try:
        async with _semaphore:
            result = await asyncio.wait_for(
                asyncio.get_running_loop().run_in_executor(None, _run_generate, req),
                timeout=310,
            )
        return result
    except asyncio.TimeoutError:
        return {"success": False, "error": "timeout after 310s", "response": ""}
    except Exception as e:
        return {"success": False, "error": str(e), "response": ""}


# ══════════════════════════════════════════════════════════════
#  Entry point
# ══════════════════════════════════════════════════════════════
if __name__ == "__main__":
    print(f"🚀 Starting Model Server on http://{API_HOST}:{API_PORT}")
    print(f"   LLaMA URL: {LLAMA_BASE_URL}")
    print(f"   GET  /health")
    print(f"   POST /generate\n")
    uvicorn.run(app, host=API_HOST, port=API_PORT, log_level="info")
