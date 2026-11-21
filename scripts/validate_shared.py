#!/usr/bin/env python3
"""Validates shared Leseteppich and Würfellesen JSON files for iOS and Android parity."""

import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent


def validate_carpets() -> None:
    path = ROOT / "shared" / "content" / "leseteppiche.json"
    data = json.loads(path.read_text(encoding="utf-8"))
    assert data.get("schemaVersion") == 1, "Unsupported schemaVersion in leseteppiche.json"
    carpets = data.get("carpets", [])
    assert len(carpets) >= 1, "At least one carpet required"

    seen_carpet_ids = set()
    seen_tile_ids = set()
    for carpet in carpets:
        cid = carpet["id"]
        assert cid not in seen_carpet_ids, f"Duplicate carpet id: {cid}"
        seen_carpet_ids.add(cid)
        tiles = carpet["tiles"]
        assert len(tiles) >= 4, f"Carpet {cid} needs at least 4 tiles"
        for tile in tiles:
            tid = tile["id"]
            assert tid not in seen_tile_ids, f"Duplicate tile id: {tid}"
            seen_tile_ids.add(tid)
            joined = "".join(tile["syllables"])
            assert joined == tile["display"], (
                f"Tile {tid}: syllables '{joined}' != display '{tile['display']}'"
            )
            assert tile["spokenText"].strip(), f"Tile {tid}: spokenText must not be empty"
    print(f"OK: {len(carpets)} Leseteppiche, {len(seen_tile_ids)} tiles validated.")


def validate_dice_boards() -> None:
    path = ROOT / "shared" / "content" / "wuerfellesen.json"
    data = json.loads(path.read_text(encoding="utf-8"))
    assert data.get("schemaVersion") == 1, "Unsupported schemaVersion in wuerfellesen.json"
    boards = data.get("boards", [])
    assert len(boards) >= 1, "At least one dice board required"

    for board in boards:
        columns = board["columns"]
        assert len(columns) == 6, f"Board {board['id']} must have 6 dice columns"
        dice_values = [col["diceValue"] for col in columns]
        assert dice_values == [1, 2, 3, 4, 5, 6], f"Invalid dice values in {board['id']}"
        row_counts = {len(col["cells"]) for col in columns}
        assert len(row_counts) == 1, f"All columns in {board['id']} must have equal height"
        for col in columns:
            for cell in col["cells"]:
                assert cell["spokenText"].strip(), f"Cell {cell['id']} spokenText empty"
    print(f"OK: {len(boards)} Würfellesen board(s) validated.")


def validate_test_vectors() -> None:
    path = ROOT / "shared" / "test-vectors" / "phonetic_matching.json"
    data = json.loads(path.read_text(encoding="utf-8"))
    cases = data.get("cases", [])
    assert len(cases) >= 5, "Expected at least 5 phonetic test vectors"
    for case in cases:
        assert case["strictness"] in {"gentle", "normal", "strict"}
        assert isinstance(case["spoken"], list) and len(case["spoken"]) >= 1
    print(f"OK: {len(cases)} phonetic test vectors validated.")


if __name__ == "__main__":
    try:
        validate_carpets()
        validate_dice_boards()
        validate_test_vectors()
    except Exception as exc:
        print(f"Validation failed: {exc}", file=sys.stderr)
        sys.exit(1)
