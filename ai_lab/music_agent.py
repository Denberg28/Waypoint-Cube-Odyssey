#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
from pathlib import Path

from ai_lab.common import call_gemini

ROOT = Path(__file__).resolve().parents[1]
CONTEXTS = ["camp", "road", "road_danger", "boss", "fishing", "campfire"]
AMBIENCES = ["forest", "rain", "wind", "boss", "campfire"]

CONTEXT_PROPERTIES = {
    "pitch_scale": {"type": "number"},
    "volume_delta_db": {"type": "number"},
    "tempo_scale": {"type": "number"},
    "root_shift": {"type": "integer"},
    "melody_gain": {"type": "number"},
    "bass_gain": {"type": "number"},
    "air_gain": {"type": "number"},
    "melody_density": {"type": "number"},
}

SCHEMA = {
    "type": "object",
    "additionalProperties": False,
    "properties": {
        "summary": {"type": "string"},
        "contexts": {
            "type": "object",
            "additionalProperties": False,
            "properties": {
                c: {
                    "type": "object",
                    "additionalProperties": False,
                    "properties": CONTEXT_PROPERTIES,
                    "required": list(CONTEXT_PROPERTIES),
                }
                for c in CONTEXTS
            },
            "required": CONTEXTS,
        },
        "ambiences": {
            "type": "object",
            "additionalProperties": False,
            "properties": {
                c: {
                    "type": "object",
                    "additionalProperties": False,
                    "properties": {
                        "volume_delta_db": {"type": "number"},
                        "intensity": {"type": "number"},
                    },
                    "required": ["volume_delta_db", "intensity"],
                }
                for c in AMBIENCES
            },
            "required": AMBIENCES,
        },
        "sfx": {
            "type": "object",
            "additionalProperties": False,
            "properties": {"volume_delta_db": {"type": "number"}},
            "required": ["volume_delta_db"],
        },
        "recommendations": {
            "type": "array",
            "items": {"type": "string"},
            "maxItems": 8,
        },
    },
    "required": ["summary", "contexts", "ambiences", "sfx", "recommendations"],
}

SYSTEM = """You are Waypoint: Cube Odyssey's Music Director and audio supervisor.
Improve the game's existing ORIGINAL procedural soundtrack, ambience, and SFX mix using
ONLY bounded parameter recommendations. Never imitate, quote, reference, or reconstruct
a copyrighted or identifiable song. Never output melodies, note sequences, lyrics,
source code, audio files, or asset URLs.

You may tune only:
- pitch_scale 0.88..1.12
- volume_delta_db -4..4 for music/ambience, -3..3 for SFX
- tempo_scale 0.92..1.08
- root_shift integer -2..2 semitones
- melody_gain, bass_gain 0.80..1.20
- air_gain 0.75..1.25
- melody_density 0.75..1.00
- ambience intensity 0.75..1.25

Contexts are camp, road, road_danger, boss, fishing, campfire.
Ambiences are forest, rain, wind, boss, campfire.
Prefer small, evidence-based changes from the current profile. Preserve gameplay clarity:
combat SFX must remain audible, camp should be restful, road_danger/boss should gain
tension without excessive loudness, and fishing/campfire should remain low fatigue.
Use only aggregate telemetry supplied in the prompt."""

def load(path: Path, default):
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except Exception:
        return default

def clamp(value, lo, hi):
    return max(lo, min(hi, value))

def neutral_context() -> dict:
    return {
        "pitch_scale": 1.0,
        "volume_delta_db": 0.0,
        "tempo_scale": 1.0,
        "root_shift": 0,
        "melody_gain": 1.0,
        "bass_gain": 1.0,
        "air_gain": 1.0,
        "melody_density": 1.0,
    }

def validate(data: dict) -> dict:
    out = {
        "schema": 2,
        "summary": str(data.get("summary", "AI audio direction profile."))[:500],
        "contexts": {},
        "ambiences": {},
        "sfx": {},
        "recommendations": [],
    }
    src = data.get("contexts", {}) if isinstance(data.get("contexts"), dict) else {}
    for c in CONTEXTS:
        cfg = src.get(c, {}) if isinstance(src.get(c, {}), dict) else {}
        base = neutral_context()
        out["contexts"][c] = {
            "pitch_scale": round(clamp(float(cfg.get("pitch_scale", base["pitch_scale"])), 0.88, 1.12), 3),
            "volume_delta_db": round(clamp(float(cfg.get("volume_delta_db", 0.0)), -4.0, 4.0), 2),
            "tempo_scale": round(clamp(float(cfg.get("tempo_scale", 1.0)), 0.92, 1.08), 3),
            "root_shift": int(clamp(int(cfg.get("root_shift", 0)), -2, 2)),
            "melody_gain": round(clamp(float(cfg.get("melody_gain", 1.0)), 0.80, 1.20), 3),
            "bass_gain": round(clamp(float(cfg.get("bass_gain", 1.0)), 0.80, 1.20), 3),
            "air_gain": round(clamp(float(cfg.get("air_gain", 1.0)), 0.75, 1.25), 3),
            "melody_density": round(clamp(float(cfg.get("melody_density", 1.0)), 0.75, 1.00), 3),
        }

    amb = data.get("ambiences", {}) if isinstance(data.get("ambiences"), dict) else {}
    for c in AMBIENCES:
        cfg = amb.get(c, {}) if isinstance(amb.get(c, {}), dict) else {}
        out["ambiences"][c] = {
            "volume_delta_db": round(clamp(float(cfg.get("volume_delta_db", 0.0)), -4.0, 4.0), 2),
            "intensity": round(clamp(float(cfg.get("intensity", 1.0)), 0.75, 1.25), 3),
        }

    sfx = data.get("sfx", {}) if isinstance(data.get("sfx"), dict) else {}
    out["sfx"] = {
        "volume_delta_db": round(clamp(float(sfx.get("volume_delta_db", 0.0)), -3.0, 3.0), 2)
    }
    if isinstance(data.get("recommendations"), list):
        out["recommendations"] = [str(x)[:240] for x in data["recommendations"][:8]]
    return out

def neutral_payload() -> dict:
    return {
        "summary": "Offline neutral validation profile.",
        "contexts": {c: neutral_context() for c in CONTEXTS},
        "ambiences": {c: {"volume_delta_db": 0.0, "intensity": 1.0} for c in AMBIENCES},
        "sfx": {"volume_delta_db": 0.0},
        "recommendations": ["Collect more real-player audio telemetry before making larger score changes."],
    }

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--offline", action="store_true")
    args = ap.parse_args()

    telemetry = load(ROOT / "runtime/telemetry_snapshot.json", [])
    current = load(ROOT / "runtime/music_profile.json", {})
    prompt = json.dumps(
        {
            "aggregate_or_recent_telemetry": telemetry[-200:] if isinstance(telemetry, list) else telemetry,
            "current_profile": current,
            "audio_engine": {
                "music_contexts": CONTEXTS,
                "ambience_contexts": AMBIENCES,
                "procedural_variants_per_music_context": 5,
                "policy": "bounded parameters only; no raw melodies/audio/code",
            },
        },
        ensure_ascii=False,
    )

    data = neutral_payload() if args.offline else call_gemini(prompt, SCHEMA, SYSTEM)
    out = validate(data)
    (ROOT / "runtime/music_profile.json").write_text(
        json.dumps(out, indent=2, ensure_ascii=False) + "\n", encoding="utf-8"
    )

    (ROOT / "reports").mkdir(exist_ok=True)
    lines = ["# AI Music Director — Audio Profile v2", "", out["summary"], "", "## Score contexts"]
    for c, cfg in out["contexts"].items():
        lines.append(
            f"- **{c}** tempo ×{cfg['tempo_scale']} · key {cfg['root_shift']:+d} st · "
            f"melody ×{cfg['melody_gain']} · bass ×{cfg['bass_gain']} · air ×{cfg['air_gain']} · "
            f"density {cfg['melody_density']} · pitch ×{cfg['pitch_scale']} · "
            f"mix {cfg['volume_delta_db']:+.2f} dB"
        )
    lines += ["", "## Ambience"]
    for c, cfg in out["ambiences"].items():
        lines.append(f"- **{c}** intensity ×{cfg['intensity']} · mix {cfg['volume_delta_db']:+.2f} dB")
    lines += ["", f"## SFX", f"- Global SFX mix: {out['sfx']['volume_delta_db']:+.2f} dB"]
    if out["recommendations"]:
        lines += ["", "## Recommendations"] + [f"- {x}" for x in out["recommendations"]]
    (ROOT / "reports/MUSIC_DIRECTOR_LATEST.md").write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(json.dumps({"ok": True, "schema": 2, "contexts": len(out["contexts"]), "ambiences": len(out["ambiences"])}))

if __name__ == "__main__":
    main()
