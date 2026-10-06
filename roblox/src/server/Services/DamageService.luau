--!strict
-- Unico ponto que altera vida: dano de magia (com DamageMath), cura, Escudo de Mana,
-- consumo de Carga Arcana, pausa de regen e registro do ultimo atacante (XP do abate).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Settings = require(Shared.Config.CombatSettings)
local ComboMath = require(Shared.Math.ComboMath)
local DamageMath = require(Shared.Math.DamageMath)
local SpellMath = require(Shared.Math.SpellMath)
local Net = require(Shared.Net)
local Signal = require(Shared.Signal)
local States = require(Shared.States)
local Units = require(Shared.Units)
local StatsService = require(script.Parent.StatsService)
local StatusService = require(script.Parent.StatusService)
local DodgeService = require(script.Parent.DodgeService)
local Targeting = require(script.Parent.Parent.Combat.Targeting)

export type DamageOptions = {
	Multiplier: number?, -- runas/talentos/passivas
	Periodic: boolean?, -- DoT: nao consome nem se beneficia da Carga Arcana
	NoReaction: boolean?, -- respingo de reacao: nao dispara outra (evita cascata)
	Execute: boolean?, -- execucao (Toque Mortal): tira toda a vida que resta, ignora escudo e armadura
}

local DamageService = {}

-- (source, target, dano tirado da vida, periodico?, escola) depois de cada golpe que acertou.
-- A IA usa para reagir (aggro, atordoamento, empurrao).
DamageService.Damaged = Signal.new() :: Signal.Signal<Model?, Model, number, boolean, string?>

local lastAttacker: { [Model]: Model } = setmetatable({}, { __mode = "k" }) :: any
local lastReaction: { [Model]: number } = setmetatable({}, { __mode = "k" }) :: any
local vfxFast = Net.get("VfxFast")

function DamageService.getLastAttacker(model: Model): Model?
	return lastAttacker[model]
end

-- Retorna o dano efetivamente tirado da vida.
function DamageService.applySpellDamage(
	source: Model?,
	target: Model,
	baseDamage: number,
	school: string?,
	options: DamageOptions?
): number
	local targetStats = StatsService.get(target)
	if not targetStats or targetStats.Humanoid.Health <= 0 then
		return 0
	end
	local sourceStats = StatsService.get(source)
	local periodic = options ~= nil and options.Periodic == true
	-- Esquiva: golpes diretos na janela de invulnerabilidade nao acertam (DoT continua).
	if not periodic and DodgeService.tryEvade(target) then
		return 0
	end
	local charged = not periodic and StatusService.has(target, States.ArcaneCharge)

	-- Armadura de Brasas: imune a fogo; quem bate de perto pega fogo (DamagePerSecond do estado,
	-- duracao em Value).
	if StatusService.has(target, States.EmberArmor) then
		if school == "Fire" then
			return 0
		end
		if source and not periodic and StatsService.isAlive(source) then
			local sourceRoot = source:FindFirstChild("HumanoidRootPart") :: BasePart?
			local targetRoot = target:FindFirstChild("HumanoidRootPart") :: BasePart?
			if sourceRoot and targetRoot and (sourceRoot.Position - targetRoot.Position).Magnitude < 9 then
				StatusService.apply(source, States.Burning, StatusService.value(target, States.EmberArmor) or 3, {
					DamagePerSecond = 1,
					Source = target,
					School = "Fire",
				})
			end
		end
	end
	local empowered = if source then StatusService.value(source, States.Empowered) else nil

	-- Reacao entre escolas (Math/ComboMath): so golpe direto de alguem.
	local reaction: ComboMath.Reaction? = nil
	if source and not periodic and not (options and options.NoReaction) then
		local now = os.clock()
		reaction = ComboMath.find(school, function(state)
			return StatusService.has(target, state)
		end)
		if reaction and ComboMath.ready(lastReaction[target], now) then
			lastReaction[target] = now
		else
			reaction = nil
		end
	end

	local multiplier = (options and options.Multiplier or 1)
		* (if source and StatusService.has(source, States.Weakened) then 0.8 else 1)
		* (1 + (empowered or 0))
		* (if reaction then reaction.Multiplier else 1)
		-- Armadura de Brasas (Molten Shield, Annie): menos dano recebido.
		* (if StatusService.has(target, States.EmberArmor) then 1 - SpellMath.EmberArmorReduction else 1)
	local damage = DamageMath.computeSpellDamage({
		BaseDamage = baseDamage,
		DamageMultiplier = multiplier,
		SpellPower = if sourceStats then sourceStats.SpellPower else 0,
		Affinity = if sourceStats and school then StatsService.getAffinity(sourceStats, school) else 0,
		TargetArmor = targetStats.Armor,
		School = school,
		TargetCursed = StatusService.has(target, States.Cursed),
		TargetArcaneCharged = charged,
		TargetWet = StatusService.has(target, States.Wet),
	}, Settings)

	local healthDamage = damage
	local infinite = StatsService.isInfinite(targetStats)
	local execute = options ~= nil and options.Execute == true
	if execute then
		healthDamage = targetStats.Humanoid.Health
	elseif StatusService.has(target, States.ManaShield) then
		if not infinite then
			local manaSpent
			healthDamage, manaSpent =
				DamageMath.resolveManaShield(damage, targetStats.Mana, Settings.ManaShieldManaPerDamage)
			StatsService.setMana(targetStats, targetStats.Mana - manaSpent)
		end
		if damage > 0 then
			vfxFast:FireAllClients("ShieldHit", { Target = target, Amount = damage })
		end
	end

	-- Corrente Carmesim: parte do dano recebido vai para a criatura ligada.
	local linkFraction = StatusService.value(target, States.Linked)
	local linked = StatusService.source(target, States.Linked)
	if
		not execute
		and linkFraction
		and linked
		and linked ~= source
		and StatsService.isAlive(linked)
		and healthDamage > 0
	then
		local diverted = healthDamage * linkFraction
		healthDamage -= diverted
		task.spawn(DamageService.applySpellDamage, target, linked, diverted, "Blood", { Periodic = true })
	end

	local humanoid = targetStats.Humanoid
	if not infinite then
		humanoid.Health = math.max(humanoid.Health - healthDamage, 0)
	end

	if charged then
		StatusService.remove(target, States.ArcaneCharge)
	end
	StatsService.notifyCombat(targetStats)
	StatsService.notifyCombat(sourceStats)
	if source then
		lastAttacker[target] = source
	end
	if humanoid.Health <= 0 then
		StatusService.clearAll(target)
	end

	if healthDamage > 0 then
		vfxFast:FireAllClients("Damage", {
			Target = target,
			Source = source,
			Amount = healthDamage,
			School = school,
			Periodic = periodic,
			Killed = humanoid.Health <= 0,
		})
	end
	DamageService.Damaged:Fire(source, target, healthDamage, periodic, school)
	if reaction then
		DamageService.react(reaction, source :: Model, target, damage, school)
	end
	return healthDamage
end

-- Efeitos da reacao depois do golpe: consome o estado, respingo, cura do conjurador, contagio.
function DamageService.react(
	reaction: ComboMath.Reaction,
	source: Model,
	target: Model,
	hitDamage: number,
	school: string?
)
	local center = Targeting.position(target)
	if reaction.Consumes then
		StatusService.remove(target, reaction.State)
	end
	local others: { Model } = {}
	local radius = Units.meters(math.max(reaction.SplashRadiusMeters, reaction.SpreadRadiusMeters))
	if radius > 0 then
		for _, other in Targeting.hostilesInRadius(source, center, radius) do
			if other ~= target and (not reaction.SplashOnlyState or StatusService.has(other, reaction.State)) then
				table.insert(others, other)
			end
		end
	end
	local splash = ComboMath.splashDamage(reaction, hitDamage)
	for _, other in others do
		if splash > 0 then
			task.spawn(DamageService.applySpellDamage, source, other, splash, school, { NoReaction = true })
		end
		if reaction.SpreadRadiusMeters > 0 then
			StatusService.spread(target, other, States.Poisoned)
			StatusService.spread(target, other, States.Bleeding)
		end
	end
	local heal = ComboMath.healAmount(reaction, hitDamage)
	if heal > 0 then
		DamageService.heal(source, heal)
	end
	local targets: { Vector3 } = {}
	for _, other in others do
		table.insert(targets, Targeting.position(other))
	end
	vfxFast:FireAllClients("Reaction", {
		Id = reaction.Id,
		Label = reaction.Label,
		Target = target,
		Position = center,
		Radius = radius,
		Targets = targets,
		Source = source,
	})
end

function DamageService.heal(target: Model, amount: number)
	local stats = StatsService.get(target)
	if not stats or amount <= 0 or stats.Humanoid.Health <= 0 then
		return
	end
	local humanoid = stats.Humanoid
	humanoid.Health = math.min(humanoid.Health + amount, humanoid.MaxHealth)
	vfxFast:FireAllClients("Heal", { Target = target, Amount = amount })
end

function DamageService.init()
	StatusService.setDamageHandler(function(source, target, amount, school, periodic)
		DamageService.applySpellDamage(source, target, amount, school, { Periodic = periodic })
	end)
end

return DamageService
