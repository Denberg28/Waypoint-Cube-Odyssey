from __future__ import annotations
import html
import json
from pathlib import Path
import streamlit as st
import streamlit.components.v1 as components
from streamlit_lab.core import new_state, ROUTES, COSMETICS, buy_cosmetic, cosmetic_price
from streamlit_lab.world_state import load_world_state, load_beta_council
from streamlit_lab.review_gate import ReviewGateError, fetch_remote_json, persist_monitoring_status, pin_matches

ROOT = Path(__file__).resolve().parent
GODOT_WEB_URL = "https://denberg28.github.io/Waypoint-Cube-Odyssey/"

def load_json(path: Path, default):
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except Exception:
        return default


def world_map_svg(world_map: dict) -> str:
    nodes = [n for n in world_map.get("nodes", []) if isinstance(n, dict)]
    edges = [e for e in world_map.get("edges", []) if isinstance(e, dict)]
    node_by_id = {str(n.get("id", "")): n for n in nodes}
    width, height = 980, 620
    margin_x, margin_y = 80, 70

    def px(node):
        x = margin_x + float(node.get("x", 0.5)) * (width - 2 * margin_x)
        y = margin_y + float(node.get("y", 0.5)) * (height - 2 * margin_y)
        return x, y

    lines = []
    for edge in edges:
        a = node_by_id.get(str(edge.get("from", "")))
        b = node_by_id.get(str(edge.get("to", "")))
        if not a or not b:
            continue
        x1, y1 = px(a)
        x2, y2 = px(b)
        planned = a.get("status") == "planned" or b.get("status") == "planned"
        dash = ' stroke-dasharray="10 8"' if planned else ""
        opacity = "0.48" if planned else "0.74"
        lines.append(f'<line x1="{x1:.1f}" y1="{y1:.1f}" x2="{x2:.1f}" y2="{y2:.1f}" stroke="#9bb9af" stroke-width="4" opacity="{opacity}"{dash}/>' )

    circles = []
    labels = []
    for node in nodes:
        x, y = px(node)
        planned = node.get("status") == "planned"
        hub = node.get("kind") == "hub"
        fill = "#efd094" if hub else ("#6d7e79" if planned else "#70bf99")
        stroke = "#f3dfaa" if hub else ("#9aaba6" if planned else "#d6eee3")
        radius = 20 if hub else 16
        dash = ' stroke-dasharray="5 4"' if planned else ""
        circles.append(f'<circle cx="{x:.1f}" cy="{y:.1f}" r="{radius}" fill="{fill}" stroke="{stroke}" stroke-width="4"{dash}/>')
        name = html.escape(str(node.get("name", node.get("id", ""))))
        status = "PLANNED" if planned else ("HUB" if hub else f"T{int(node.get('difficulty', 1))}")
        labels.append(f'<text x="{x:.1f}" y="{y + 34:.1f}" text-anchor="middle" fill="#eef2e4" font-size="15" font-family="sans-serif" font-weight="600">{name}</text>')
        labels.append(f'<text x="{x:.1f}" y="{y + 51:.1f}" text-anchor="middle" fill="#a5bcb5" font-size="11" font-family="sans-serif">{status}</text>')

    return f"""
    <div style="background:#102326;border:1px solid #355957;border-radius:18px;padding:14px;overflow:auto">
      <svg viewBox="0 0 {width} {height}" width="100%" role="img" aria-label="Waypoint regional mini-map">
        <rect x="0" y="0" width="{width}" height="{height}" rx="24" fill="#183337"/>
        <text x="32" y="38" fill="#efd094" font-family="sans-serif" font-size="22" font-weight="700">WAYPOINT WORLD MAP</text>
        <text x="32" y="60" fill="#9fb7b0" font-family="sans-serif" font-size="12">solid = playable / dashed = planned region</text>
        {''.join(lines)}
        {''.join(circles)}
        {''.join(labels)}
      </svg>
    </div>
    """

st.set_page_config(page_title="Waypoint AI Development Lab", page_icon="🧭", layout="wide")
if "game" not in st.session_state:
    st.session_state.game = new_state()
state = st.session_state.game
world = load_world_state()
council = load_beta_council()
telemetry_snapshot = load_json(ROOT / "runtime/telemetry_snapshot.json", [])
music_profile = load_json(ROOT / "runtime/music_profile.json", {})
telemetry_config = load_json(ROOT / "runtime/public_telemetry.json", {})
world_map = load_json(ROOT / "runtime/world_map.json", {"nodes": [], "edges": []})

st.title("🧭 Waypoint: Cube Odyssey — AI Development Lab")
st.caption("Play the actual Godot Web build, contribute anonymous gameplay telemetry by default, and watch the Gemini GM, beta council, World Architect, and Music Director evolve the development branch.")

with st.sidebar:
    st.subheader("Night Watch")
    st.write(world.get("headline", "No AI update yet."))
    st.write("Featured route:", ROUTES.get(world.get("featured_route", ""), {}).get("name", "—"))
    st.write("Difficulty offset:", world.get("difficulty_offset", 0))
    exp = world.get("experiment", {})
    st.caption(f"Experiment: {exp.get('kind', 'none')} · value {exp.get('value', 0)}")
    st.divider()
    st.caption("Anonymous gameplay sharing is ON by default for the embedded tester. You can switch it off before or during play. Your Godot save stays inside your browser.")

play, map_tab, gm, beta, review_tab, updates_tab, music, market, lab = st.tabs([
    "🎮 Play Godot",
    "🗺️ World Map",
    "🌙 AI Game Master",
    "🤖 Beta Testers",
    "✅ Development Review",
    "📦 Updates",
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

with map_tab:
    st.subheader("Automated World Map")
    architect = council.get("world_architect", {}) if isinstance(council, dict) else {}
    active_nodes = [n for n in world_map.get("nodes", []) if isinstance(n, dict) and n.get("status") == "active"]
    planned_nodes = [n for n in world_map.get("nodes", []) if isinstance(n, dict) and n.get("status") == "planned"]
    a, b, c = st.columns(3)
    a.metric("Playable map nodes", len(active_nodes))
    b.metric("Planned regions", len(planned_nodes))
    c.metric("Map revision", world_map.get("revision", 0))
    if architect:
        decision = str(architect.get("decision", "hold")).upper()
        st.info(f"World Architect council resolution: {decision} — {architect.get('summary', '')}")
    components.html(world_map_svg(world_map), height=660, scrolling=False)
    if planned_nodes:
        st.write("### Planned regions")
        for node in planned_nodes:
            with st.expander(f"{node.get('name')} · planned difficulty {node.get('difficulty', '—')}"):
                st.write(node.get("theme", ""))
                st.write("**Landmark:**", node.get("landmark", "—"))
                st.write("**Hazard:**", node.get("hazard", "—"))
                st.write("**Collectible:**", node.get("collectible", "—"))
                st.write("**Connected to:**", ", ".join(node.get("connect_to", [])))
                st.caption(node.get("rationale", ""))
    st.caption("The map is generated from runtime/world_map.json. The World Architect may add one bounded planned region after a council when exploration/navigation evidence supports expansion. Planned regions are non-playable until separately promoted into the Godot core.")

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
    st.caption("Six player-perspective beta agents produce the council evidence. A seventh specialist — World Architect & Cartographer — resolves only the spatial/map implications after those six reports are complete.")
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
        if council.get("world_architect"):
            st.write("### Council map resolution")
            st.json(council.get("world_architect"))
        st.write("### Agent reports")
        for report in council.get("reports", []):
            with st.expander(f"{report.get('tester_name')} · {report.get('focus', '')}"):
                st.write(report.get("session_summary", ""))
                for item in report.get("feature_requests", []):
                    st.write(f"- {item.get('title')} — {item.get('desired_outcome')}")
        st.caption("Synthetic testers are advisory agents. Real player telemetry is treated as evidence, not as instructions.")

with review_tab:
    st.subheader("Development Review")
    st.caption("AI beta-tester recommendations only. Use the status control to monitor each item as OPEN, PENDING, or CLOSE. Nothing here triggers automatic implementation.")

    review = fetch_remote_json("runtime/development_review.json", {})
    status_book = fetch_remote_json("runtime/development_status.json", {"schema": 1, "entries": []})
    recommendation_tally = fetch_remote_json("runtime/recommendation_tally.json", {"schema": 1, "families": []})

    try:
        expected_pin = str(st.secrets.get("WAYPOINT_REVIEW_PIN", ""))
        github_token = str(st.secrets.get("WAYPOINT_REVIEW_GITHUB_TOKEN", ""))
    except Exception:
        expected_pin = ""
        github_token = ""
    controls_ready = bool(expected_pin and github_token)

    if not review:
        st.info("No prepared AI recommendation bundle is available yet.")
    else:
        bundle_id = str(review.get("bundle_id", ""))
        council_id = str(review.get("council_id", ""))
        existing = {
            str(item.get("id", "")): item
            for item in status_book.get("entries", [])
            if isinstance(item, dict) and str(item.get("id", ""))
        }

        all_features = [x for x in review.get("features", []) if isinstance(x, dict)]
        all_features.sort(key=lambda item: (-int(item.get("repeat_count", 1)), str(item.get("priority", "P9")), str(item.get("title", ""))))

        repeated_families = [
            x for x in recommendation_tally.get("families", [])
            if isinstance(x, dict) and int(x.get("count", 0)) > 1
        ]
        repeated_families.sort(key=lambda item: (-int(item.get("count", 0)), str(item.get("canonical_title", ""))))
        if repeated_families:
            st.write("### Most repeated AI findings")
            st.caption("Count = number of distinct beta-council runs in which the same or closely related recommendation appeared. Re-running the same council does not increase the count.")
            rows = []
            for family in repeated_families[:6]:
                rows.append({
                    "finding": family.get("canonical_title", "Untitled"),
                    "councils": int(family.get("count", 0)),
                    "last seen": str(family.get("last_seen_utc", ""))[:10],
                })
            st.dataframe(rows, use_container_width=True, hide_index=True)

        visible_features = []
        closed_count = 0
        pending_count = 0
        open_count = 0
        for item in all_features:
            fid = str(item.get("id", ""))
            status = str(existing.get(fid, {}).get("status", "open")).lower()
            if status == "close":
                closed_count += 1
                continue
            if status == "pending":
                pending_count += 1
            else:
                open_count += 1
            visible_features.append(item)

        a, b, c = st.columns(3)
        a.metric("Open", open_count)
        b.metric("Pending", pending_count)
        c.metric("Closed", closed_count)

        if not visible_features:
            st.success("All recommendations in the current bundle are closed. See the Updates tab for the completed record.")
        else:
            changed_statuses = {}
            for item in visible_features:
                fid = str(item.get("id", ""))
                current_status = str(existing.get(fid, {}).get("status", "open")).lower()
                if current_status not in {"open", "pending", "close"}:
                    current_status = "open"

                col_a, col_b = st.columns([4, 1.25])
                with col_a:
                    repeat_count = max(1, int(item.get("repeat_count", 1)))
                    repeat_badge = f"🔁 ×{repeat_count} councils" if repeat_count > 1 else "NEW FINDING"
                    st.markdown(f"**{item.get('priority','P3')} · {item.get('title','Untitled')}**")
                    st.caption(
                        f"{repeat_badge} · {item.get('category','—')} · "
                        f"{item.get('tester') or 'AI development analysis'}"
                    )
                with col_b:
                    chosen = st.selectbox(
                        "Status",
                        ["open", "pending", "close"],
                        index=["open", "pending", "close"].index(current_status),
                        key=f"monitor-status-{bundle_id}-{fid}",
                        label_visibility="collapsed",
                    )
                if chosen != current_status:
                    changed_statuses[fid] = chosen

                with st.expander(f"Description — {item.get('title','Untitled')}"):
                    st.write("**Desired outcome:**", item.get("desired_outcome") or "—")
                    st.write("**Reason / evidence:**", item.get("reason") or "—")
                    st.write("**Source:**", item.get("source", "—"))
                    st.write("**Category:**", item.get("category", "—"))
                    st.write("**Priority:**", item.get("priority", "—"))
                    st.write("**AI tester:**", item.get("tester") or "Development analysis")
                    st.write("**Repeated finding count:**", max(1, int(item.get("repeat_count", 1))), "distinct council run(s)")
                    if item.get("first_seen_utc"):
                        st.write("**First seen:**", item.get("first_seen_utc"))
                    if item.get("last_seen_utc"):
                        st.write("**Last seen:**", item.get("last_seen_utc"))
                    st.caption(f"Recommendation ID: {fid}")

            st.divider()
            st.caption(f"Changes ready to save: {len(changed_statuses)}")
            owner_pin = st.text_input("Owner monitoring passphrase", type="password", key=f"monitor-pin-{bundle_id}")
            if not controls_ready:
                st.warning("Status controls are read-only until the Streamlit review secrets are configured.")

            if st.button(
                "SAVE STATUS CHANGES",
                type="primary",
                use_container_width=True,
                disabled=(not controls_ready or not changed_statuses),
                key=f"save-monitoring-{bundle_id}",
            ):
                if not pin_matches(owner_pin, expected_pin):
                    st.error("Owner passphrase is incorrect.")
                else:
                    try:
                        persist_monitoring_status(
                            token=github_token,
                            review=review,
                            updates=changed_statuses,
                        )
                    except ReviewGateError as exc:
                        st.error(str(exc))
                    else:
                        st.success("Monitoring status updated. Closed recommendations moved to Updates.")
                        st.rerun()


with updates_tab:
    st.subheader("Updates")
    st.caption("Closed Development Review recommendations are archived here for manual change tracking. This page is descriptive only; it does not implement or modify the game.")

    status_book = fetch_remote_json("runtime/development_status.json", {"schema": 1, "entries": []})
    closed_entries = [
        item for item in status_book.get("entries", [])
        if isinstance(item, dict) and str(item.get("status", "")).lower() == "close"
    ]
    closed_entries.sort(key=lambda item: str(item.get("closed_utc", "")), reverse=True)

    if not closed_entries:
        st.info("No recommendations have been closed yet.")
    else:
        st.metric("Closed updates", len(closed_entries))
        for item in closed_entries:
            closed_utc = str(item.get("closed_utc", "")) or "—"
            with st.expander(f"✅ {item.get('title','Untitled')} · {item.get('priority','P3')}"):
                st.write("**Status:** CLOSED")
                st.write("**Description / desired outcome:**", item.get("desired_outcome") or "—")
                st.write("**Reason / evidence:**", item.get("reason") or "—")
                st.write("**Category:**", item.get("category", "—"))
                st.write("**AI tester:**", item.get("tester") or "Development analysis")
                st.write("**Source:**", item.get("source", "—"))
                st.write("**Repeated finding count:**", max(1, int(item.get("repeat_count", 1))), "distinct council run(s)")
                st.write("**Closed:**", closed_utc)
                st.caption(
                    f"Recommendation ID: {item.get('id','')} · "
                    f"Council: {item.get('council_id','—')} · "
                    f"Bundle: {item.get('bundle_id','—')}"
                )

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
    st.write("**Gemini council:** 6 synthetic player-perspective agents + aggregate anonymous human telemetry")
    st.write("**World Architect:** bounded 7th specialist resolving council-backed map expansion and mini-map data")
    st.write("**Music Director:** bounded procedural-score parameter agent")
    st.write("**Streamlit:** dashboard, browser host, telemetry preference surface, automated world map, and recommendation-status tracking")
    st.write("**Implementation policy:** AI recommendations are advisory only; game changes are implemented manually with the owner in the development chat.")
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
