#!/usr/bin/env python3
from __future__ import annotations
import json, os, urllib.parse, urllib.request
from collections import Counter, defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

def fetch_events() -> list[dict]:
    base=os.environ.get('SUPABASE_URL','').strip().rstrip('/')
    key=os.environ.get('SUPABASE_SECRET_KEY','').strip()
    if not base or not key:
        print('Supabase backend secrets not configured; preserving existing telemetry snapshot.')
        return []
    query=urllib.parse.urlencode({
        'select':'session_id,received_at,event,mode,class_id,route,stage,row_index,hp,max_hp,coins,bag,gems,details,client_version',
        'order':'received_at.desc','limit':'2000'
    })
    req=urllib.request.Request(base+'/rest/v1/gameplay_events?'+query,headers={'apikey':key,'Accept':'application/json'})
    with urllib.request.urlopen(req,timeout=60) as r:
        return json.loads(r.read().decode('utf-8'))

def summarize(events: list[dict]) -> list[dict]:
    if not events: return []
    counts=Counter(str(x.get('event','')) for x in events)
    routes=Counter(str(x.get('route','')) for x in events if x.get('route'))
    sessions={str(x.get('session_id')) for x in events if x.get('session_id')}
    route_completed=Counter(str(x.get('route','')) for x in events if x.get('event')=='route_complete')
    damage=defaultdict(int); moves=0; jumps=0
    for x in events:
        if x.get('event')=='movement':
            moves += 1
            d=x.get('details') or {}
            if d.get('jump'): jumps += 1
            try: damage[str(x.get('route',''))] += max(0,-int(d.get('hp_delta',0)))
            except Exception: pass
    summary={
        'source':'real_public_playtests','sample_events':len(events),'unique_sessions':len(sessions),
        'event_counts':dict(counts),'route_activity':dict(routes),'route_completions':dict(route_completed),
        'damage_by_route':dict(damage),'movement_actions':moves,'jump_actions':jumps
    }
    recent=[]
    for x in events[:120]:
        recent.append({k:x.get(k) for k in ('received_at','event','mode','class_id','route','stage','row_index','hp','max_hp','coins','bag','gems','details','client_version')})
    return [summary,*recent]

def main():
    events=fetch_events()
    if not events: return
    snapshot=summarize(events)
    (ROOT/'runtime').mkdir(exist_ok=True)
    (ROOT/'runtime/telemetry_snapshot.json').write_text(json.dumps(snapshot,indent=2,ensure_ascii=False),encoding='utf-8')
    print(json.dumps(snapshot[0],ensure_ascii=False))
if __name__=='__main__': main()
