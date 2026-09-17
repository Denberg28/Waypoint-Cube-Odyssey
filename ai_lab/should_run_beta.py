#!/usr/bin/env python3
from __future__ import annotations

import datetime as dt
import os
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def enabled() -> bool:
    return os.environ.get("BETA_TESTER_ENABLED", "true").lower() in {"1", "true", "yes", "on"}


def councils_today(limit: int) -> tuple[int, str]:
    today = dt.datetime.now(dt.timezone.utc).strftime("%Y%m%d")
    count = len([p for p in (ROOT / "beta_feedback").glob(f"{today}T*") if p.is_dir()])
    return count, today


def main() -> int:
    if not enabled():
        print("Beta tester council disabled.")
        return 10

    # Hourly council: one complete six-agent council per scheduled hour.
    # The 24/day ceiling prevents accidental duplicate/manual loops from running
    # without bound while still allowing every hourly schedule to execute.
    limit = max(1, min(24, int(os.environ.get("BETA_MAX_DAILY_COUNCILS", "24"))))
    count, _ = councils_today(limit)
    print(f"Beta tester councils today: {count}/{limit}")
    if count >= limit:
        print("Skip: hourly council daily safety cap reached.")
        return 11

    print("Run: scheduled hourly full beta council.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
