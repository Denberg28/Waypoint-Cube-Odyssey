#!/usr/bin/env python3
from __future__ import annotations

import argparse
import datetime as dt
import json
import os
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
STATE = ROOT / "runtime/autonomy_guard.json"
TRUE = {"1", "true", "yes", "on"}
DEFAULT_STOP_THRESHOLD = 3


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


def load_state() -> dict:
    try:
        value = json.loads(STATE.read_text(encoding="utf-8"))
        return value if isinstance(value, dict) else {}
    except Exception:
        return {}


def save_state(state: dict) -> None:
    STATE.parent.mkdir(parents=True, exist_ok=True)
    STATE.write_text(json.dumps(state, indent=2), encoding="utf-8")


def base_state() -> dict:
    return {
        "schema": 2,
        "failure_streak": 0,
        "latched_stop": False,
        "latched_stop_utc": "",
        "latched_reason": "",
        "manual_resume_required": False,
        "last_success_utc": "",
        "last_failure_utc": "",
        "last_failure_reason": "",
    }


def environment_policy(state: dict, now: dt.datetime) -> dict:
    plus_end = parse_date(os.environ.get("CHATGPT_PLUS_END_UTC", ""))
    free_only = os.environ.get("FREE_TIER_ONLY", "true").lower() in TRUE
    gemini_free_confirmed = os.environ.get("GEMINI_FREE_TIER_CONFIRMED", "false").lower() in TRUE
    threshold = max(1, int(os.environ.get("AUTONOMY_STOP_THRESHOLD", str(DEFAULT_STOP_THRESHOLD))))

    reason = ""
    chatgpt_development_allowed = False
    if plus_end is None:
        reason = "No verified ChatGPT Plus end date configured; paid-quality autonomous development fails closed."
    else:
        cutoff = plus_end - dt.timedelta(days=5)
        chatgpt_development_allowed = now < cutoff
        if not chatgpt_development_allowed:
            reason = "Within the five-day pre-expiry safety window; ChatGPT developmental autonomy is disabled."

    basic_gemini_allowed = free_only and gemini_free_confirmed
    if not basic_gemini_allowed:
        reason = reason or "Gemini free-tier status is not explicitly confirmed; autonomous API calls are disabled."

    if state.get("latched_stop"):
        chatgpt_development_allowed = False
        basic_gemini_allowed = False
        reason = state.get("latched_reason") or "Autonomy circuit breaker is latched; manual resume is required."

    state.update({
        "schema": 2,
        "updated_utc": now.strftime("%Y-%m-%dT%H:%M:%SZ"),
        "free_tier_only": free_only,
        "gemini_free_tier_confirmed": gemini_free_confirmed,
        "basic_gemini_allowed": basic_gemini_allowed,
        "chatgpt_development_allowed": chatgpt_development_allowed,
        "chatgpt_plus_end_utc": plus_end.strftime("%Y-%m-%dT%H:%M:%SZ") if plus_end else "",
        "chatgpt_development_cutoff_utc": (plus_end - dt.timedelta(days=5)).strftime("%Y-%m-%dT%H:%M:%SZ") if plus_end else "",
        "stop_threshold": threshold,
        "reason": reason,
        "policy": "After repeated autonomous request failures, latch all model autonomy off until explicit manual resume. Never auto-resume after quota, subscription, credential, provider, or billing failures.",
    })
    return state


def record_failure(state: dict, reason: str, now: dt.datetime) -> dict:
    threshold = max(1, int(state.get("stop_threshold", DEFAULT_STOP_THRESHOLD)))
    state["failure_streak"] = int(state.get("failure_streak", 0)) + 1
    state["last_failure_utc"] = now.strftime("%Y-%m-%dT%H:%M:%SZ")
    state["last_failure_reason"] = reason[:500]
    if state["failure_streak"] >= threshold:
        state["latched_stop"] = True
        state["latched_stop_utc"] = now.strftime("%Y-%m-%dT%H:%M:%SZ")
        state["latched_reason"] = f"Circuit breaker tripped after {state['failure_streak']} consecutive autonomous request failures: {reason[:300]}"
        state["manual_resume_required"] = True
        state["basic_gemini_allowed"] = False
        state["chatgpt_development_allowed"] = False
    return state


def record_success(state: dict, now: dt.datetime) -> dict:
    # A success clears only the pre-trip streak. Once latched, only --resume may reset it.
    if not state.get("latched_stop"):
        state["failure_streak"] = 0
        state["last_success_utc"] = now.strftime("%Y-%m-%dT%H:%M:%SZ")
        state["last_failure_reason"] = ""
    return state


def resume(state: dict, now: dt.datetime) -> dict:
    state.update({
        "failure_streak": 0,
        "latched_stop": False,
        "latched_stop_utc": "",
        "latched_reason": "",
        "manual_resume_required": False,
        "last_failure_reason": "",
        "last_success_utc": now.strftime("%Y-%m-%dT%H:%M:%SZ"),
    })
    return environment_policy(state, now)


def main() -> int:
    parser = argparse.ArgumentParser()
    group = parser.add_mutually_exclusive_group()
    group.add_argument("--failure", metavar="REASON")
    group.add_argument("--success", action="store_true")
    group.add_argument("--resume", action="store_true")
    args = parser.parse_args()

    now = now_utc()
    state = base_state()
    state.update(load_state())
    state = environment_policy(state, now)

    if args.resume:
        state = resume(state, now)
    elif args.failure:
        state = record_failure(state, args.failure, now)
        state = environment_policy(state, now)
    elif args.success:
        state = record_success(state, now)
        state = environment_policy(state, now)

    save_state(state)
    print(json.dumps(state))
    return 0 if state.get("basic_gemini_allowed") else 12


if __name__ == "__main__":
    raise SystemExit(main())
