#!/usr/bin/env python3
from __future__ import annotations
import argparse, json
from pathlib import Path
from ai_lab.common import call_gemini

ROOT = Path(__file__).resolve().parents[1]
CONTEXTS = ["camp", "road", "boss", "fishing", "campfire"]
SCHEMA = {
  "type":"object","additionalProperties":False,
  "properties":{
    "summary":{"type":"string"},
    "contexts":{"type":"object","additionalProperties":False,"properties":{
      c:{"type":"object","additionalProperties":False,"properties":{
        "pitch_scale":{"type":"number"},"volume_delta_db":{"type":"number"}
      },"required":["pitch_scale","volume_delta_db"]} for c in CONTEXTS
    },"required":CONTEXTS},
    "recommendations":{"type":"array","items":{"type":"string"},"maxItems":8}
  },"required":["summary","contexts","recommendations"]
}
SYSTEM = """You are Waypoint's Music Director. Improve the existing original procedural score using only bounded parameter recommendations. Never imitate, quote, or reproduce any copyrighted melody or identifiable song. Do not output notes, lyrics, source code, or audio files. Base recommendations only on supplied aggregate telemetry and current music context behavior. pitch_scale must stay 0.88..1.12 and volume_delta_db -4..4. Prefer subtle changes and explain them briefly."""

def load(path: Path, default):
    try: return json.loads(path.read_text(encoding='utf-8'))
    except Exception: return default

def validate(data: dict) -> dict:
    out={"schema":1,"summary":str(data.get("summary","AI music profile."))[:500],"contexts":{},"recommendations":[]}
    src=data.get("contexts",{}) if isinstance(data.get("contexts"),dict) else {}
    for c in CONTEXTS:
        cfg=src.get(c,{}) if isinstance(src.get(c,{}),dict) else {}
        out["contexts"][c]={
            "pitch_scale":round(max(0.88,min(1.12,float(cfg.get("pitch_scale",1.0)))),3),
            "volume_delta_db":round(max(-4.0,min(4.0,float(cfg.get("volume_delta_db",0.0)))),2)
        }
    out["recommendations"]=[str(x)[:240] for x in data.get("recommendations",[])[:8]] if isinstance(data.get("recommendations"),list) else []
    return out

def main():
    ap=argparse.ArgumentParser(); ap.add_argument('--offline',action='store_true'); args=ap.parse_args()
    telemetry=load(ROOT/'runtime/telemetry_snapshot.json',[])
    current=load(ROOT/'runtime/music_profile.json',{})
    prompt=json.dumps({"aggregate_or_recent_telemetry":telemetry[-200:] if isinstance(telemetry,list) else telemetry,"current_profile":current},ensure_ascii=False)
    if args.offline:
        data={"summary":"Offline neutral validation profile.","contexts":{c:{"pitch_scale":1.0,"volume_delta_db":0.0} for c in CONTEXTS},"recommendations":["Collect more real-player audio telemetry before making larger score changes."]}
    else:
        data=call_gemini(prompt,SCHEMA,SYSTEM)
    out=validate(data)
    (ROOT/'runtime/music_profile.json').write_text(json.dumps(out,indent=2,ensure_ascii=False),encoding='utf-8')
    (ROOT/'reports').mkdir(exist_ok=True)
    lines=["# AI Music Director", "", out['summary'], ""]
    for c,cfg in out['contexts'].items(): lines.append(f"- **{c}** pitch `{cfg['pitch_scale']}` · volume delta `{cfg['volume_delta_db']} dB`")
    if out['recommendations']:
        lines += ["", "## Recommendations"] + [f"- {x}" for x in out['recommendations']]
    (ROOT/'reports/MUSIC_DIRECTOR_LATEST.md').write_text('\n'.join(lines)+'\n',encoding='utf-8')
    print(json.dumps({"ok":True,"contexts":len(out['contexts'])}))
if __name__=='__main__': main()
