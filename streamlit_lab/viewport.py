from __future__ import annotations

import json
from typing import Any


THEMES: dict[str, dict[str, str]] = {
    "moss": {"sky": "#91c7d8", "ground": "#4f7d4f", "road": "#8c7358", "edge": "#5d4a36"},
    "forge": {"sky": "#71555a", "ground": "#4d3b37", "road": "#6e5547", "edge": "#322723"},
    "shrine": {"sky": "#778ab0", "ground": "#59697f", "road": "#8d837b", "edge": "#514d53"},
    "treasure": {"sky": "#d8b36d", "ground": "#8a7041", "road": "#a08258", "edge": "#5e4932"},
    "frost": {"sky": "#bfd7ea", "ground": "#d6e5ee", "road": "#a9bac4", "edge": "#728692"},
    "fen": {"sky": "#758b80", "ground": "#496358", "road": "#6e6656", "edge": "#3b443e"},
}


def _safe_payload(state: dict[str, Any], world: dict[str, Any], routes: dict[str, Any]) -> str:
    route_id = state.get("route")
    info = routes.get(route_id, {}) if route_id else {}
    payload = {
        "route": route_id,
        "route_name": info.get("name", "Lantern Camp"),
        "step": int(state.get("step", 0)),
        "distance": max(1, int(state.get("distance", 12))),
        "hp": int(state.get("hp", 0)),
        "max_hp": max(1, int(state.get("max_hp", 100))),
        "coins": int(state.get("coins", 0)),
        "message": str(state.get("message", ""))[:180],
        "encounter": state.get("encounter") if isinstance(state.get("encounter"), dict) else None,
        "featured_route": world.get("featured_route"),
        "routes": [
            {"id": rid, "name": str(item.get("name", rid)), "difficulty": int(item.get("difficulty", 0))}
            for rid, item in routes.items()
        ],
    }
    return json.dumps(payload, ensure_ascii=False).replace("</", "<\\/")


def viewport_html(state: dict[str, Any], world: dict[str, Any], routes: dict[str, Any]) -> str:
    route_id = state.get("route") or "moss"
    theme = THEMES.get(route_id, THEMES["moss"])
    payload = _safe_payload(state, world, routes)
    return f"""
<!doctype html>
<html>
<head>
<meta charset="utf-8" />
<style>
  * {{ box-sizing: border-box; }}
  body {{ margin: 0; background: transparent; font-family: Inter, system-ui, sans-serif; }}
  .frame {{
    position: relative; overflow: hidden; border-radius: 18px; border: 1px solid rgba(255,255,255,.16);
    background: #17202a; box-shadow: 0 12px 34px rgba(0,0,0,.28);
  }}
  canvas {{ display:block; width:100%; height:auto; aspect-ratio: 16 / 8.5; }}
  .hud {{ position:absolute; inset: 12px 14px auto 14px; display:flex; justify-content:space-between; gap:10px; pointer-events:none; }}
  .pill {{ background:rgba(11,18,24,.76); border:1px solid rgba(255,255,255,.14); border-radius:999px; padding:7px 11px; color:#fff; font-size:12px; backdrop-filter:blur(7px); }}
  .message {{ position:absolute; left:50%; bottom:12px; transform:translateX(-50%); width:min(76%,760px); text-align:center; color:#fff; background:rgba(11,18,24,.78); border:1px solid rgba(255,255,255,.14); border-radius:12px; padding:8px 12px; font-size:12px; pointer-events:none; }}
  .tag {{ color:#d9f1ff; opacity:.9; }}
</style>
</head>
<body>
<div class="frame">
  <canvas id="game" width="960" height="510"></canvas>
  <div class="hud"><div class="pill" id="leftHud"></div><div class="pill" id="rightHud"></div></div>
  <div class="message" id="msg"></div>
</div>
<script>
const S = {payload};
const C = document.getElementById('game');
const X = C.getContext('2d');
const W = C.width, H = C.height;
const palette = {json.dumps(theme)};
let t = 0;

document.getElementById('leftHud').innerHTML = `<b>${{S.route_name}}</b> · ${{S.route ? `Trail ${{S.step}}/${{S.distance}}` : 'Crossroads'}}`;
document.getElementById('rightHud').innerHTML = `❤ ${{S.hp}}/${{S.max_hp}} &nbsp; · &nbsp; 🪙 ${{S.coins}}`;
document.getElementById('msg').textContent = S.message || 'Choose a route.';

function lerp(a,b,p) {{ return a + (b-a)*p; }}
function poly(points, fill, stroke=null) {{
  X.beginPath(); X.moveTo(points[0][0],points[0][1]);
  for (let i=1;i<points.length;i++) X.lineTo(points[i][0],points[i][1]);
  X.closePath(); X.fillStyle=fill; X.fill();
  if(stroke) {{ X.strokeStyle=stroke; X.lineWidth=2; X.stroke(); }}
}}
function rounded(x,y,w,h,r,fill) {{
  X.beginPath(); X.roundRect(x,y,w,h,r); X.fillStyle=fill; X.fill();
}}
function drawBackground() {{
  const g=X.createLinearGradient(0,0,0,H*0.62); g.addColorStop(0,palette.sky); g.addColorStop(1,'#d9e4df');
  X.fillStyle=g; X.fillRect(0,0,W,H);
  X.fillStyle=palette.ground; X.fillRect(0,H*0.46,W,H*0.54);
  for(let i=0;i<14;i++) {{
    const x=(i*79+37)%W, base=H*0.47 + (i%3)*4;
    X.fillStyle='rgba(20,40,32,.32)';
    X.beginPath(); X.moveTo(x-22,base); X.lineTo(x,base-54-(i%4)*8); X.lineTo(x+22,base); X.fill();
  }}
  X.fillStyle='rgba(255,255,255,.16)';
  for(let i=0;i<5;i++) X.fillRect((i*211 + (t*8)%1100)-120, 64+i*18, 96, 10);
}}
function roadX(y, side) {{
  const p=(y-H*0.30)/(H*0.70); const half=lerp(52,W*0.34,Math.max(0,Math.min(1,p)));
  return W/2 + side*half;
}}
function drawRoad() {{
  poly([[roadX(H*.31,-1),H*.31],[roadX(H*.31,1),H*.31],[roadX(H,1),H],[roadX(H,-1),H]], palette.road, palette.edge);
  const rows=9;
  for(let i=0;i<rows;i++) {{
    const p0=i/rows, p1=(i+1)/rows;
    const y0=lerp(H*.34,H*.96,p0*p0), y1=lerp(H*.34,H*.96,p1*p1);
    X.strokeStyle='rgba(255,255,255,.18)'; X.lineWidth=1; X.beginPath(); X.moveTo(roadX(y1,-1),y1); X.lineTo(roadX(y1,1),y1); X.stroke();
  }}
  X.strokeStyle='rgba(255,255,255,.18)'; X.lineWidth=2;
  for(const s of [-.33,.33]) {{ X.beginPath(); X.moveTo(roadX(H*.34,s),H*.34); X.lineTo(roadX(H*.96,s),H*.96); X.stroke(); }}
}}
function drawCube(cx,cy,scale) {{
  const bob=Math.sin(t*5)*3; cy+=bob;
  const s=scale;
  X.fillStyle='rgba(0,0,0,.22)'; X.beginPath(); X.ellipse(cx,cy+s*.8,s*.72,s*.19,0,0,Math.PI*2); X.fill();
  rounded(cx-s*.48,cy-s*.58,s*.96,s*.96,s*.12,'#f2c46d');
  X.fillStyle='#2b3138'; X.fillRect(cx-s*.25,cy-s*.18,s*.12,s*.12); X.fillRect(cx+s*.13,cy-s*.18,s*.12,s*.12);
  X.fillStyle='#8c6540'; X.fillRect(cx-s*.38,cy+s*.37,s*.19,s*.44); X.fillRect(cx+s*.19,cy+s*.37,s*.19,s*.44);
  X.save(); X.translate(cx-s*.54,cy); X.rotate(Math.sin(t*6)*.18); X.fillStyle='#d9a95c'; X.fillRect(-s*.08,-s*.05,s*.16,s*.46); X.restore();
  X.save(); X.translate(cx+s*.54,cy); X.rotate(-Math.sin(t*6)*.18); X.fillStyle='#d9a95c'; X.fillRect(-s*.08,-s*.05,s*.16,s*.46); X.restore();
}}
function drawEncounter() {{
  if(!S.encounter) return;
  const cx=W/2, cy=H*.48;
  if(S.encounter.kind==='obstacle') {{
    X.strokeStyle='#3e612f'; X.lineWidth=8;
    for(let i=-2;i<=2;i++) {{ X.beginPath(); X.moveTo(cx+i*24,cy+34); X.lineTo(cx+i*17,cy-30-(i%2)*10); X.stroke(); }}
    X.fillStyle='#d8f0b2'; X.font='bold 14px system-ui'; X.textAlign='center'; X.fillText('JUMP',cx,cy-45);
  }} else if(S.encounter.kind==='enemy') {{
    X.fillStyle='#6aa35c'; X.beginPath(); X.arc(cx,cy,32,0,Math.PI*2); X.fill();
    X.fillStyle='#172020'; X.fillRect(cx-13,cy-7,8,8); X.fillRect(cx+5,cy-7,8,8);
    X.fillStyle='#fff'; X.font='bold 13px system-ui'; X.textAlign='center'; X.fillText(S.encounter.name||'Enemy',cx,cy-45);
  }}
}}
function drawCrossroads() {{
  const baseY=H*.70, x=W*.50;
  X.strokeStyle='#6f4c2e'; X.lineWidth=16; X.beginPath(); X.moveTo(x,baseY+80); X.lineTo(x,baseY-130); X.stroke();
  const picks=S.routes.slice(0,3);
  picks.forEach((r,i)=>{{
    const yy=baseY-96+i*54, dir=i===1?1:(i===0?-1:1), dx=dir*(140+i*12);
    rounded(x+(dir<0?dx-160:20),yy,150,38,7,'#8b633c');
    X.fillStyle='#fff4dc'; X.font='bold 13px system-ui'; X.textAlign='center';
    X.fillText(r.name, x+(dir<0?dx-85:95), yy+24);
  }});
  X.fillStyle='#fff'; X.font='bold 24px system-ui'; X.textAlign='center'; X.fillText('LANTERN CAMP',W/2,72);
  X.fillStyle='#e6f5ff'; X.font='14px system-ui'; X.fillText('Choose a route below to begin',W/2,96);
}}
function frame() {{
  t+=0.016; drawBackground(); drawRoad();
  if(S.route) {{ drawEncounter(); drawCube(W/2,H*.81,64); }} else {{ drawCrossroads(); drawCube(W*.50,H*.88,52); }}
  requestAnimationFrame(frame);
}}
frame();
</script>
</body>
</html>
"""
