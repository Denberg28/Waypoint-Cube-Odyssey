# Runtime Module Standard

Gameplay domains use a two-file convention:

- `<domain>_catalog.gd`: static definitions and balance data.
- `<domain>_service.gd`: domain rules and state mutations.

Shared callers should use the stable facades in `scripts/catalog.gd` and `scripts/state.gd` unless direct module access is explicitly appropriate.

Do not add new pet, marketplace, enemy, or road rules back into `state.gd` or `catalog.gd`. Add them to the owning module and expose only the necessary wrapper.
