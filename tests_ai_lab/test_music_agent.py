from ai_lab.music_agent import CONTEXTS, validate


def test_music_profile_is_clamped_and_complete():
    raw = {
        "summary": "test",
        "contexts": {
            "camp": {"pitch_scale": 4.0, "volume_delta_db": 99},
            "road": {"pitch_scale": 0.1, "volume_delta_db": -99},
        },
        "recommendations": ["x"] * 20,
    }
    out = validate(raw)
    assert set(out["contexts"]) == set(CONTEXTS)
    assert out["contexts"]["camp"]["pitch_scale"] == 1.12
    assert out["contexts"]["camp"]["volume_delta_db"] == 4.0
    assert out["contexts"]["road"]["pitch_scale"] == 0.88
    assert out["contexts"]["road"]["volume_delta_db"] == -4.0
    assert len(out["recommendations"]) == 8


def test_music_profile_defaults_are_neutral():
    out = validate({})
    for cfg in out["contexts"].values():
        assert cfg["pitch_scale"] == 1.0
        assert cfg["volume_delta_db"] == 0.0
