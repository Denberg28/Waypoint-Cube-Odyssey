from streamlit_lab.core import new_state, choose_route, ROUTES
from streamlit_lab.viewport import viewport_html


def test_viewport_renders_crossroads_and_route_state():
    state = new_state()
    html = viewport_html(state, {"featured_route": "fen"}, ROUTES)
    assert "LANTERN CAMP" in html
    assert "Crossroads" in html
    choose_route(state, "fen")
    html = viewport_html(state, {"featured_route": "fen"}, ROUTES)
    assert "Whispering Fen" in html
    assert "Trail 0/12" in html


def test_viewport_handles_obstacle_without_executing_user_text():
    state = new_state()
    choose_route(state, "moss")
    state["message"] = "</script><script>alert('x')</script>"
    state["encounter"] = {"kind": "obstacle", "name": "Thorns"}
    html = viewport_html(state, {}, ROUTES)
    assert "JUMP" in html
    assert "<\\/script>" in html
