#!/usr/bin/env python3
from __future__ import annotations
import datetime as dt
import os
from pathlib import Path
ROOT = Path(__file__).resolve().parents[1]
if os.environ.get("BETA_TESTER_ENABLED", "true").lower() not in {"1", "true", "yes", "on"}:
    raise SystemExit(10)
limit = max(1, min(4, int(os.environ.get("BETA_MAX_DAILY_COUNCILS", "2"))))
today = dt.datetime.now(dt.timezone.utc).strftime("%Y%m%d")
count = len([p for p in (ROOT / "beta_feedback").glob(f"{today}T*") if p.is_dir()])
print(f"Beta tester councils today: {count}/{limit}")
raise SystemExit(0 if count < limit else 11)
