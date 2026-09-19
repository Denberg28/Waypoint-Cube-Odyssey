from __future__ import annotations
import json
from pathlib import Path

_ROOT = Path(__file__).resolve().parents[1]
_ROUTE_CATALOG = json.loads((_ROOT / "game_data" / "routes.json").read_text(encoding="utf-8"))
ALLOWED_ROUTES = set(_ROUTE_CATALOG)
ALLOWED_TYPES={"world_event","challenge","collectible_rumor","market_special","route_modifier"}
ALLOWED_EXPERIMENTS={"none","market_discount","route_coin_bonus","enemy_pressure","obstacle_pressure"}
WORLD_SCHEMA={
 "type":"object","properties":{
  "headline":{"type":"string"},"summary":{"type":"string"},
  "featured_route":{"type":"string","enum":sorted(ALLOWED_ROUTES)},
  "difficulty_offset":{"type":"integer","minimum":-1,"maximum":1},
  "development_focus":{"type":"object","properties":{"title":{"type":"string"},"reason":{"type":"string"}},"required":["title","reason"]},
  "adopted_feedback_ids":{"type":"array","items":{"type":"string"}},
  "experiment":{"type":"object","properties":{
      "kind":{"type":"string","enum":sorted(ALLOWED_EXPERIMENTS)},
      "route":{"type":"string","enum":sorted(ALLOWED_ROUTES)},
      "value":{"type":"integer","minimum":-10,"maximum":25},
      "reason":{"type":"string"}
    },"required":["kind","route","value","reason"]},
  "challenge":{"type":"object","properties":{"title":{"type":"string"},"description":{"type":"string"},"target":{"type":"integer","minimum":1,"maximum":5}},"required":["title","description","target"]},
  "reward":{"type":"object","properties":{"coins":{"type":"integer","minimum":0,"maximum":25},"gems":{"type":"integer","minimum":0,"maximum":2}},"required":["coins","gems"]},
  "content_pack":{"type":"object","properties":{"kind":{"type":"string","enum":sorted(ALLOWED_TYPES)},"title":{"type":"string"},"description":{"type":"string"},"route":{"type":"string","enum":sorted(ALLOWED_ROUTES)}},"required":["kind","title","description","route"]},
  "development_backlog":{"type":"array","items":{"type":"object","properties":{"priority":{"type":"string","enum":["P1","P2","P3"]},"title":{"type":"string"},"reason":{"type":"string"},"requires_code_change":{"type":"boolean"}},"required":["priority","title","reason","requires_code_change"]}}
 },"required":["headline","summary","featured_route","difficulty_offset","development_focus","adopted_feedback_ids","experiment","challenge","reward","content_pack","development_backlog"]}

def validate_world(data: dict, valid_feedback_ids: set[str] | None = None) -> dict:
    data=dict(data or {})
    if data.get("featured_route") not in ALLOWED_ROUTES: data["featured_route"]="moss"
    data["difficulty_offset"]=max(-1,min(1,int(data.get("difficulty_offset",0))))
    reward=data.setdefault("reward",{})
    reward["coins"]=max(0,min(25,int(reward.get("coins",0))))
    reward["gems"]=max(0,min(2,int(reward.get("gems",0))))
    ch=data.setdefault("challenge",{})
    ch["target"]=max(1,min(5,int(ch.get("target",1))))
    pack=data.setdefault("content_pack",{})
    if pack.get("kind") not in ALLOWED_TYPES: pack["kind"]="world_event"
    if pack.get("route") not in ALLOWED_ROUTES: pack["route"]=data["featured_route"]
    focus=data.setdefault("development_focus",{})
    focus["title"]=str(focus.get("title","Observe player behavior"))[:160]
    focus["reason"]=str(focus.get("reason","Collect more evidence before permanent changes."))[:600]
    exp=data.setdefault("experiment",{})
    if exp.get("kind") not in ALLOWED_EXPERIMENTS: exp["kind"]="none"
    if exp.get("route") not in ALLOWED_ROUTES: exp["route"]=data["featured_route"]
    try: value=int(exp.get("value",0))
    except Exception: value=0
    if exp["kind"]=="none": value=0
    elif exp["kind"]=="market_discount": value=max(0,min(25,value))
    elif exp["kind"]=="route_coin_bonus": value=max(0,min(15,value))
    else: value=max(-10,min(10,value))
    exp["value"]=value
    exp["reason"]=str(exp.get("reason",""))[:600]
    ids=[str(x)[:180] for x in list(data.get("adopted_feedback_ids",[]))[:5]]
    if valid_feedback_ids is not None:
        ids=[x for x in ids if x in valid_feedback_ids]
    data["adopted_feedback_ids"]=ids
    data["development_backlog"]=list(data.get("development_backlog",[]))[:5]
    return data
