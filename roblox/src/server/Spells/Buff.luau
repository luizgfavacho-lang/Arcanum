--!strict
-- Magias em si mesmo (Kind "Buff"):
--   ManaShield  Escudo de Mana: dano pago com mana (DamageService) por DurationSeconds.
--   EmberArmor  Armadura de Brasas: imune a fogo; quem bate de perto ou encosta (RadiusMeters) queima.
--   Sacrifice   Ritual de Sacrificio: (paga vida no SpellService) explosao de sangue em volta
--               (Damage em RadiusMeters) e Fortalecido (+EffectValue de dano e velocidade).
--   Pact        Pacto de Sangue: Fortalecido em voce e nos aliados por perto (poder compartilhado).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Net = require(Shared.Net)
local States = require(Shared.States)
local Units = require(Shared.Units)
local Services = script.Parent.Parent.Services
local StatsService = require(Services.StatsService)
local StatusService = require(Services.StatusService)
local Targeting = require(script.Parent.Parent.Combat.Targeting)
local Context = require(script.Parent.Context)
local Area = require(script.Parent.Area)

local vfx = Net.get("Vfx")

local PACT_RANGE = Units.meters(15)

local Buff = {}

local function emberAura(ctx: Context.Context)
	local row = ctx.Spell.Row
	local reach = Units.meters(row.RadiusMeters) + 3
	task.spawn(function()
		while StatusService.has(ctx.Caster, States.EmberArmor) and StatsService.isAlive(ctx.Caster) do
			for _, target in Targeting.hostilesInRadius(ctx.Caster, Targeting.position(ctx.Caster), reach) do
				StatusService.apply(target, States.Burning, row.ProcDurationSeconds, {
					DamagePerSecond = row.ProcDamagePerSecond,
					Source = ctx.Caster,
					School = row.School,
				})
			end
			task.wait(1)
		end
	end)
end

function Buff.cast(ctx: Context.Context)
	local row = ctx.Spell.Row
	local mode = ctx.Spell.Def.Mode
	local caster = ctx.Caster
	if mode == "ManaShield" then
		StatusService.apply(caster, States.ManaShield, row.DurationSeconds, { Source = caster })
	elseif mode == "EmberArmor" then
		StatusService.apply(caster, States.EmberArmor, row.DurationSeconds, {
			DamagePerSecond = row.ProcDamagePerSecond,
			Value = row.ProcDurationSeconds,
			Source = caster,
		})
		emberAura(ctx)
	elseif mode == "Sacrifice" then
		local center = Targeting.position(caster)
		local radius = Units.meters(row.RadiusMeters)
		vfx:FireAllClients("Ritual", { Caster = caster, Position = center, Radius = radius, School = row.School })
		task.delay(0.35, function()
			for _, target in Targeting.hostilesInRadius(caster, center, radius) do
				Context.damage(ctx, target, row.Damage)
				local away = (Targeting.position(target) - center) * Vector3.new(1, 0, 1)
				Area.push(
					target,
					(if away.Magnitude > 0.1 then away.Unit else Vector3.xAxis) * 20 + Vector3.new(0, 12, 0)
				)
			end
		end)
		StatusService.apply(caster, States.Empowered, row.DurationSeconds, { Value = row.EffectValue, Source = caster })
	elseif mode == "Pact" then
		local allies: { Model } = {}
		for _, player in Players:GetPlayers() do
			local character = player.Character
			if
				character
				and character ~= caster
				and StatsService.isAlive(character)
				and (Targeting.position(character) - Targeting.position(caster)).Magnitude <= PACT_RANGE
			then
				table.insert(allies, character)
			end
		end
		StatusService.apply(caster, States.Empowered, row.DurationSeconds, { Value = row.EffectValue, Source = caster })
		for _, ally in allies do
			StatusService.apply(
				ally,
				States.Empowered,
				row.DurationSeconds,
				{ Value = row.EffectValue, Source = caster }
			)
		end
		vfx:FireAllClients("Pact", { Caster = caster, Allies = allies, School = row.School })
	end
end

return Buff
