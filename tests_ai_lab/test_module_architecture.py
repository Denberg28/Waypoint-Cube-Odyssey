from __future__ import annotations

from pathlib import Path


MODULE_ROOT = Path("scripts/modules")


def test_domain_modules_exist_with_catalog_service_pattern():
    expected = {
        "core": ["core_catalog.gd"],
        "pets": ["pet_catalog.gd", "pet_service.gd"],
        "marketplace": ["marketplace_catalog.gd", "marketplace_service.gd"],
        "road": ["road_catalog.gd", "road_service.gd"],
        "enemy": ["enemy_catalog.gd", "enemy_service.gd"],
    }
    for module, files in expected.items():
        for filename in files:
            assert (MODULE_ROOT / module / filename).is_file()


def test_catalog_is_a_compatibility_facade_not_domain_storage():
    catalog = Path("scripts/catalog.gd").read_text(encoding="utf-8")

    for preload in [
        "core/core_catalog.gd",
        "pets/pet_catalog.gd",
        "marketplace/marketplace_catalog.gd",
        "road/road_catalog.gd",
        "enemy/enemy_catalog.gd",
    ]:
        assert preload in catalog

    # Large domain definitions belong to their owning modules now.
    assert '"Moss Trail"' not in catalog
    assert '"Moss Slime"' not in catalog
    assert '"Forest Sage"' not in catalog


def test_state_is_a_stable_facade_for_domain_services():
    state = Path("scripts/state.gd").read_text(encoding="utf-8")

    for preload in [
        "pets/pet_service.gd",
        "marketplace/marketplace_service.gd",
        "road/road_service.gd",
        "enemy/enemy_service.gd",
    ]:
        assert preload in state

    expected_delegates = [
        "return PetService.feed_cat(self)",
        "return MarketplaceService.buy_cosmetic(self, id)",
        "return MarketplaceService.buy_cat_food(self, quantity)",
        "return RoadService.roll_environment(self, route)",
        "return EnemyService.enemy_visual_variant(self, kind, row, lane, elite)",
    ]
    for delegate in expected_delegates:
        assert delegate in state


def test_module_services_do_not_depend_on_main_or_world():
    for path in MODULE_ROOT.glob("*/*_service.gd"):
        source = path.read_text(encoding="utf-8")
        assert 'res://scripts/main.gd' not in source
        assert 'res://scripts/world.gd' not in source
