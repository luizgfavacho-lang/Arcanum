"""Confere o conteudo montado por setup_content.py + import_data.py (fatia vertical).

Roda DENTRO do editor (PythonScriptPlugin). Normalmente chamado por Scripts/SetupContent.ps1:
    UnrealEditor-Cmd Arcanum.uproject -run=pythonscript -script=Scripts/Python/verify_content.py

Saida: "[Verify] OK/FALHOU <asset>: <motivo>" por asset + resumo. Termina com erro se algo falhar.
"""
import os
import re

import unreal

ROOT = "/Game/Arcanum"
INPUT = f"{ROOT}/Input"
CHARACTERS = f"{ROOT}/Characters"
CORE = f"{ROOT}/Core"
PROJECTILES = f"{ROOT}/Spells/Projectiles"
ABILITIES = f"{ROOT}/Spells/Abilities"
SPELLS = f"{ROOT}/Spells"
DATA = f"{ROOT}/Data"
MAP = f"{ROOT}/Maps/L_Sandbox"
MESH = "/Game/Characters/Mannequins/Meshes/SKM_Quinn_Simple"
ANIM_BP = "/Game/Characters/Mannequins/Anims/Unarmed/ABP_Unarmed"

INPUT_ACTIONS = {
    "IA_Move": "AXIS2D", "IA_Look": "AXIS2D", "IA_Jump": "BOOLEAN",
    **{f"IA_Spell{i}": "BOOLEAN" for i in range(1, 6)},
    "IA_CastSelected": "BOOLEAN", "IA_CycleSlot": "AXIS1D",
}
# tecla -> (acao, [modificadores]) ; "swizzle" = SwizzleAxis YXZ, "negate" = XYZ, "negate_y" = so Y
KEY_MAPPINGS = {
    "W": ("IA_Move", ["swizzle"]), "S": ("IA_Move", ["swizzle", "negate"]),
    "D": ("IA_Move", []), "A": ("IA_Move", ["negate"]),
    "Mouse2D": ("IA_Look", ["negate_y"]), "SpaceBar": ("IA_Jump", []),
    "One": ("IA_Spell1", []), "Two": ("IA_Spell2", []), "Three": ("IA_Spell3", []),
    "Four": ("IA_Spell4", []), "Five": ("IA_Spell5", []),
    "LeftMouseButton": ("IA_CastSelected", []), "MouseWheelAxis": ("IA_CycleSlot", []),
}
PROJECTILES_EXPECTED = {"BP_Proj_Fireball": "NS_Placeholder_Fire", "BP_Proj_ArcaneMissile": "NS_Placeholder_Arcane"}
ABILITIES_EXPECTED = {
    "GA_Fireball": ("/Script/ArcanumCore.ArcanumAbility_Projectile", "BP_Proj_Fireball", False),
    "GA_ArcaneMissile": ("/Script/ArcanumCore.ArcanumAbility_Projectile", "BP_Proj_ArcaneMissile", True),
    "GA_ChainLightning": ("/Script/ArcanumCore.ArcanumAbility_ChainLightning", None, False),
}
PROC_STATE_TAGS = {
    "Fireball": "State.Burning", "ArcaneMissile": "State.ArcaneCharge", "ChainLightning": "State.Paralyzed",
    "Spark": "State.Paralyzed", "BloodBlade": "State.Bleeding",
}
STARTING_SPELLS = ["Fireball", "ArcaneMissile", "ChainLightning"]
INI_EXPECTED = {
    "GlobalDefaultGameMode": f"{CORE}/BP_GameMode.BP_GameMode_C",
    "EditorStartupMap": f"{MAP}.L_Sandbox",
    "GameDefaultMap": f"{MAP}.L_Sandbox",
}

eal = unreal.EditorAssetLibrary
results = []


class Check:
    """Acumula problemas de um asset; imprime uma linha so."""

    def __init__(self, name):
        self.name, self.problems = name, []

    def expect(self, cond, msg):
        if not cond:
            self.problems.append(msg)
        return cond

    def eq(self, label, got, want):
        return self.expect(got == want, f"{label}={got!r} (esperado {want!r})")

    def __enter__(self):
        return self

    def __exit__(self, exc_type, exc, tb):
        if exc is not None:
            self.problems.append(f"excecao: {exc}")
        ok = not self.problems
        results.append(ok)
        msg = "; ".join(self.problems) if self.problems else "ok"
        line = f"[Verify] {'OK' if ok else 'FALHOU'} {self.name}: {msg}"
        if ok:
            print(line)
        else:
            unreal.log_error(line)
        return True  # excecao ja registrada


def load(path):
    if not eal.does_asset_exist(path):
        raise RuntimeError(f"{path} nao existe")
    return eal.load_asset(path)


def name_of(obj):
    return obj.get_name() if obj else None


def cdo_of(bp):
    return unreal.get_default_object(bp.generated_class())


def is_child(bp, parent_path):
    return unreal.MathLibrary.class_is_child_of(bp.generated_class(), unreal.load_class(None, parent_path))


def tag_name(tag):
    m = re.search(r'TagName="([^"]*)"', tag.export_text())
    return m.group(1) if m else ""


def key_name(key):
    return key.export_text()  # FKey exporta o nome puro ("W")


def class_name(path):
    return path.rsplit("/", 1)[-1] + "_C"


def check_mannequin(c, cdo):
    mesh = cdo.get_editor_property("mesh")
    c.eq("Mesh", name_of(mesh.get_editor_property("skeletal_mesh_asset")), "SKM_Quinn_Simple")
    loc = mesh.get_editor_property("relative_location")
    rot = mesh.get_editor_property("relative_rotation")
    c.expect(abs(loc.z + 90) < 0.01, f"Mesh.Z={loc.z}")
    c.expect(abs(rot.yaw + 90) < 0.01, f"Mesh.Yaw={rot.yaw}")
    c.eq("AnimClass", name_of(mesh.get_editor_property("anim_class")), "ABP_Unarmed_C")


def verify_mannequin():
    with Check("Manequim (/Game/Characters)") as c:
        c.expect(load(MESH) is not None, "SKM_Quinn_Simple nao carrega")
        c.expect(load(ANIM_BP).generated_class() is not None, "ABP_Unarmed sem classe gerada")


def verify_input():
    for name, value_type in INPUT_ACTIONS.items():
        with Check(name) as c:
            c.eq("ValueType", load(f"{INPUT}/{name}").get_editor_property("value_type"),
                 getattr(unreal.InputActionValueType, value_type))

    with Check("IMC_Default") as c:
        imc = load(f"{INPUT}/IMC_Default")
        mappings = list(imc.get_editor_property("default_key_mappings").get_editor_property("mappings"))
        c.eq("mapeamentos", len(mappings), len(KEY_MAPPINGS))
        for mapping in mappings:
            key = key_name(mapping.get_editor_property("key"))
            if not c.expect(key in KEY_MAPPINGS, f"tecla inesperada {key}"):
                continue
            action, mods = KEY_MAPPINGS[key]
            c.eq(f"{key}.Action", name_of(mapping.get_editor_property("action")), action)
            got = []
            for m in mapping.get_editor_property("modifiers"):
                if isinstance(m, unreal.InputModifierSwizzleAxis):
                    got.append("swizzle" if m.get_editor_property("order") == unreal.InputAxisSwizzle.YXZ else "swizzle?")
                elif isinstance(m, unreal.InputModifierNegate):
                    got.append({(True, True, True): "negate", (False, True, False): "negate_y"}.get((m.x, m.y, m.z), "negate?"))
                else:
                    got.append(name_of(m.get_class()))
            c.eq(f"{key}.Modifiers", got, mods)


def verify_characters():
    with Check("BP_PlayerCharacter") as c:
        bp = load(f"{CHARACTERS}/BP_PlayerCharacter")
        c.expect(is_child(bp, "/Script/Arcanum.ArcanumPlayerCharacter"), "pai nao e ArcanumPlayerCharacter")
        cdo = cdo_of(bp)
        check_mannequin(c, cdo)
        c.eq("DefaultMappingContext", name_of(cdo.get_editor_property("default_mapping_context")), "IMC_Default")
        for prop, want in [("move_action", "IA_Move"), ("look_action", "IA_Look"), ("jump_action", "IA_Jump"),
                           ("cast_selected_action", "IA_CastSelected"), ("cycle_slot_action", "IA_CycleSlot")]:
            c.eq(prop, name_of(cdo.get_editor_property(prop)), want)
        c.eq("SpellSlotActions", [name_of(a) for a in cdo.get_editor_property("spell_slot_actions")],
             [f"IA_Spell{i}" for i in range(1, 6)])

    with Check("BP_Enemy_Dummy") as c:
        bp = load(f"{CHARACTERS}/BP_Enemy_Dummy")
        c.expect(is_child(bp, "/Script/Arcanum.ArcanumEnemyCharacter"), "pai nao e ArcanumEnemyCharacter")
        cdo = cdo_of(bp)
        check_mannequin(c, cdo)
        row = cdo.get_editor_property("enemy_row")
        c.eq("EnemyRow.DataTable", name_of(row.get_editor_property("data_table")), "DT_Enemies")
        c.eq("EnemyRow.RowName", str(row.get_editor_property("row_name")), "SkeletonMage")


def verify_core():
    with Check("BP_PlayerState") as c:
        bp = load(f"{CORE}/BP_PlayerState")
        c.expect(is_child(bp, "/Script/Arcanum.ArcanumPlayerState"), "pai nao e ArcanumPlayerState")
        spells = cdo_of(bp).get_editor_property("spellbook").get_editor_property("starting_spells")
        c.eq("Spellbook.StartingSpells", [name_of(s) for s in spells], [f"DA_Spell_{s}" for s in STARTING_SPELLS])

    with Check("BP_GameMode") as c:
        bp = load(f"{CORE}/BP_GameMode")
        c.expect(is_child(bp, "/Script/Arcanum.ArcanumGameMode"), "pai nao e ArcanumGameMode")
        cdo = cdo_of(bp)
        c.eq("DefaultPawnClass", name_of(cdo.get_editor_property("default_pawn_class")), "BP_PlayerCharacter_C")
        c.eq("PlayerStateClass", name_of(cdo.get_editor_property("player_state_class")), "BP_PlayerState_C")


def find_component_template(bp, var_name):
    sds = unreal.get_engine_subsystem(unreal.SubobjectDataSubsystem)
    lib = unreal.SubobjectDataBlueprintFunctionLibrary
    for handle in sds.k2_gather_subobject_data_for_blueprint(bp):
        data = lib.get_data(handle)
        if str(lib.get_variable_name(data)) == var_name:
            return lib.get_object_for_blueprint(data, bp)
    return None


def verify_projectiles():
    for name, ns in PROJECTILES_EXPECTED.items():
        with Check(ns) as c:
            c.expect(isinstance(load(f"{PROJECTILES}/{ns}"), unreal.NiagaraSystem), "nao e NiagaraSystem")
        with Check(name) as c:
            bp = load(f"{PROJECTILES}/{name}")
            c.expect(is_child(bp, "/Script/ArcanumCore.ArcanumProjectile"), "pai nao e ArcanumProjectile")
            trail = find_component_template(bp, "Trail")
            if c.expect(isinstance(trail, unreal.NiagaraComponent), "sem componente Niagara 'Trail'"):
                c.eq("Trail.Asset", name_of(trail.get_editor_property("asset")), ns)


def verify_abilities():
    for name, (parent, projectile, homing) in ABILITIES_EXPECTED.items():
        with Check(name) as c:
            bp = load(f"{ABILITIES}/{name}")
            c.expect(is_child(bp, parent), f"pai nao e {parent.rsplit('.', 1)[-1]}")
            if projectile:
                cdo = cdo_of(bp)
                c.eq("ProjectileClass", name_of(cdo.get_editor_property("projectile_class")), f"{projectile}_C")
                c.eq("bHoming", cdo.get_editor_property("homing"), homing)


def verify_spells():
    for spell_id, tag in PROC_STATE_TAGS.items():
        with Check(f"DA_Spell_{spell_id}") as c:
            da = load(f"{SPELLS}/DA_Spell_{spell_id}")
            c.eq("ProcStateTag", tag_name(da.get_editor_property("proc_state_tag")), tag)
            if f"GA_{spell_id}" in ABILITIES_EXPECTED:
                c.eq("AbilityClass", name_of(da.get_editor_property("ability_class")), f"GA_{spell_id}_C")


def verify_level():
    with Check("L_Sandbox") as c:
        load(MAP)
        les = unreal.get_editor_subsystem(unreal.LevelEditorSubsystem)
        c.expect(les.load_level(MAP), "load_level falhou")
        actors = unreal.get_editor_subsystem(unreal.EditorActorSubsystem).get_all_level_actors()
        counts = {}
        for a in actors:
            counts[a.get_class().get_name()] = counts.get(a.get_class().get_name(), 0) + 1
        for cls in ["DirectionalLight", "SkyAtmosphere", "SkyLight", "ExponentialHeightFog", "PlayerStart"]:
            c.eq(cls, counts.get(cls, 0), 1)
        floor = [a for a in actors if a.get_actor_label() == "Floor"]
        if c.expect(len(floor) == 1, "sem chao 'Floor'"):
            ext = floor[0].get_actor_bounds(False)[1]
            c.expect(abs(ext.x * 2 - 10000) < 1 and abs(ext.y * 2 - 10000) < 1, f"chao {ext.x * 2 / 100:.0f}x{ext.y * 2 / 100:.0f} m")
        starts = [a for a in actors if isinstance(a, unreal.PlayerStart)]
        dummies = [a for a in actors if a.get_class().get_name() == "BP_Enemy_Dummy_C"]
        c.eq("BP_Enemy_Dummy", len(dummies), 5)
        if starts and dummies:
            origin = starts[0].get_actor_location()
            dist = [(d.get_actor_location() - origin).length() / 100 for d in dummies]
            c.expect(all(12 <= d <= 20 for d in dist), f"dummies a {min(dist):.1f}-{max(dist):.1f} m do PlayerStart")


def verify_ini():
    with Check("DefaultEngine.ini") as c:
        path = os.path.join(unreal.Paths.convert_relative_path_to_full(unreal.Paths.project_config_dir()), "DefaultEngine.ini")
        with open(path, encoding="utf-8") as f:
            text = f.read()
        section = re.search(r"^\[/Script/EngineSettings\.GameMapsSettings\]\n(.*?)(?=^\[|\Z)", text, re.S | re.M)
        body = section.group(1) if section else ""
        for key, value in INI_EXPECTED.items():
            c.expect(re.search(rf"^{key}={re.escape(value)}$", body, re.M) is not None, f"{key} != {value}")


def main():
    for fn in [verify_mannequin, verify_input, verify_characters, verify_core, verify_projectiles,
               verify_abilities, verify_spells, verify_level, verify_ini]:
        fn()
    failed = results.count(False)
    print(f"[Verify] Resumo: {len(results) - failed}/{len(results)} OK")
    if failed:
        raise RuntimeError(f"[Verify] {failed} verificacao(oes) falharam")


main()
