#!/usr/bin/env python3
"""Gera roblox/src/shared/Data/*.luau a partir de Data/*.csv e Content/Text/ST_Spells.csv.

Os CSV continuam sendo a fonte de verdade dos numeros (validados por Scripts/validate_data.py).
NAO edite os .luau gerados: edite o CSV e rode `python3 roblox/tools/gen_data.py`.
"""
import csv
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "roblox/src/shared/Data"
TABLES = ["Spells", "Levels", "Enemies", "Runes", "Talents", "Passives", "Combos"]
HEADER = "-- GERADO por roblox/tools/gen_data.py a partir de {src}. NAO EDITE: mude o CSV e rode o gerador.\n"
IDENT = re.compile(r"^[A-Za-z_][A-Za-z0-9_]*$")


def lua_value(text: str) -> str:
    if text in ("True", "False"):
        return text.lower()
    try:
        number = float(text)
        return repr(int(number)) if number.is_integer() else repr(number)
    except ValueError:
        return '"' + text.replace("\\", "\\\\").replace('"', '\\"') + '"'


def lua_key(key: str) -> str:
    if key.isdigit():
        return f"[{key}]"
    return key if IDENT.match(key) else f'["{key}"]'


def write_table(name: str, rows, key_col: str, src: str):
    lines = ["--!strict", HEADER.format(src=src), "return table.freeze({"]
    for row in rows:
        key = row[key_col]
        fields = ", ".join(
            f"{lua_key(k)} = {lua_value(v)}" for k, v in row.items() if k != key_col
        )
        lines.append(f"\t{lua_key(key)} = table.freeze({{ {fields} }}),")
    lines.append("})")
    (OUT / f"{name}.luau").write_text("\n".join(lines) + "\n", encoding="utf-8")


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    for name in TABLES:
        with open(ROOT / "Data" / f"{name}.csv", newline="", encoding="utf-8") as f:
            rows = list(csv.DictReader(f))
        write_table(name, rows, "Name", f"Data/{name}.csv")

    # Textos: { Fireball = { Name = "...", Desc = "..." } }
    texts = {}
    with open(ROOT / "Content/Text/ST_Spells.csv", newline="", encoding="utf-8") as f:
        for row in csv.DictReader(f):
            spell, field = row["Key"].rsplit(".", 1)
            texts.setdefault(spell, {})[field] = row["SourceString"]
    lines = ["--!strict", HEADER.format(src="Content/Text/ST_Spells.csv"), "return table.freeze({"]
    for spell, fields in texts.items():
        body = ", ".join(f"{k} = {lua_value(v)}" for k, v in fields.items())
        lines.append(f"\t{spell} = table.freeze({{ {body} }}),")
    lines.append("})")
    (OUT / "SpellText.luau").write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(f"gen_data: {len(TABLES) + 1} modulos em {OUT.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
