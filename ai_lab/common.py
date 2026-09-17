from __future__ import annotations
import json, os, urllib.request
from typing import Any
API_URL="https://generativelanguage.googleapis.com/v1beta/interactions"
DEFAULT_MODEL="gemini-3.5-flash-lite"

def extract_output_text(payload: dict[str,Any]) -> str:
    for step in reversed(payload.get("steps",[])):
        if step.get("type") == "model_output":
            for c in step.get("content",[]):
                if c.get("type") == "text" and isinstance(c.get("text"),str):
                    return c["text"]
    raise ValueError("Gemini response contained no model text output")

def call_gemini(prompt: str, schema: dict[str,Any], system_instruction: str, model: str|None=None) -> dict[str,Any]:
    key=os.environ.get("GEMINI_API_KEY","").strip()
    if not key: raise RuntimeError("GEMINI_API_KEY is not set")
    body={"model":model or os.environ.get("GEMINI_MODEL",DEFAULT_MODEL),"input":prompt,"system_instruction":system_instruction,"store":False,
          "generation_config":{"max_output_tokens":2200,"temperature":0.45},
          "response_format":{"type":"text","mime_type":"application/json","schema":schema}}
    req=urllib.request.Request(API_URL,data=json.dumps(body).encode(),method="POST",headers={"Content-Type":"application/json","x-goog-api-key":key})
    with urllib.request.urlopen(req,timeout=120) as r: raw=json.loads(r.read().decode())
    return json.loads(extract_output_text(raw))
