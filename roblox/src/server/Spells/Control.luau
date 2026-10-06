--!strict
-- Controle (Kind "Control"), alvo pela mira:
--   Prison      Prisao de Energia: jaula prende o alvo (e quem estiver no RadiusMeters) por Duration.
--   Hook        Anzol Carmesim (Meat Hook, Pudge): tiro de habilidade SEM mira automatica; o gancho
--               voa pela mira e fisga o 1o inimigo no caminho; fere (Damage) e puxa ate o mago.
--   Chain       Corrente Carmesim: liga o alvo por Duration; prende no inicio (Proc) e EffectValue do
--               dano que o mago recebe vai para ele.
--   DeathTouch  Toque Mortal (Reaper's Scythe, Necrophos): curto alcance; atordoa um instante, tira
--               EffectValue da vida maxima (teto SecondaryDamage em chefes), enfraquece (Proc) e
--               EXECUTA quem ficar abaixo de SpellMath.ExecuteThreshold.
--   Curse       Maldicao (Maledict, Witch Doctor): area no ponto mirado; Maldicao (+20% de dano
--               recebido) e veneno (Proc); quem morre amaldicoado passa a praga para os vizinhos.
--   Hemorrhage  Hemorragia: marca o alvo; sangramento forte nele e em quem estiver no RadiusMeters.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Net = require(Shared.Net)
local SpellMath = require(Shared.Math.SpellMath)
local States = require(Shared.States)
local Units = require(Shared.Units)
local Services = script.Parent.Parent.Services
local DamageService = require(Services.DamageService)
local StatsService = require(Services.StatsService)
local StatusService = require(Services.StatusService)
local Targeting = require(script.Parent.Parent.Combat.Targeting)
local Context = require(script.Parent.Context)
local Area = require(script.Parent.Area)

local vfx = Net.get("Vfx")

local FLAT = Vector3.new(1, 0, 1)
local SNAP_STUDS = 7 -- sem alvo exato na mira: pega o inimigo mais perto do ponto mirado
local HOOK_SPEED = 110 -- studs/s do gancho
local HOOK_WIDTH = 2.2 -- raio do gancho (tiro de habilidade)
local DEATH_WINDUP = 0.35 -- a foice "segura" o alvo antes do golpe
local CURSE_SPREAD = Units.meters(4.5)

local cursedWatch: { [Model]: boolean } = setmetatable({}, { __mode = "k" }) :: any
-- Ate quando cada alvo esta amaldicoado (a morte limpa os estados antes do Died disparar).
local cursedUntil: { [Model]: number } = setmetatable({}, { __mode = "k" }) :: any

local Control = {}

local watchCurse: (Context.Context, Model) -> ()

local function aimedTarget(ctx: Context.Context, rangeMeters: number): (Model?, Vector3)
	local range = Units.meters(rangeMeters)
	local target, point = Targeting.aimTrace(ctx.Caster, ctx.Origin, Context.direction(ctx), range, 1.5)
	if not target then
		target = Targeting.nearestHostile(ctx.Caster, point, SNAP_STUDS)
	end
	return target, if target then Targeting.position(target) else point
end

local function isBoss(model: Model): boolean
	return model:GetAttribute("Boss") == true
end

local function prison(ctx: Context.Context)
	local row = ctx.Spell.Row
	local target, point = aimedTarget(ctx, row.RangeMeters)
	if not target then
		vfx:FireAllClients("ControlMiss", { Position = point, School = row.School })
		return
	end
	local caged = { target }
	for _, other in Targeting.hostilesInRadius(ctx.Caster, point, Units.meters(row.RadiusMeters) + 2) do
		if other ~= target then
			table.insert(caged, other)
		end
	end
	for _, model in caged do
		StatusService.apply(model, States.Paralyzed, row.DurationSeconds)
	end
	vfx:FireAllClients("Prison", {
		Position = point,
		Size = if isBoss(target) then 12 else 7,
		Duration = row.DurationSeconds,
		School = row.School,
	})
end

local function hook(ctx: Context.Context)
	local row = ctx.Spell.Row
	local range = Units.meters(row.RangeMeters)
	-- Sem mira automatica: so fisga o que estiver no caminho do gancho.
	local target, point = Targeting.aimTrace(ctx.Caster, ctx.Origin, Context.direction(ctx), range, HOOK_WIDTH)
	local from = Targeting.muzzle(ctx.Caster)
	local reach = if target then Targeting.position(target) else point
	local travel = math.clamp((reach - from).Magnitude / HOOK_SPEED, 0.08, 0.5)
	vfx:FireAllClients(
		"Hook",
		{ Caster = ctx.Caster, Target = target, To = reach, Travel = travel, School = row.School }
	)
	if not target then
		return
	end
	task.delay(travel, function()
		if not Targeting.isHostile(ctx.Caster, target) then
			return
		end
		Context.damage(ctx, target, row.Damage)
		local toCaster = (Targeting.position(ctx.Caster) - Targeting.position(target)) * FLAT
		local distance = toCaster.Magnitude - 5
		if distance > 0 and not isBoss(target) and not Players:GetPlayerFromCharacter(target) then
			local speed = Units.meters(row.EffectValue)
			local pullTime = math.min(distance / speed, 1)
			StatusService.apply(target, States.Paralyzed, pullTime + 0.3)
			-- Varios empurroes curtos seguidos (o Area.push dura ~0,18 s).
			for t = 0, pullTime, 0.15 do
				task.delay(t, function()
					if StatsService.isAlive(target) then
						local now = (Targeting.position(ctx.Caster) - Targeting.position(target)) * FLAT
						if now.Magnitude > 5 then
							Area.push(target, now.Unit * speed + Vector3.new(0, 4, 0))
						end
					end
				end)
			end
		end
	end)
end

local function chain(ctx: Context.Context)
	local row = ctx.Spell.Row
	local target, point = aimedTarget(ctx, row.RangeMeters)
	if not target then
		vfx:FireAllClients("ControlMiss", { Position = point, School = row.School })
		return
	end
	Context.tryProc(ctx, target) -- prende no inicio
	StatusService.apply(ctx.Caster, States.Linked, row.DurationSeconds, { Value = row.EffectValue, Source = target })
	vfx:FireAllClients(
		"BloodChain",
		{ Caster = ctx.Caster, Target = target, Duration = row.DurationSeconds, School = row.School }
	)
end

local function deathTouch(ctx: Context.Context)
	local row = ctx.Spell.Row
	local target = aimedTarget(ctx, row.RangeMeters + 1)
	if
		not target
		or (Targeting.position(target) - Targeting.position(ctx.Caster)).Magnitude
			> Units.meters(row.RangeMeters) + 4
	then
		vfx:FireAllClients("ControlMiss", { Position = Targeting.muzzle(ctx.Caster), School = row.School })
		return
	end
	local stats = StatsService.get(target)
	if not stats then
		return
	end
	local amount = stats.Humanoid.MaxHealth * row.EffectValue
	if isBoss(target) then
		amount = math.min(amount, row.SecondaryDamage)
	end
	vfx:FireAllClients("DeathTouch", { Caster = ctx.Caster, Target = target, School = row.School })
	if not isBoss(target) then
		StatusService.apply(target, States.Paralyzed, DEATH_WINDUP + 0.1)
	end
	task.delay(DEATH_WINDUP, function()
		if not Targeting.isHostile(ctx.Caster, target) then
			return
		end
		DamageService.applySpellDamage(
			ctx.Caster,
			target,
			amount,
			row.School,
			{ Multiplier = ctx.Mods.DamageMultiplier }
		)
		Context.tryProc(ctx, target)
		local humanoid = stats.Humanoid
		if SpellMath.shouldExecute(humanoid.Health, humanoid.MaxHealth, isBoss(target)) then
			vfx:FireAllClients("Execute", { Caster = ctx.Caster, Target = target, School = row.School })
			DamageService.applySpellDamage(ctx.Caster, target, humanoid.Health, row.School, { Execute = true })
		end
	end)
end

-- Praga: quem morre amaldicoado passa Maldicao e veneno para os vizinhos (que tambem passam adiante).
watchCurse = function(ctx: Context.Context, target: Model)
	cursedUntil[target] = os.clock() + ctx.Spell.Row.DurationSeconds
	if cursedWatch[target] then
		return
	end
	local humanoid = target:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end
	cursedWatch[target] = true
	humanoid.Died:Connect(function()
		if os.clock() > (cursedUntil[target] or 0) then
			return
		end
		local center = Targeting.position(target)
		local row = ctx.Spell.Row
		local victims = Targeting.hostilesInRadius(ctx.Caster, center, CURSE_SPREAD)
		local points: { Vector3 } = {}
		for _, other in victims do
			if other ~= target then
				StatusService.apply(other, States.Cursed, row.DurationSeconds, { Source = ctx.Caster })
				Context.tryProc(ctx, other)
				watchCurse(ctx, other)
				table.insert(points, Targeting.position(other))
			end
		end
		vfx:FireAllClients("CurseSpread", { From = center, Points = points, School = row.School })
	end)
end

local function curse(ctx: Context.Context)
	local row = ctx.Spell.Row
	local _, point =
		Targeting.aimTrace(ctx.Caster, ctx.Origin, Context.direction(ctx), Units.meters(row.RangeMeters), 0.5)
	local center = Area.groundBelow(point, ctx.Caster)
	local radius = Units.meters(row.RadiusMeters)
	vfx:FireAllClients("Curse", { Position = center, Radius = radius, School = row.School })
	for _, target in Targeting.hostilesInRadius(ctx.Caster, center + Vector3.new(0, 2.5, 0), radius + 1.5) do
		StatusService.apply(target, States.Cursed, row.DurationSeconds, { Source = ctx.Caster })
		Context.tryProc(ctx, target) -- veneno
		watchCurse(ctx, target)
	end
end

local function hemorrhage(ctx: Context.Context)
	local row = ctx.Spell.Row
	local target, point = aimedTarget(ctx, row.RangeMeters)
	local radius = Units.meters(row.RadiusMeters)
	vfx:FireAllClients("Hemorrhage", { Target = target, Position = point, Radius = radius, School = row.School })
	local victims = Targeting.hostilesInRadius(ctx.Caster, point, radius + 1.5)
	if target and not table.find(victims, target) then
		table.insert(victims, target)
	end
	for _, victim in victims do
		Context.tryProc(ctx, victim)
	end
end

function Control.cast(ctx: Context.Context)
	local mode = ctx.Spell.Def.Mode
	if mode == "Prison" then
		prison(ctx)
	elseif mode == "Hook" then
		hook(ctx)
	elseif mode == "Chain" then
		chain(ctx)
	elseif mode == "DeathTouch" then
		deathTouch(ctx)
	elseif mode == "Curse" then
		curse(ctx)
	elseif mode == "Hemorrhage" then
		hemorrhage(ctx)
	end
end

return Control
