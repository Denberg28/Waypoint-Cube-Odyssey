# Runtime Module Standard

Gameplay domains use a two-file convention:

- `<domain>_catalog.gd`: static definitions and balance data.
- `<domain>_service.gd`: domain rules and state mutations.

Shared callers should use the stable facades in `scripts/catalog.gd` and `scripts/state.gd` unless direct module access is explicitly appropriate.

Do not add new pet, marketplace, enemy, or road rules back into `state.gd` or `catalog.gd`. Add them to the owning module and expose only the necessary wrapper.


## Progression module

- `progression_catalog.gd` owns Camp Renown thresholds, objective rewards, objective templates, and rare-event frequency.
- `progression_service.gd` owns objective progress, reward claims, Camp Level recalculation, and rare-event resolution/placement.

Do not add road-objective or Camp Renown rules back into `state.gd`; expose them through the State facade.
