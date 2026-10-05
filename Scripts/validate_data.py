#!/usr/bin/env python3
"""Valida os dados de balanceamento (Data/*.csv) SEM abrir a Unreal.

- Colunas de cada CSV == UPROPERTYs do struct C++ correspondente.
- Enums, faixas (chances 0..1, valores >= 0), ids cruzados (String Table, tags .ini).
- Curva de niveis == ArcanumProgressionMath; arvore de talentos com 5 nos por ramo.
- Faixas de tier do GDD (avisos; --strict transforma em erro).

Saida curta de proposito (economia de tokens). Codigo de saida 1 se houver erro.
Uso: python3 Scripts/validate_data.py [--strict]
"""
import csv
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DATA = ROOT / "Data"
ROWS = ROOT / "Source/ArcanumCore/Public/Data"

TABLES = {
    "Spells.csv": "ArcanumSpellRow.h",
    "Levels.csv": "ArcanumLevelRow.h",
    "Enemies.csv": "ArcanumEnemyRow.h",
    "Runes.csv": "ArcanumRuneRow.h",
    "Talents.csv": "ArcanumTalentRow.h",
    "Passives.csv": "ArcanumPassiveRow.h",
    "Combos.csv": "ArcanumComboRow.h",
}
SCHOOLS = {"None", "Electricity", "Fire", "Energy", "Necromancy", "Blood"}
# Faixas do GDD por tier: (custo de mana, dano, recarga)
TIER_RANGES = {1: ((10, 20), (4, 8), (1, 3)), 2: ((30, 50), (10, 18), (6, 12)), 3: ((80, 150), (25, 50), (30, 90))}

errors, warnings = [], []


def struct_fields(header: Path):
    text = header.read_text(encoding="utf-8")
    return re.findall(r"UPROPERTY\([^)]*\)\s*\n\s*[\w:<>]+\s+(\w+)", text)


def load(name):
    with open(DATA / name, newline="", encoding="utf-8") as f:
        return list(csv.DictReader(f))


def num(row, key):
    try:
        return float(row[key])
    except (TypeError, ValueError):
        errors.append(f"{row.get('Name')}: {key}='{row.get(key)}' nao e numero")
        return 0.0


def check_columns():
    for csv_name, header in TABLES.items():
        with open(DATA / csv_name, newline="", encoding="utf-8") as f:
            cols = next(csv.reader(f))
        expected = struct_fields(ROWS / header)
        if cols[0] != "Name":
            errors.append(f"{csv_name}: primeira coluna deve ser Name")
        missing = [c for c in expected if c not in cols]
        extra = [c for c in cols[1:] if c not in expected]
        if missing:
            errors.append(f"{csv_name}: faltam colunas {missing}")
        if extra:
            errors.append(f"{csv_name}: colunas sem campo no struct {extra}")


def check_spells(strict):
    spells = load("Spells.csv")
    ids = [s["Name"] for s in spells]
    if len(ids) != len(set(ids)):
        errors.append("Spells.csv: ids duplicados")
    for s in spells:
        n = s["Name"]
        if s["School"] not in SCHOOLS - {"None"}:
            errors.append(f"{n}: escola invalida '{s['School']}'")
        for key in ("ProcChance",):
            if not 0 <= num(s, key) <= 1:
                errors.append(f"{n}: {key} fora de 0..1")
        for key in ("ManaCost", "Cooldown", "Damage", "RangeMeters", "RadiusMeters", "DurationSeconds", "ManaPerSecond"):
            if num(s, key) < 0:
                errors.append(f"{n}: {key} negativo")
        if s["bChanneled"] == "True" and num(s, "ManaPerSecond") <= 0:
            errors.append(f"{n}: canalizada sem ManaPerSecond")
        if num(s, "ProcChance") > 0 and num(s, "ProcDurationSeconds") <= 0:
            errors.append(f"{n}: ProcChance sem ProcDurationSeconds")

        # Fora da checagem de faixa: canalizadas, zonas/auras com tick e excecoes marcadas no CSV.
        tier = int(num(s, "Tier"))
        is_zone = num(s, "TickIntervalSeconds") > 0 and num(s, "DurationSeconds") > 0
        exempt = "[excecao" in s["Notes"]
        if tier in TIER_RANGES and s["bChanneled"] != "True" and not is_zone and not exempt:
            (cmin, cmax), (dmin, dmax), (rmin, rmax) = TIER_RANGES[tier]
            cost = num(s, "ManaCost")
            if cost and not cmin <= cost <= cmax:
                warnings.append(f"{n} T{tier}: custo {cost:g} fora de {cmin}-{cmax}")
            cd = num(s, "Cooldown")
            if not rmin <= cd <= rmax:
                warnings.append(f"{n} T{tier}: recarga {cd:g} fora de {rmin}-{rmax}")
            dmg = num(s, "Damage") * max(num(s, "Count"), 1)
            if dmg and not dmin <= dmg <= dmax:
                warnings.append(f"{n} T{tier}: dano total {dmg:g} fora de {dmin}-{dmax}")

    # Ids cruzados: String Table e tags
    with open(ROOT / "Content/Text/ST_Spells.csv", newline="", encoding="utf-8") as f:
        keys = {r["Key"] for r in csv.DictReader(f)}
    tags = (ROOT / "Config/Tags/ArcanumSpells.ini").read_text(encoding="utf-8")
    for n in ids:
        for k in (f"{n}.Name", f"{n}.Desc"):
            if k not in keys:
                errors.append(f"ST_Spells.csv: falta {k}")
        for t in (f"Cooldown.Spell.{n}", f"GameplayCue.Spell.{n}.Cast", f"GameplayCue.Spell.{n}.Impact"):
            if f'"{t}"' not in tags:
                errors.append(f"ArcanumSpells.ini: falta tag {t}")
    if strict:
        errors.extend(warnings)
        warnings.clear()


def check_levels():
    levels = load("Levels.csv")
    if len(levels) != 50:
        errors.append(f"Levels.csv: {len(levels)} niveis (esperado 50)")
    total_sp = 0
    for row in levels:
        lvl = int(row["Name"])
        expected = 0 if lvl >= 50 else round(50 * lvl ** 1.5)
        if int(num(row, "XPToNext")) != expected:
            errors.append(f"Levels.csv nivel {lvl}: XPToNext {row['XPToNext']} != {expected} (ArcanumProgressionMath)")
        total_sp += int(num(row, "SkillPoints"))
    if total_sp != 10:
        errors.append(f"Levels.csv: {total_sp} pontos de habilidade (esperado 10)")


def check_talents():
    talents = load("Talents.csv")
    ini = (ROOT / "Config/Tags/ArcanumTalents.ini").read_text(encoding="utf-8")
    required = {1: 0, 2: 0, 3: 1, 4: 1, 5: 3}
    by_school = {}
    for t in talents:
        by_school.setdefault(t["School"], []).append(int(num(t, "Node")))
        node = int(num(t, "Node"))
        if int(num(t, "RequiredPointsInBranch")) != required.get(node, -1):
            errors.append(f"Talento {t['Name']}: no {node} deveria exigir {required.get(node)}")
        if f'"{t["GrantedTag"]}"' not in ini:
            errors.append(f"ArcanumTalents.ini: falta {t['GrantedTag']}")
    for school in SCHOOLS - {"None"}:
        if sorted(by_school.get(school, [])) != [1, 2, 3, 4, 5]:
            errors.append(f"Talentos de {school}: nos {sorted(by_school.get(school, []))} (esperado 1-5)")


def check_misc():
    for name, school_col in (("Enemies.csv", "School"), ("Runes.csv", "School"), ("Combos.csv", "TriggerSchool")):
        for row in load(name):
            if row[school_col] not in SCHOOLS:
                errors.append(f"{name} {row['Name']}: escola invalida '{row[school_col]}'")
    for row in load("Enemies.csv"):
        if num(row, "MaxHealth") <= 0:
            errors.append(f"Enemies.csv {row['Name']}: MaxHealth <= 0")
    for row in load("Passives.csv"):
        if not 0 <= num(row, "Chance") <= 1:
            errors.append(f"Passives.csv {row['Name']}: Chance fora de 0..1")


def main():
    strict = "--strict" in sys.argv
    check_columns()
    if not errors:
        check_spells(strict)
        check_levels()
        check_talents()
        check_misc()
    for w in warnings:
        print(f"AVISO  {w}")
    for e in errors:
        print(f"ERRO   {e}")
    print(f"validate_data: {len(errors)} erro(s), {len(warnings)} aviso(s)")
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main())
