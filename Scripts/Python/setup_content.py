"""Monta o conteudo de editor da fatia vertical (Docs/04-FatiaVertical.md §4) sem interface grafica.

Roda DENTRO do editor (PythonScriptPlugin). Normalmente chamado por Scripts/SetupContent.ps1:
    UnrealEditor-Cmd Arcanum.uproject -run=pythonscript -script=Scripts/Python/setup_content.py

Idempotente: cria o que falta e reaplica as propriedades no que ja existe.
Fases (variavel de ambiente ARCANUM_SETUP_PHASE, padrao "all"):
  pre  - input, Blueprints, projeteis, abilities, nivel e Config/DefaultEngine.ini
         (precisa existir ANTES do import_data.py, que liga AbilityClass por nome GA_<Id>).
  post - o que depende dos assets do import_data.py: ProcStateTag dos DA_Spell_*,
         StartingSpells do BP_PlayerState e EnemyRow do BP_Enemy_Dummy.
  all  - pre + post (post e pulado com aviso se os DT/DA ainda nao existirem).
Pre-requisito: /Game/Characters/Mannequins copiado do template (SetupContent.ps1 faz isso).
Saida curta: uma linha "[Setup] ..." por asset.
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
NIAGARA_TEMPLATE = "/Niagara/DefaultAssets/Templates/Systems/FountainLightweight"

# Nome -> tipo de valor
INPUT_ACTIONS = {
    "IA_Move": "AXIS2D",
    "IA_Look": "AXIS2D",
    "IA_Jump": "BOOLEAN",
    **{f"IA_Spell{i}": "BOOLEAN" for i in range(1, 6)},
    "IA_CastSelected": "BOOLEAN",
    "IA_CycleSlot": "AXIS1D",
}

# (tecla, acao, modificadores) ; modificadores: "swizzle" (YXZ), "negate" (XYZ), "negate_y"
KEY_MAPPINGS = [
    ("W", "IA_Move", ["swizzle"]),
    ("S", "IA_Move", ["swizzle", "negate"]),
    ("D", "IA_Move", []),
    ("A", "IA_Move", ["negate"]),
    ("Mouse2D", "IA_Look", ["negate_y"]),
    ("SpaceBar", "IA_Jump", []),
    ("One", "IA_Spell1", []),
    ("Two", "IA_Spell2", []),
    ("Three", "IA_Spell3", []),
    ("Four", "IA_Spell4", []),
    ("Five", "IA_Spell5", []),
    ("LeftMouseButton", "IA_CastSelected", []),
    ("MouseWheelAxis", "IA_CycleSlot", []),
]

# nome: sistema Niagara do rastro. A cor (Fire laranja, Arcane violeta) fica no modulo do emissor,
# que o Python nao alcanca: ajuste manual no editor (Docs/04 §4).
PROJECTILE_BPS = {
    "BP_Proj_Fireball": "NS_Placeholder_Fire",
    "BP_Proj_ArcaneMissile": "NS_Placeholder_Arcane",
}

ABILITY_BPS = {
    # nome: (classe pai, projetil ou None, teleguiado)
    "GA_Fireball": ("/Script/ArcanumCore.ArcanumAbility_Projectile", "BP_Proj_Fireball", False),
    "GA_ArcaneMissile": ("/Script/ArcanumCore.ArcanumAbility_Projectile", "BP_Proj_ArcaneMissile", True),
    "GA_ChainLightning": ("/Script/ArcanumCore.ArcanumAbility_ChainLightning", None, False),
}

PROC_STATE_TAGS = {
    "Fireball": "State.Burning",
    "ArcaneMissile": "State.ArcaneCharge",
    "ChainLightning": "State.Paralyzed",
    "Spark": "State.Paralyzed",
    "BloodBlade": "State.Bleeding",
}
STARTING_SPELLS = ["Fireball", "ArcaneMissile", "ChainLightning"]
ENEMY_ROW = ("DT_Enemies", "SkeletonMage")

NUM_DUMMIES = 5
DUMMY_DISTANCE = 1500.0  # cm (~15 m do PlayerStart)

INI_SETTINGS = {
    "[/Script/EngineSettings.GameMapsSettings]": {
        "GlobalDefaultGameMode": f"{CORE}/BP_GameMode.BP_GameMode_C",
        "EditorStartupMap": f"{MAP}.L_Sandbox",
        "GameDefaultMap": f"{MAP}.L_Sandbox",
    },
}

asset_tools = unreal.AssetToolsHelpers.get_asset_tools()
eal = unreal.EditorAssetLibrary
failures = []


def log(name, msg):
    print(f"[Setup] {name}: {msg}")


def fail(name, msg):
    failures.append(name)
    unreal.log_error(f"[Setup] FALHOU {name}: {msg}")


def load_or_create(path, name, asset_class, factory):
    """Retorna (asset, criado_agora)."""
    full = f"{path}/{name}"
    if eal.does_asset_exist(full):
        return eal.load_asset(full), False
    return asset_tools.create_asset(name, path, asset_class, factory), True


def save(asset):
    eal.save_loaded_asset(asset, only_if_is_dirty=False)


def load_blueprint(path, name, parent_path):
    """Cria (ou carrega) um Blueprint com o pai dado. Retorna (bp, criado_agora)."""
    parent = unreal.load_class(None, parent_path)
    if parent is None:
        raise RuntimeError(f"classe pai {parent_path} nao encontrada (compilou o C++?)")
    full = f"{path}/{name}"
    if eal.does_asset_exist(full):
        bp = eal.load_asset(full)
        if not unreal.MathLibrary.class_is_child_of(bp.generated_class(), parent):
            unreal.BlueprintEditorLibrary.reparent_blueprint(bp, parent)
            unreal.BlueprintEditorLibrary.compile_blueprint(bp)
        return bp, False
    factory = unreal.BlueprintFactory()
    factory.set_editor_property("parent_class", parent)
    bp = asset_tools.create_asset(name, path, unreal.Blueprint, factory)
    unreal.BlueprintEditorLibrary.compile_blueprint(bp)
    return bp, True


def bp_class(path):
    # load_blueprint_class depende do Asset Registry, que nao enxerga BPs criados nesta mesma execucao.
    bp = eal.load_asset(path) if eal.does_asset_exist(path) else None
    return bp.generated_class() if bp else None


def cdo_of(bp):
    return unreal.get_default_object(bp.generated_class())


def make_tag(tag_name):
    tag = unreal.GameplayTag()
    tag.import_text(f'(TagName="{tag_name}")')
    return tag


def tag_name(tag):
    m = re.search(r'TagName="([^"]*)"', tag.export_text())
    return m.group(1) if m else ""


# ---------------------------------------------------------------------------- B. Input

def setup_input():
    actions = {}
    for name, value_type in INPUT_ACTIONS.items():
        action, created = load_or_create(INPUT, name, unreal.InputAction, unreal.InputAction_Factory())
        action.set_editor_property("value_type", getattr(unreal.InputActionValueType, value_type))
        save(action)
        actions[name] = action
        log(name, f"{'criado' if created else 'atualizado'} ({value_type})")

    imc, created = load_or_create(INPUT, "IMC_Default", unreal.InputMappingContext, unreal.InputMappingContext_Factory())
    imc.unmap_all()
    for key_name, action_name, mods in KEY_MAPPINGS:
        mapping = unreal.EnhancedActionKeyMapping()
        mapping.set_editor_property("action", actions[action_name])
        key = unreal.Key()
        key.import_text(key_name)  # FKey importa/exporta o nome puro ("W"), nao "(KeyName=...)"
        mapping.set_editor_property("key", key)
        modifiers = []
        for mod in mods:
            # Cria no pacote transitorio, configura e so entao move para dentro do IMC: com o IMC como
            # outer o Python trata o objeto como template e recusa bX/bY/bZ (EditInstanceOnly).
            if mod == "swizzle":
                m = unreal.new_object(unreal.InputModifierSwizzleAxis)
                m.set_editor_property("order", unreal.InputAxisSwizzle.YXZ)
            else:
                m = unreal.new_object(unreal.InputModifierNegate)
                if mod == "negate_y":
                    m.x, m.y, m.z = False, True, False
            m.rename(None, imc)
            modifiers.append(m)
        mapping.set_editor_property("modifiers", modifiers)
        set_imc_mappings(imc, get_imc_mappings(imc) + [mapping])
    save(imc)
    log("IMC_Default", f"{'criado' if created else 'atualizado'} ({len(get_imc_mappings(imc))} mapeamentos)")
    return actions, imc


def get_imc_mappings(imc):
    data = imc.get_editor_property("default_key_mappings")
    return list(data.get_editor_property("mappings"))


def set_imc_mappings(imc, mappings):
    data = imc.get_editor_property("default_key_mappings")
    data.set_editor_property("mappings", mappings)
    imc.set_editor_property("default_key_mappings", data)


# ---------------------------------------------------------------------------- A/C/H. Personagens

def apply_mannequin(cdo):
    mesh_asset = eal.load_asset(MESH)
    anim_class = bp_class(ANIM_BP)
    if mesh_asset is None or anim_class is None:
        raise RuntimeError("manequim do template ausente em /Game/Characters (rode SetupContent.ps1)")
    mesh = cdo.get_editor_property("mesh")
    mesh.set_editor_property("skeletal_mesh_asset", mesh_asset)
    mesh.set_editor_property("relative_location", unreal.Vector(0.0, 0.0, -90.0))
    mesh.set_editor_property("relative_rotation", unreal.Rotator(roll=0.0, pitch=0.0, yaw=-90.0))
    mesh.set_editor_property("anim_class", anim_class)


def setup_player_character(actions, imc):
    bp, created = load_blueprint(CHARACTERS, "BP_PlayerCharacter", "/Script/Arcanum.ArcanumPlayerCharacter")
    cdo = cdo_of(bp)
    apply_mannequin(cdo)
    cdo.set_editor_property("default_mapping_context", imc)
    cdo.set_editor_property("move_action", actions["IA_Move"])
    cdo.set_editor_property("look_action", actions["IA_Look"])
    cdo.set_editor_property("jump_action", actions["IA_Jump"])
    cdo.set_editor_property("spell_slot_actions", [actions[f"IA_Spell{i}"] for i in range(1, 6)])
    cdo.set_editor_property("cast_selected_action", actions["IA_CastSelected"])
    cdo.set_editor_property("cycle_slot_action", actions["IA_CycleSlot"])
    save(bp)
    log("BP_PlayerCharacter", f"{'criado' if created else 'atualizado'} (malha, AnimBP, input)")


def setup_enemy_dummy():
    bp, created = load_blueprint(CHARACTERS, "BP_Enemy_Dummy", "/Script/Arcanum.ArcanumEnemyCharacter")
    apply_mannequin(cdo_of(bp))
    save(bp)
    log("BP_Enemy_Dummy", f"{'criado' if created else 'atualizado'} (malha, AnimBP)")


# ---------------------------------------------------------------------------- D. Core

def setup_core():
    ps, created = load_blueprint(CORE, "BP_PlayerState", "/Script/Arcanum.ArcanumPlayerState")
    save(ps)
    log("BP_PlayerState", "criado" if created else "ok")

    gm, created = load_blueprint(CORE, "BP_GameMode", "/Script/Arcanum.ArcanumGameMode")
    cdo = cdo_of(gm)
    cdo.set_editor_property("default_pawn_class", bp_class(f"{CHARACTERS}/BP_PlayerCharacter"))
    cdo.set_editor_property("player_state_class", bp_class(f"{CORE}/BP_PlayerState"))
    save(gm)
    log("BP_GameMode", f"{'criado' if created else 'atualizado'} (pawn, player state)")


# ---------------------------------------------------------------------------- E. Projeteis + Niagara

def setup_niagara(name):
    full = f"{PROJECTILES}/{name}"
    created = False
    if not eal.does_asset_exist(full):
        # O template fica no conteudo do plugin Niagara, fora do Asset Registry do commandlet: carrega antes.
        template = unreal.load_asset(NIAGARA_TEMPLATE)
        if template is None or asset_tools.duplicate_asset(name, PROJECTILES, template) is None:
            raise RuntimeError(f"nao foi possivel duplicar {NIAGARA_TEMPLATE}")
        created = True
    system = eal.load_asset(full)
    save(system)
    log(name, f"{'criado' if created else 'ok'} (copia de {NIAGARA_TEMPLATE.rsplit('/', 1)[-1]})")
    return system


def find_component_handle(bp, var_name):
    sds = unreal.get_engine_subsystem(unreal.SubobjectDataSubsystem)
    handles = sds.k2_gather_subobject_data_for_blueprint(bp)
    for handle in handles:
        data = unreal.SubobjectDataBlueprintFunctionLibrary.get_data(handle)
        if str(unreal.SubobjectDataBlueprintFunctionLibrary.get_variable_name(data)) == var_name:
            return handle
    return None


def ensure_component(bp, var_name, component_class):
    """Adiciona um componente ao BP (se faltar) e retorna o template editavel."""
    sds = unreal.get_engine_subsystem(unreal.SubobjectDataSubsystem)
    handle = find_component_handle(bp, var_name)
    if handle is None:
        root = sds.k2_gather_subobject_data_for_blueprint(bp)[0]
        params = unreal.AddNewSubobjectParams(parent_handle=root, new_class=component_class, blueprint_context=bp)
        handle, reason = sds.add_new_subobject(params)
        if not unreal.SubobjectDataBlueprintFunctionLibrary.is_handle_valid(handle):
            raise RuntimeError(f"add_new_subobject falhou: {reason}")
        sds.rename_subobject(handle, unreal.Text(var_name))
    data = unreal.SubobjectDataBlueprintFunctionLibrary.get_data(handle)
    return unreal.SubobjectDataBlueprintFunctionLibrary.get_object_for_blueprint(data, bp)


def setup_projectiles():
    for name, ns_name in PROJECTILE_BPS.items():
        system = setup_niagara(ns_name)
        bp, created = load_blueprint(PROJECTILES, name, "/Script/ArcanumCore.ArcanumProjectile")
        trail = ensure_component(bp, "Trail", unreal.NiagaraComponent)
        trail.set_editor_property("asset", system)
        unreal.BlueprintEditorLibrary.compile_blueprint(bp)
        save(bp)
        log(name, f"{'criado' if created else 'atualizado'} (Trail = {ns_name})")


# ---------------------------------------------------------------------------- F. Abilities

def setup_abilities():
    for name, (parent, projectile, homing) in ABILITY_BPS.items():
        bp, created = load_blueprint(ABILITIES, name, parent)
        cdo = cdo_of(bp)
        details = "pai " + parent.rsplit(".", 1)[-1]
        if projectile:
            cdo.set_editor_property("projectile_class", bp_class(f"{PROJECTILES}/{projectile}"))
            cdo.set_editor_property("homing", homing)
            details += f", ProjectileClass={projectile}, bHoming={homing}"
        save(bp)
        log(name, f"{'criado' if created else 'atualizado'} ({details})")


# ---------------------------------------------------------------------------- I. Nivel

def find_actor(actors, label):
    for actor in actors:
        if actor.get_actor_label() == label:
            return actor
    return None


def place(actors, label, actor_class, location, rotation=None, scale=None):
    """Garante um ator com esse rotulo no nivel atual (spawna se faltar) e aplica o transform."""
    eas = unreal.get_editor_subsystem(unreal.EditorActorSubsystem)
    actor = find_actor(actors, label)
    if actor is None:
        actor = eas.spawn_actor_from_class(actor_class, location, rotation or unreal.Rotator())
        actor.set_actor_label(label)
        actors.append(actor)
    actor.set_actor_location(location, False, False)
    actor.set_actor_rotation(rotation or unreal.Rotator(), False)
    if scale is not None:
        actor.set_actor_scale3d(scale)
    return actor


def setup_level():
    les = unreal.get_editor_subsystem(unreal.LevelEditorSubsystem)
    eas = unreal.get_editor_subsystem(unreal.EditorActorSubsystem)
    created = not eal.does_asset_exist(MAP)
    if created:
        if not les.new_level(MAP, False):
            raise RuntimeError("new_level falhou")
    elif not les.load_level(MAP):
        raise RuntimeError("load_level falhou")
    actors = list(eas.get_all_level_actors())

    floor = place(actors, "Floor", unreal.StaticMeshActor, unreal.Vector(0, 0, -50), scale=unreal.Vector(100, 100, 1))
    floor.static_mesh_component.set_static_mesh(eal.load_asset("/Engine/BasicShapes/Cube"))
    floor.static_mesh_component.set_editor_property("mobility", unreal.ComponentMobility.STATIC)

    sun = place(actors, "Sun", unreal.DirectionalLight, unreal.Vector(0, 0, 1000), unreal.Rotator(roll=0, pitch=-45, yaw=-30))
    sun.get_component_by_class(unreal.DirectionalLightComponent).set_editor_property("atmosphere_sun_light", True)
    place(actors, "SkyAtmosphere", unreal.SkyAtmosphere, unreal.Vector(0, 0, 0))
    sky = place(actors, "SkyLight", unreal.SkyLight, unreal.Vector(0, 0, 500))
    sky.get_component_by_class(unreal.SkyLightComponent).set_editor_property("real_time_capture", True)
    place(actors, "HeightFog", unreal.ExponentialHeightFog, unreal.Vector(0, 0, 0))
    start = unreal.Vector(0, 0, 100)
    place(actors, "PlayerStart", unreal.PlayerStart, start)

    dummy_class = bp_class(f"{CHARACTERS}/BP_Enemy_Dummy")
    # Grupo em leque a ~15 m na frente do PlayerStart (+X), virados para o jogador.
    offsets = [(0, 0), (200, -250), (200, 250), (400, -120), (400, 120)]
    for i, (dx, dy) in enumerate(offsets[:NUM_DUMMIES]):
        loc = unreal.Vector(DUMMY_DISTANCE + dx, dy, 100)
        place(actors, f"Enemy_Dummy_{i + 1}", dummy_class, loc, unreal.Rotator(roll=0, pitch=0, yaw=180))

    les.save_current_level()
    log("L_Sandbox", f"{'criado' if created else 'atualizado'} (chao 100x100 m, luz, ceu, neblina, PlayerStart, {NUM_DUMMIES} dummies)")


# ---------------------------------------------------------------------------- D/I. DefaultEngine.ini

def setup_ini():
    path = os.path.join(unreal.Paths.convert_relative_path_to_full(unreal.Paths.project_config_dir()), "DefaultEngine.ini")
    with open(path, encoding="utf-8") as f:
        lines = f.read().splitlines()
    changed = False
    for section, values in INI_SETTINGS.items():
        if section not in lines:
            lines = [section] + [f"{k}={v}" for k, v in values.items()] + [""] + lines
            changed = True
            continue
        start = lines.index(section) + 1
        end = start
        while end < len(lines) and not lines[end].startswith("["):
            end += 1
        for key, value in values.items():
            idx = next((i for i in range(start, end) if lines[i].split("=", 1)[0].strip() == key), None)
            wanted = f"{key}={value}"
            if idx is None:
                lines.insert(start, wanted)
                end += 1
                changed = True
            elif lines[idx] != wanted:
                lines[idx] = wanted
                changed = True
    if changed:
        with open(path, "w", encoding="utf-8", newline="\n") as f:
            f.write("\n".join(lines) + "\n")
    log("DefaultEngine.ini", "atualizado (GameMode, mapas)" if changed else "ok")


# ---------------------------------------------------------------------------- G/H. Pos-import

def setup_post_import():
    missing = [s for s in PROC_STATE_TAGS if not eal.does_asset_exist(f"{SPELLS}/DA_Spell_{s}")]
    if missing or not eal.does_asset_exist(f"{DATA}/{ENEMY_ROW[0]}"):
        unreal.log_warning("[Setup] pos-import pulado: rode import_data.py e depois setup com ARCANUM_SETUP_PHASE=post")
        return

    for spell_id, tag in PROC_STATE_TAGS.items():
        da = eal.load_asset(f"{SPELLS}/DA_Spell_{spell_id}")
        da.set_editor_property("proc_state_tag", make_tag(tag))
        save(da)
        got = tag_name(da.get_editor_property("proc_state_tag"))
        if got != tag:
            fail(f"DA_Spell_{spell_id}", f"ProcStateTag ficou '{got}' (tag {tag} existe?)")
        else:
            log(f"DA_Spell_{spell_id}", f"ProcStateTag={tag}")

    ps = eal.load_asset(f"{CORE}/BP_PlayerState")
    spells = [eal.load_asset(f"{SPELLS}/DA_Spell_{s}") for s in STARTING_SPELLS]
    cdo_of(ps).get_editor_property("spellbook").set_editor_property("starting_spells", spells)
    save(ps)
    log("BP_PlayerState", f"Spellbook.StartingSpells={STARTING_SPELLS}")

    enemy = eal.load_asset(f"{CHARACTERS}/BP_Enemy_Dummy")
    handle = unreal.DataTableRowHandle()
    handle.set_editor_property("data_table", eal.load_asset(f"{DATA}/{ENEMY_ROW[0]}"))
    handle.set_editor_property("row_name", ENEMY_ROW[1])
    cdo_of(enemy).set_editor_property("enemy_row", handle)
    save(enemy)
    log("BP_Enemy_Dummy", f"EnemyRow={ENEMY_ROW[0]}/{ENEMY_ROW[1]}")


# ----------------------------------------------------------------------------

def step(name, fn, *args):
    try:
        return fn(*args)
    except Exception as e:  # noqa: BLE001 - reporta e segue para os proximos assets
        fail(name, e)
        return None


def main():
    phase = os.environ.get("ARCANUM_SETUP_PHASE", "all").lower()
    print(f"[Setup] fase: {phase}")
    if phase in ("pre", "all"):
        result = step("Input", setup_input)
        if result:
            step("BP_PlayerCharacter", setup_player_character, *result)
        step("BP_Enemy_Dummy", setup_enemy_dummy)
        step("Core", setup_core)
        step("Projeteis", setup_projectiles)
        step("Abilities", setup_abilities)
        step("L_Sandbox", setup_level)
        step("DefaultEngine.ini", setup_ini)
    if phase in ("post", "all"):
        step("Pos-import", setup_post_import)
    print(f"[Setup] Resumo: {'OK' if not failures else 'FALHAS em ' + ', '.join(failures)}")


main()
