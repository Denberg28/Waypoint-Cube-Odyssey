#!/usr/bin/env python3
from __future__ import annotations
import datetime as dt, os
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
if os.environ.get('AI_CYCLE_ENABLED','true').lower() not in {'1','true','yes','on'}:
    raise SystemExit(10)
limit=max(1,min(24,int(os.environ.get('AI_MAX_DAILY_CYCLES','8'))))
today=dt.datetime.now(dt.timezone.utc).strftime('%Y%m%d')
count=len(list((ROOT/'generated_content').glob(f'{today}T*.json')))
print(f'AI cycles today: {count}/{limit}')
raise SystemExit(0 if count < limit else 11)
