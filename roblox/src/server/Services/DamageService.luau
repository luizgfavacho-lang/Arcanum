--!strict
-- Unico ponto que altera vida: dano de magia (com DamageMath), cura, Escudo de Mana,
-- consumo de Carga Arcana, pausa de regen e registro do ultimo atacante (XP do abate).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Settings = require(Shared.Config.CombatSettings)
local DamageMath = require(Shared.Math.DamageMath)
local Net = require(Shared.Net)
local States = require(Shared.States)
local StatsService = require(script.Parent.StatsService)
local StatusService = require(script.Parent.StatusService)

export type DamageOptions = {
	Multiplier: number?, -- runas/talentos/passivas
	Periodic: boolean?, -- DoT: nao consome nem se beneficia da Carga Arcana
}

local DamageService = {}

local lastAttacker: { [Model]: Model } = setmetatable({}, { __mode = "k" }) :: any
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
	local charged = not periodic and StatusService.has(target, States.ArcaneCharge)

	local damage = DamageMath.computeSpellDamage({
		BaseDamage = baseDamage,
		DamageMultiplier = (options and options.Multiplier or 1)
			* (if source and StatusService.has(source, States.Weakened) then 0.8 else 1),
		SpellPower = if sourceStats then sourceStats.SpellPower else 0,
		Affinity = if sourceStats and school then StatsService.getAffinity(sourceStats, school) else 0,
		TargetArmor = targetStats.Armor,
		School = school,
		TargetCursed = StatusService.has(target, States.Cursed),
		TargetArcaneCharged = charged,
		TargetWet = StatusService.has(target, States.Wet),
	}, Settings)

	local healthDamage = damage
	if StatusService.has(target, States.ManaShield) then
		local manaSpent
		healthDamage, manaSpent =
			DamageMath.resolveManaShield(damage, targetStats.Mana, Settings.ManaShieldManaPerDamage)
		StatsService.setMana(targetStats, targetStats.Mana - manaSpent)
	end

	local humanoid = targetStats.Humanoid
	humanoid.Health = math.max(humanoid.Health - healthDamage, 0)

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
	return healthDamage
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
