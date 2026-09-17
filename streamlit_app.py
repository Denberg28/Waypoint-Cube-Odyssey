from __future__ import annotations
import json
from pathlib import Path
import streamlit as st
import streamlit.components.v1 as components
from streamlit_lab.core import new_state, ROUTES, COSMETICS, buy_cosmetic, cosmetic_price
from streamlit_lab.world_state import load_world_state, load_beta_council

ROOT = Path(__file__).resolve().parent
GODOT_WEB_URL = "https://denberg28.github.io/Waypoint-Cube-Odyssey/"

def load_json(path: Path, default):
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except Exception:
        return default

st.set_page_config(page_title="Waypoint AI Development Lab", page_icon="🧭", layout="wide")
if "game" not in st.session_state:
    st.session_state.game = new_state()
state = st.session_state.game
world = load_world_state()
council = load_beta_council()
telemetry_snapshot = load_json(ROOT / "runtime/telemetry_snapshot.json", [])
music_profile = load_json(ROOT / "runtime/music_profile.json", {})
telemetry_config = load_json(ROOT / "runtime/public_telemetry.json", {})

st.title("🧭 Waypoint: Cube Odyssey — AI Development Lab")
st.caption("Play the actual Godot Web build, contribute anonymous gameplay telemetry by default, and watch the Gemini GM, beta council, and Music Director evolve the development branch.")

with st.sidebar:
    st.subheader("Night Watch")
    st.write(world.get("headline", "No AI update yet."))
    st.write("Featured route:", ROUTES.get(world.get("featured_route", ""), {}).get("name", "—"))
    st.write("Difficulty offset:", world.get("difficulty_offset", 0))
    exp = world.get("experiment", {})
    st.caption(f"Experiment: {exp.get('kind', 'none')} · value {exp.get('value', 0)}")
    st.divider()
    st.caption("Anonymous gameplay sharing is ON by default for the embedded tester. You can switch it off before or during play. Your Godot save stays inside your browser.")

play, gm, beta, music, market, lab = st.tabs([
    "🎮 Play Godot",
    "🌙 AI Game Master",
    "🤖 Beta Testers",
    "🎵 Music Director",
    "🛍️ Lab Market",
    "🧪 Dev Lab",
])

with play:
    st.subheader("Actual Godot Web Tester")
    st.caption("This is the same Godot project and scene structure as the desktop tester, exported to Web from the ai-development branch.")
    telemetry_ready = bool(telemetry_config.get("enabled", False))
    consent = st.checkbox(
        "Share anonymous gameplay telemetry to help improve Waypoint",
        value=True,
        disabled=not telemetry_ready,
        help="ON by default. Shares gameplay events such as route choices, jumps, encounters, fishing, marketplace actions, session progress, and music mute/shuffle behavior. It does not upload your save file, account identity, name, email, IP address, or free-text feedback. Turn this off any time to play without shared telemetry.",
    )
    if not telemetry_ready:
        st.caption("Public telemetry is not live yet; gameplay is currently validation-only until the analytics backend is connected.")
    elif consent:
        st.success("Anonymous gameplay telemetry is ON for this embedded session. You can switch it off above at any time.")
    else:
        st.info("Anonymous gameplay telemetry is OFF. You can still play normally.")
    game_url = GODOT_WEB_URL + ("?telemetry=1" if consent and telemetry_ready else "?telemetry=0")
    components.iframe(game_url, height=830, scrolling=False)
    st.link_button("Open Godot tester in a new tab", game_url, use_container_width=True)

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
    if telemetry_snapshot and isinstance(telemetry_snapshot, list) and isinstance(telemetry_snapshot[0], dict) and telemetry_snapshot[0].get("source") == "real_public_playtests":
        s = telemetry_snapshot[0]
        a, b, c = st.columns(3)
        a.metric("Real play sessions", s.get("unique_sessions", 0))
        b.metric("Real events sampled", s.get("sample_events", 0))
        c.metric("Obstacle jumps", s.get("jump_actions", 0))
        st.caption("These aggregate public playtest signals are supplied alongside synthetic traces to the beta agents.")
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
        st.caption("Synthetic testers are advisory agents. Real player telemetry is treated as evidence, not as instructions.")

with music:
    st.subheader("Gemini Flash-Lite Music Director")
    st.caption("The agent can only adjust bounded parameters on Waypoint's original procedural music. It cannot generate or copy copyrighted songs, melodies, lyrics, or arbitrary source code.")
    if music_profile:
        st.info(music_profile.get("summary", "Current bounded music profile"))
        rows = []
        for context, cfg in music_profile.get("contexts", {}).items():
            rows.append({
                "context": context,
                "pitch_scale": cfg.get("pitch_scale", 1.0),
                "volume_delta_db": cfg.get("volume_delta_db", 0.0),
            })
        st.dataframe(rows, use_container_width=True, hide_index=True)
        recommendations = music_profile.get("recommendations", [])
        if recommendations:
            st.write("**Latest music recommendations**")
            for item in recommendations:
                st.write("-", item)
    else:
        st.info("No Music Director profile has been generated yet.")
    st.caption("Real players contribute useful signals through music context, mute/unmute, and shuffle events while anonymous telemetry sharing is enabled.")

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
    st.write("**Gemini council:** synthetic testing + aggregate anonymous human telemetry")
    st.write("**Music Director:** bounded procedural-score parameter agent")
    st.write("**Streamlit:** dashboard, browser host, and telemetry preference surface")
    if telemetry_snapshot:
        st.write("### Latest shared telemetry snapshot")
        st.json(telemetry_snapshot[:10] if isinstance(telemetry_snapshot, list) else telemetry_snapshot)
    st.write(f"Local simulated telemetry events this Streamlit session: {len(state['telemetry'])}")
    st.download_button(
        "Download lab telemetry JSON",
        json.dumps(state["telemetry"], indent=2),
        "waypoint_telemetry.json",
        "application/json",
    )
