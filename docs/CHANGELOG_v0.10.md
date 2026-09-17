# Waypoint: Cube Odyssey v0.10

## Right-side status rail
- Expanded the right status panel from a compact card into a wider, near-full-height information rail.
- Preserved character stats, equipment, consumables, challenge/relic information, and adventure messages.
- Reduced message-feed expansion so the new feedback controls remain easy to reach.

## AI Game Master feedback foundation
- Added a dedicated AI Game Master feedback chat-style section.
- Added multiline player input and a Send Feedback action.
- Added recent-feedback history with stage, threat, and game-mode context.
- Added a local structured JSONL queue at `user://waypoint_ai_gm_feedback.jsonl`.
- Each feedback entry stores a gameplay snapshot for future AI analysis and game-update planning.
- No network connection or AI service is used yet; the UI clearly reports local queued status.

## Crossroads UI
- Moved route selection from the left side to the same centered bottom popup lane used by gameplay dialogs.
- Increased visual consistency between crossroads, reward, event, fishing, and fight cards.

## Save compatibility
- Gameplay save schema remains version 8 because AI feedback is stored separately from player progression.
