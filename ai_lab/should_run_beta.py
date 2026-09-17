#!/usr/bin/env python3
from __future__ import annotations

import datetime as dt
import json
import os
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUTPUT_PATHS = (
    "beta_feedback/",
    "reports/BETA_COUNCIL_LATEST.md",
    "reports/WORLD_ARCHITECT_LATEST.md",
    "runtime/beta_council.json",
    "runtime/world_map.json",
    "runtime/telemetry_snapshot.json",
)
FALLBACK_HOURS = max(6, min(24, int(os.environ.get("BETA_FALLBACK_HOURS", "12"))))


def enabled() -> bool:
    return os.environ.get("BETA_TESTER_ENABLED", "true").lower() in {"1", "true", "yes", "on"}


def forced() -> bool:
    return os.environ.get("BETA_FORCE_RUN", "false").lower() in {"1", "true", "yes", "on"}


def git(*args: str) -> str:
    try:
        return subprocess.check_output(["git", *args], cwd=ROOT, text=True, stderr=subprocess.DEVNULL).strip()
    except (subprocess.CalledProcessError, FileNotFoundError):
        return ""


def latest_council_commit() -> str:
    return git("log", "-1", "--format=%H", "--grep=^ai: beta council and world architect resolution$")


def latest_council_time() -> dt.datetime | None:
    sha = latest_council_commit()
    if not sha:
        return None
    raw = git("show", "-s", "--format=%cI", sha)
    if not raw:
        return None
    try:
        return dt.datetime.fromisoformat(raw.replace("Z", "+00:00")).astimezone(dt.timezone.utc)
    except ValueError:
        return None


def relevant_code_changed() -> bool:
    sha = latest_council_commit()
    if not sha:
        return True
    changed = git("diff", "--name-only", f"{sha}..HEAD").splitlines()
    for path in changed:
        path = path.strip()
        if not path:
            continue
        if any(path == prefix or path.startswith(prefix) for prefix in OUTPUT_PATHS):
            continue
        # Documentation-only churn should not wake six model agents.
        if path.lower().endswith((".md", ".txt")):
            continue
        return True
    return False


def load_json_text(text: str):
    try:
        return json.loads(text)
    except Exception:
        return None


def normalize_telemetry(value):
    if isinstance(value, dict):
        return {
            k: normalize_telemetry(v)
            for k, v in sorted(value.items())
            if k not in {"generated_at", "synced_at", "updated_at"}
        }
    if isinstance(value, list):
        return [normalize_telemetry(v) for v in value]
    return value


def telemetry_changed() -> bool:
    sha = latest_council_commit()
    current_path = ROOT / "runtime" / "telemetry_snapshot.json"
    if not current_path.exists():
        return False
    current = load_json_text(current_path.read_text(encoding="utf-8"))
    if not sha:
        return bool(current)
    previous_raw = git("show", f"{sha}:runtime/telemetry_snapshot.json")
    previous = load_json_text(previous_raw) if previous_raw else None
    return normalize_telemetry(current) != normalize_telemetry(previous)


def councils_today(limit: int) -> tuple[int, str]:
    today = dt.datetime.now(dt.timezone.utc).strftime("%Y%m%d")
    count = len([p for p in (ROOT / "beta_feedback").glob(f"{today}T*") if p.is_dir()])
    return count, today


def main() -> int:
    if not enabled():
        print("Beta tester council disabled.")
        return 10

    limit = max(1, min(4, int(os.environ.get("BETA_MAX_DAILY_COUNCILS", "2"))))
    count, _ = councils_today(limit)
    print(f"Beta tester councils today: {count}/{limit}")
    if count >= limit and not forced():
        print("Skip: daily free-tier safety cap reached.")
        return 11

    if forced():
        print("Run: manual workflow dispatch override.")
        return 0

    last = latest_council_time()
    if last is None:
        print("Run: no previous council resolution found.")
        return 0

    if relevant_code_changed():
        print("Run: meaningful game/code changes detected since the last council.")
        return 0

    if telemetry_changed():
        print("Run: aggregate real-player telemetry changed since the last council.")
        return 0

    age = dt.datetime.now(dt.timezone.utc) - last
    if age >= dt.timedelta(hours=FALLBACK_HOURS):
        print(f"Run: fallback review interval reached ({FALLBACK_HOURS}h).")
        return 0

    remaining = dt.timedelta(hours=FALLBACK_HOURS) - age
    print(f"Skip: no meaningful change; fallback review due in about {remaining}.")
    return 12


if __name__ == "__main__":
    raise SystemExit(main())
