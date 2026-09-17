from ai_lab.beta_contracts import validate_beta_report
from ai_lab.beta_testers import build_council, report_ids, offline_report
from ai_lab.simulation import simulate_trace


def test_simulated_trace_uses_real_game_rules():
    trace = simulate_trace("qa_edge_cases", seed=7, max_actions=12)
    assert trace["starting_route"] == "forge"
    assert isinstance(trace["telemetry"], list)
    assert trace["actions"]


def test_beta_report_is_clamped_and_limited():
    data = validate_beta_report({
        "fun_score": 99, "clarity_score": 0, "friction_score": "3",
        "session_summary": "x",
        "observations": [{"category":"bad","severity":"bad","evidence":"e","recommendation":"r"}]*10,
        "bugs": [],
        "feature_requests": [{"title":"f","category":"bad","player_value":"v","rationale":"r","safe_content_only":True,"desired_outcome":"d"}]*10,
        "keep": ["k"]*10,
    })
    assert data["fun_score"] == 5 and data["clarity_score"] == 1
    assert len(data["observations"]) == 6
    assert len(data["feature_requests"]) == 5
    assert len(data["keep"]) == 5


def test_council_contains_stable_feedback_ids():
    trace = simulate_trace("first_time_player", seed=1, max_actions=8)
    report = report_ids("first_time_player", "20260101T000000Z", offline_report("first_time_player", trace))
    council = build_council("20260101T000000Z", [report])
    assert council["tester_count"] == 1
    assert council["safe_content_feature_requests"][0]["id"].startswith("20260101T000000Z-first_time_player-feature-")
