# Gemini Beta Tester Council

v0.22 adds six synthetic beta tester agents powered by `gemini-3.5-flash-lite`.

## Roles

- First-Time Player — onboarding and control clarity
- Explorer & Collector — route variety, collectibles, cosmetics and revisits
- Combat Challenger — encounter pacing, challenge and mastery
- Economy Optimizer — coin flow, marketplace value and reward pacing
- Accessibility & UI Tester — readability, controls and cognitive load
- QA Edge-Case Tester — state transitions, exploits and regression risks

The agents do not claim to see the rendered Godot game. Each agent receives a deterministic or seeded play trace produced from the executable Streamlit game rules plus current route/world data. It must ground feedback in that evidence.

## Development loop

1. GitHub Actions runs the Beta Tester Council.
2. Six Gemini calls produce structured tester reports.
3. Reports are validated and assigned immutable feedback IDs.
4. `runtime/beta_council.json` becomes the latest council evidence.
5. The hourly AI Game Master/development cycle reads the council.
6. Gemini may adopt up to five valid feedback IDs.
7. Safe requests may become a bounded temporary experiment/content pack.
8. Source/UI/engine feature requests remain review-only backlog items.
9. ChatGPT can review `reports/LATEST_HANDOFF.md` and `reports/BETA_COUNCIL_LATEST.md` for heavier engineering work.

## Automatic experiments

The Streamlit development build supports only these temporary experiment types:

- `market_discount` — 0–25% temporary cosmetic discount
- `route_coin_bonus` — 0–15 extra completion coins on one route
- `enemy_pressure` — at most ±10 percentage points on one route
- `obstacle_pressure` — at most ±10 percentage points on one route
- `none`

No beta agent can directly edit Godot source, delete progress, spend player resources, or merge source changes.

## API budget

The default setup uses two beta councils per UTC day. With six testers, that is up to 12 beta-tester Gemini calls/day, in addition to the existing AI development-cycle budget. Change `BETA_MAX_DAILY_COUNCILS` deliberately if you want a different budget.
