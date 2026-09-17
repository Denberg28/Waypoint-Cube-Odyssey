from __future__ import annotations
import json
import streamlit as st
import streamlit.components.v1 as components
from streamlit_lab.core import new_state, ROUTES, COSMETICS, buy_cosmetic, cosmetic_price
from streamlit_lab.world_state import load_world_state, load_beta_council

GODOT_WEB_URL = "https://denberg28.github.io/Waypoint-Cube-Odyssey/"

st.set_page_config(page_title="Waypoint AI Development Lab", page_icon="🧭", layout="wide")
if "game" not in st.session_state:
    st.session_state.game = new_state()
state = st.session_state.game
world = load_world_state()
council = load_beta_council()

st.title("🧭 Waypoint: Cube Odyssey — AI Development Lab")
st.caption("The Play tab embeds the actual Godot Web export. Streamlit hosts the AI Game Master, beta council, and development telemetry around it.")

with st.sidebar:
    st.subheader("Night Watch")
    st.write(world.get("headline", "No AI update yet."))
    st.write("Featured route:", ROUTES.get(world.get("featured_route"), {}).get("name", "—"))
    st.write("Difficulty offset:", world.get("difficulty_offset", 0))
    exp = world.get("experiment", {})
    st.caption(f"Experiment: {exp.get('kind', 'none')} · value {exp.get('value', 0)}")
    st.divider()
    st.caption("The Godot game keeps its own save/state in the browser. Streamlit lab state below is separate and used only for AI-development experiments.")

play, gm, beta, market, lab = st.tabs([
    "🎮 Play Godot",
    "🌙 AI Game Master",
    "🤖 Beta Testers",
    "🛍️ Lab Market",
    "🧪 Dev Lab",
])

with play:
    st.subheader("Actual Godot Web Tester")
    st.caption("This is the same Godot project and scene structure as the desktop tester, exported to Web from the ai-development branch.")
    components.iframe(GODOT_WEB_URL, height=830, scrolling=False)
    st.link_button("Open Godot tester in a new tab", GODOT_WEB_URL, use_container_width=True)

with gm:
    st.subheader("Night Watch")
    focus = world.get("development_focus", {})
    if focus:
        st.info(f"Development focus: {focus.get('title', '')} — {focus.get('reason', '')}")
    adopted = world.get("adopted_feedback_ids", [])
    if adopted:
        st.write("**Adopted beta feedback:**")
        for item in adopted:
            st.code(item)
    st.json(world)
    st.caption("Gemini-generated world state is validated before the development build reads it.")

with beta:
    st.subheader("Gemini 3.5 Flash-Lite Beta Tester Council")
    if not council:
        st.info("No beta tester council has run yet.")
    else:
        scores = council.get("scores", {})
        x, y, z = st.columns(3)
        x.metric("Fun", f"{scores.get('fun_average', '—')} / 5")
        y.metric("Clarity", f"{scores.get('clarity_average', '—')} / 5")
        z.metric("Friction", f"{scores.get('friction_average', '—')} / 5")
        st.write("**Category signal**", council.get("category_signal", {}))
        st.write("### Safe content requests")
        safe = council.get("safe_content_feature_requests", [])
        if not safe:
            st.caption("None in latest council.")
        for item in safe:
            st.markdown(f"**{item.get('title')}** · `{item.get('id')}`")
            st.write(item.get("desired_outcome", ""))
        st.write("### Agent reports")
        for report in council.get("reports", []):
            with st.expander(f"{report.get('tester_name')} · {report.get('focus', '')}"):
                st.write(report.get("session_summary", ""))
                for item in report.get("feature_requests", []):
                    st.write(f"- {item.get('title')} — {item.get('desired_outcome')}")
        st.caption("These are synthetic AI tester reports based on executable play traces and data snapshots, not human visual playtest results.")

with market:
    st.subheader("Streamlit Lab Marketplace")
    st.caption("This is only the lightweight Python simulation used by the AI lab. Use the Play Godot tab for the real game marketplace.")
    exp = world.get("experiment", {})
    if exp.get("kind") == "market_discount" and int(exp.get("value", 0)) > 0:
        st.success(f"Beta-driven experiment: {int(exp['value'])}% marketplace discount this AI cycle.")
    for item in COSMETICS:
        owned = item["id"] in state["owned_cosmetics"]
        price = cosmetic_price(item, world)
        label = "Equip" if owned else f"Buy · {price} coins"
        c1, c2, c3 = st.columns([3, 1, 1])
        c1.write(f"**{item['name']}** · {item['slot'].title()}")
        c2.write("Owned" if owned else (f"{item['price']} → {price}" if price != item['price'] else ""))
        if c3.button(label, key=f"buy-{item['id']}"):
            _, msg = buy_cosmetic(state, item["id"], world)
            state["message"] = msg
            st.rerun()

with lab:
    st.subheader("AI Development Lab")
    st.write("**Godot Web source:** `ai-development` → GitHub Pages")
    st.write("**Godot production baseline:** locked v0.19")
    st.write("**Gemini council:** synthetic gameplay/system beta testing")
    st.write("**Streamlit:** dashboard and browser host")
    st.write(f"Local simulated telemetry events this session: {len(state['telemetry'])}")
    st.json(state["telemetry"][-25:])
    st.download_button(
        "Download lab telemetry JSON",
        json.dumps(state["telemetry"], indent=2),
        "waypoint_telemetry.json",
        "application/json",
    )
