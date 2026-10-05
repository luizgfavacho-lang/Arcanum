"""Importa Data/*.csv para DataTables e cria/atualiza os Data Assets de magia.

Roda DENTRO do editor (PythonScriptPlugin). Normalmente chamado por Scripts/ImportData.ps1:
    UnrealEditor-Cmd Arcanum.uproject -run=pythonscript -script=Scripts/Python/import_data.py

- DT_<Tabela> em /Game/Arcanum/Data (cria se nao existir; reimporta sempre).
- DA_Spell_<Id> em /Game/Arcanum/Spells para cada linha de Spells.csv: preenche SpellId e
  Balance. AbilityClass e preenchida se existir /Game/Arcanum/Spells/Abilities/GA_<Id>.
  Tags de recarga/cue sao derivadas do SpellId em C++ (nao precisam ser setadas).
Saida curta: uma linha por tabela + resumo.
"""
import csv
import os

import unreal

PROJECT_DIR = unreal.Paths.convert_relative_path_to_full(unreal.Paths.project_dir())
DATA_DIR = os.path.join(PROJECT_DIR, "Data")
DATA_PATH = "/Game/Arcanum/Data"
SPELLS_PATH = "/Game/Arcanum/Spells"
ABILITIES_PATH = "/Game/Arcanum/Spells/Abilities"

# csv -> (asset, struct)
TABLES = [
    ("Spells.csv", "DT_Spells", "ArcanumSpellRow"),
    ("Levels.csv", "DT_Levels", "ArcanumLevelRow"),
    ("Enemies.csv", "DT_Enemies", "ArcanumEnemyRow"),
    ("Runes.csv", "DT_Runes", "ArcanumRuneRow"),
    ("Talents.csv", "DT_Talents", "ArcanumTalentRow"),
    ("Passives.csv", "DT_Passives", "ArcanumPassiveRow"),
    ("Combos.csv", "DT_Combos", "ArcanumComboRow"),
]

asset_tools = unreal.AssetToolsHelpers.get_asset_tools()
eal = unreal.EditorAssetLibrary
failures = 0


def load_or_create(path, name, asset_class, factory):
    full = f"{path}/{name}"
    if eal.does_asset_exist(full):
        return eal.load_asset(full)
    return asset_tools.create_asset(name, path, asset_class, factory)


def import_table(csv_name, asset_name, struct_name):
    global failures
    struct = unreal.load_object(None, f"/Script/ArcanumCore.{struct_name}")
    if struct is None:
        unreal.log_error(f"[ImportData] struct {struct_name} nao encontrado (compilou o C++?)")
        failures += 1
        return None
    factory = unreal.DataTableFactory()
    factory.set_editor_property("struct", struct)
    table = load_or_create(DATA_PATH, asset_name, unreal.DataTable, factory)
    ok = unreal.DataTableFunctionLibrary.fill_data_table_from_csv_file(table, os.path.join(DATA_DIR, csv_name))
    eal.save_loaded_asset(table, only_if_is_dirty=False)
    rows = len(unreal.DataTableFunctionLibrary.get_data_table_row_names(table))
    print(f"[ImportData] {asset_name}: {'OK' if ok else 'FALHOU'} ({rows} linhas)")
    if not ok:
        failures += 1
    return table


def sync_spell_assets(spells_table):
    definition_class = unreal.load_class(None, "/Script/ArcanumCore.ArcanumSpellDefinition")
    factory = unreal.DataAssetFactory()
    factory.set_editor_property("data_asset_class", definition_class)

    with open(os.path.join(DATA_DIR, "Spells.csv"), newline="", encoding="utf-8") as f:
        spell_ids = [row["Name"] for row in csv.DictReader(f)]

    created, missing_ability = 0, []
    for spell_id in spell_ids:
        name = f"DA_Spell_{spell_id}"
        existed = eal.does_asset_exist(f"{SPELLS_PATH}/{name}")
        asset = load_or_create(SPELLS_PATH, name, definition_class, factory)
        asset.set_editor_property("spell_id", spell_id)
        handle = unreal.DataTableRowHandle()
        handle.set_editor_property("data_table", spells_table)
        handle.set_editor_property("row_name", spell_id)
        asset.set_editor_property("balance", handle)

        ability_path = f"{ABILITIES_PATH}/GA_{spell_id}.GA_{spell_id}_C"
        ability_class = unreal.load_class(None, ability_path) if eal.does_asset_exist(f"{ABILITIES_PATH}/GA_{spell_id}") else None
        if ability_class:
            asset.set_editor_property("ability_class", ability_class)
        elif asset.get_editor_property("ability_class") is None:
            missing_ability.append(spell_id)

        eal.save_loaded_asset(asset, only_if_is_dirty=False)
        created += 0 if existed else 1

    print(f"[ImportData] Spells: {len(spell_ids)} Data Assets ({created} novos); sem AbilityClass: {len(missing_ability)}")


def main():
    tables = {asset: import_table(csv_name, asset, struct) for csv_name, asset, struct in TABLES}
    if tables.get("DT_Spells") is not None:
        sync_spell_assets(tables["DT_Spells"])
    print(f"[ImportData] Resumo: {len(TABLES) - failures}/{len(TABLES)} tabelas OK")


main()
