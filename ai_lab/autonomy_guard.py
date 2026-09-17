#!/usr/bin/env python3
from __future__ import annotations

import datetime as dt
import json
import os
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
STATE = ROOT / "runtime/autonomy_guard.json"

TRUE = {"1", "true", "yes", "on"}


def now_utc() -> dt.datetime:
    return dt.datetime.now(dt.timezone.utc)


def parse_date(value: str) -> dt.datetime | None:
    value = value.strip()
    if not value:
        return None
    try:
        parsed = dt.datetime.fromisoformat(value.replace("Z", "+00:00"))
    except ValueError:
        try:
            parsed = dt.datetime.strptime(value, "%Y-%m-%d")
        except ValueError:
            return None
    if parsed.tzinfo is None:
        parsed = parsed.replace(tzinfo=dt.timezone.utc)
    return parsed.astimezone(dt.timezone.utc)


def main() -> int:
    now = now_utc()
    plus_end = parse_date(os.environ.get("CHATGPT_PLUS_END_UTC", ""))
    free_only = os.environ.get("FREE_TIER_ONLY", "true").lower() in TRUE
    gemini_free_confirmed = os.environ.get("GEMINI_FREE_TIER_CONFIRMED", "false").lower() in TRUE

    reason = ""
    chatgpt_development_allowed = False
    if plus_end is None:
        reason = "No verified ChatGPT Plus end date configured; paid-quality autonomous development fails closed."
    else:
        cutoff = plus_end - dt.timedelta(days=5)
        chatgpt_development_allowed = now < cutoff
        if not chatgpt_development_allowed:
            reason = "Within the five-day pre-expiry safety window; ChatGPT developmental autonomy is disabled."

    # Gemini is allowed only when the owner explicitly confirms the API project
    # remains on Google's Free tier. This repository cannot reliably infer the
    # billing tier from an API key, so ambiguity fails closed.
    basic_gemini_allowed = free_only and gemini_free_confirmed
    if not basic_gemini_allowed:
        reason = reason or "Gemini free-tier status is not explicitly confirmed; autonomous API calls are disabled."

    state = {
        "schema": 1,
        "updated_utc": now.strftime("%Y-%m-%dT%H:%M:%SZ"),
        "free_tier_only": free_only,
        "gemini_free_tier_confirmed": gemini_free_confirmed,
        "basic_gemini_allowed": basic_gemini_allowed,
        "chatgpt_development_allowed": chatgpt_development_allowed,
        "chatgpt_plus_end_utc": plus_end.strftime("%Y-%m-%dT%H:%M:%SZ") if plus_end else "",
        "chatgpt_development_cutoff_utc": (plus_end - dt.timedelta(days=5)).strftime("%Y-%m-%dT%H:%M:%SZ") if plus_end else "",
        "reason": reason,
        "policy": "Fail closed on paid-quality development and any unverified paid API path. Preserve only explicitly confirmed free-tier Gemini capability.",
    }
    STATE.parent.mkdir(parents=True, exist_ok=True)
    STATE.write_text(json.dumps(state, indent=2), encoding="utf-8")
    print(json.dumps(state))
    return 0 if basic_gemini_allowed else 12


if __name__ == "__main__":
    raise SystemExit(main())
