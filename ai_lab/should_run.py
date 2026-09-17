#!/usr/bin/env python3
from __future__ import annotations

import datetime as dt
import json
import os
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def load_json(path: Path, default):
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except Exception:
        return default


def latest_cycle_time() -> dt.datetime | None:
    times: list[dt.datetime] = []
    for path in (ROOT / "generated_content").glob("*.json"):
        try:
            times.append(dt.datetime.strptime(path.stem, "%Y%m%dT%H%M%SZ").replace(tzinfo=dt.timezone.utc))
        except ValueError:
            continue
    return max(times) if times else None


def cadence_hours() -> int:
    state = load_json(ROOT / "runtime" / "development_governance.json", {})
    try:
        value = int(state.get("development_cadence_hours", 3)) if isinstance(state, dict) else 3
    except (TypeError, ValueError):
        value = 3
    return max(1, min(48, value))


def cadence_due(now: dt.datetime, hours: int) -> bool:
    latest = latest_cycle_time()
    if latest is None:
        return True
    return now - latest >= dt.timedelta(hours=hours)


def main() -> int:
    if os.environ.get("AI_CYCLE_ENABLED", "true").lower() not in {"1", "true", "yes", "on"}:
        print("AI development cycle disabled.")
        return 10

    limit = max(1, min(24, int(os.environ.get("AI_MAX_DAILY_CYCLES", "8"))))
    today = dt.datetime.now(dt.timezone.utc).strftime("%Y%m%d")
    count = len(list((ROOT / "generated_content").glob(f"{today}T*.json")))
    hours = cadence_hours()
    print(f"AI cycles today: {count}/{limit}; governed cadence: every {hours} hour(s)")
    if count >= limit:
        print("Skip: AI development daily safety cap reached.")
        return 11

    now = dt.datetime.now(dt.timezone.utc)
    if not cadence_due(now, hours):
        print("Skip: milestone governor has slowed the AI development cadence; next cycle is not due yet.")
        return 12

    print("Run: governed AI development cycle is due.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
