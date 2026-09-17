#!/usr/bin/env python3
from __future__ import annotations

import datetime as dt
import json
import os
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def enabled() -> bool:
    return os.environ.get("BETA_TESTER_ENABLED", "true").lower() in {"1", "true", "yes", "on"}


def load_json(path: Path, default):
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except Exception:
        return default


def councils_today(limit: int) -> tuple[int, str]:
    today = dt.datetime.now(dt.timezone.utc).strftime("%Y%m%d")
    count = len([p for p in (ROOT / "beta_feedback").glob(f"{today}T*") if p.is_dir()])
    return count, today


def latest_council_time() -> dt.datetime | None:
    times: list[dt.datetime] = []
    for path in (ROOT / "beta_feedback").glob("*"):
        if not path.is_dir():
            continue
        try:
            times.append(dt.datetime.strptime(path.name, "%Y%m%dT%H%M%SZ").replace(tzinfo=dt.timezone.utc))
        except ValueError:
            continue
    return max(times) if times else None


def cadence_hours() -> int:
    state = load_json(ROOT / "runtime" / "development_governance.json", {})
    try:
        value = int(state.get("beta_cadence_hours", 1)) if isinstance(state, dict) else 1
    except (TypeError, ValueError):
        value = 1
    return max(1, min(24, value))


def cadence_due(now: dt.datetime, hours: int) -> bool:
    latest = latest_council_time()
    if latest is None:
        return True
    return now - latest >= dt.timedelta(hours=hours)


def main() -> int:
    if not enabled():
        print("Beta tester council disabled.")
        return 10

    limit = max(1, min(24, int(os.environ.get("BETA_MAX_DAILY_COUNCILS", "24"))))
    count, _ = councils_today(limit)
    hours = cadence_hours()
    print(f"Beta tester councils today: {count}/{limit}; governed cadence: every {hours} hour(s)")
    if count >= limit:
        print("Skip: beta council daily safety cap reached.")
        return 11

    now = dt.datetime.now(dt.timezone.utc)
    if not cadence_due(now, hours):
        print("Skip: milestone governor has slowed the beta cadence; next council is not due yet.")
        return 12

    print("Run: governed full beta council is due.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
