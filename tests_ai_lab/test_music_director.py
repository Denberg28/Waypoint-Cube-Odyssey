from __future__ import annotations

import json
from pathlib import Path

from ai_lab.music_agent import AMBIENCES, CONTEXTS, validate


def test_audio_profile_v2_covers_all_game_music_contexts():
    main = Path("scripts/main.gd").read_text(encoding="utf-8")
    director = Path("scripts/music_director.gd").read_text(encoding="utf-8")
    profile = json.loads(Path("runtime/music_profile.json").read_text(encoding="utf-8"))

    assert profile["schema"] == 2
    assert set(profile["contexts"]) == set(CONTEXTS)
    assert "road_danger" in CONTEXTS
    assert set(profile["ambiences"]) == set(AMBIENCES)

    assert 'return "road_danger"' in main
    assert "music_profile_context(context)" in main
    assert "ambience_profile_context(kind)" in main
    assert "tempo_scale" in main
    assert "root_shift" in main
    assert "melody_gain" in main
    assert "bass_gain" in main
    assert "air_gain" in main
    assert "melody_density" in main
    assert "ambience_intensity" in main

    assert "func ambience_config(context: String) -> Dictionary:" in director
    assert "func sfx_config() -> Dictionary:" in director
    assert "profile_schema" in director


def test_music_agent_clamps_every_bounded_audio_control():
    raw = {
        "summary": "test",
        "contexts": {
            c: {
                "pitch_scale": 4.0,
                "volume_delta_db": 20.0,
                "tempo_scale": 4.0,
                "root_shift": 99,
                "melody_gain": 9.0,
                "bass_gain": -4.0,
                "air_gain": 8.0,
                "melody_density": 0.1,
            }
            for c in CONTEXTS
        },
        "ambiences": {
            c: {"volume_delta_db": -99.0, "intensity": 8.0}
            for c in AMBIENCES
        },
        "sfx": {"volume_delta_db": 99.0},
        "recommendations": ["ok"],
    }
    out = validate(raw)
    assert out["schema"] == 2
    for cfg in out["contexts"].values():
        assert cfg["pitch_scale"] == 1.12
        assert cfg["volume_delta_db"] == 4.0
        assert cfg["tempo_scale"] == 1.08
        assert cfg["root_shift"] == 2
        assert cfg["melody_gain"] == 1.2
        assert cfg["bass_gain"] == 0.8
        assert cfg["air_gain"] == 1.25
        assert cfg["melody_density"] == 0.75
    for cfg in out["ambiences"].values():
        assert cfg["volume_delta_db"] == -4.0
        assert cfg["intensity"] == 1.25
    assert out["sfx"]["volume_delta_db"] == 3.0


def test_music_director_remains_parameter_only_not_raw_audio_generation():
    agent = Path("ai_lab/music_agent.py").read_text(encoding="utf-8")
    workflow = Path(".github/workflows/music-director.yml").read_text(encoding="utf-8")

    assert "Never output melodies" in agent
    assert "audio files" in agent
    assert "source code" in agent
    assert "bounded parameters only" in agent
    assert 'GEMINI_MAX_REQUESTS_PER_RUN: "1"' in workflow
    assert 'cron: "37 2,14 * * *"' in workflow


def test_music_workflow_updates_development_branch():
    workflow = Path(".github/workflows/music-director.yml").read_text(encoding="utf-8")

    assert "ref: ai-development" in workflow
    assert "python -m ai_lab.music_agent" in workflow
    assert "runtime/music_profile.json" in workflow
    assert "reports/MUSIC_DIRECTOR_LATEST.md" in workflow
    assert "git push origin ai-development" in workflow
