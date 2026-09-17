#!/usr/bin/env python3
from __future__ import annotations
import json, urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CONFIG = ROOT / 'runtime/public_telemetry.json'


def load_config() -> dict:
    try:
        value = json.loads(CONFIG.read_text(encoding='utf-8'))
        return value if isinstance(value, dict) else {}
    except Exception:
        return {}


def fetch_summary() -> dict:
    cfg = load_config()
    base = str(cfg.get('supabase_url', '')).strip().rstrip('/')
    key = str(cfg.get('supabase_publishable_key', '')).strip()
    if not base or not key or not bool(cfg.get('enabled', False)):
        print('Public telemetry is not configured; preserving existing telemetry snapshot.')
        return {}
    body = json.dumps({'hours_back': 72}).encode('utf-8')
    req = urllib.request.Request(
        base + '/rest/v1/rpc/get_waypoint_telemetry_summary',
        data=body,
        method='POST',
        headers={
            'apikey': key,
            'Content-Type': 'application/json',
            'Accept': 'application/json',
        },
    )
    with urllib.request.urlopen(req, timeout=60) as r:
        value = json.loads(r.read().decode('utf-8'))
    return value if isinstance(value, dict) else {}


def main():
    summary = fetch_summary()
    if not summary:
        return
    snapshot = [{
        'source': 'real_public_playtests_aggregate',
        'window_hours': int(summary.get('window_hours', 72)),
        'sample_events': int(summary.get('events', 0)),
        'unique_sessions': int(summary.get('sessions', 0)),
        'event_counts': summary.get('event_counts', {}),
        'route_activity': summary.get('route_counts', {}),
        'music': summary.get('music', {}),
        'generated_at': summary.get('generated_at', ''),
    }]
    (ROOT / 'runtime').mkdir(exist_ok=True)
    (ROOT / 'runtime/telemetry_snapshot.json').write_text(
        json.dumps(snapshot, indent=2, ensure_ascii=False), encoding='utf-8'
    )
    print(json.dumps(snapshot[0], ensure_ascii=False))


if __name__ == '__main__':
    main()
