--!strict
-- Feixes:
--   Beam   Raio Arcano (canalizada): feixe preciso pela mira; Damage = dano/s no primeiro alvo;
--          gasta ManaPerSecond enquanto o botao estiver segurado.
--   Lance  Lanca do Firmamento: carrega por EffectValue s e dispara um laser de RangeMeters que
--          atravessa todas as criaturas na linha (Damage em cada).

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

local vfx = Net.get("Vfx")
local vfxFast = Net.get("VfxFast")

local LANCE_WIDTH = 3.5 -- studs da linha que o laser acerta

local Beam = {}

function Beam.start(ctx: Context.Context)
	local row = ctx.Spell.Row
	local interval = if row.TickIntervalSeconds > 0 then row.TickIntervalSeconds else 0.1
	ctx.Caster:SetAttribute("Channeling", ctx.Spell.Id)
	task.spawn(function()
		while not ctx.Stopped do
			local stats = StatsService.get(ctx.Caster)
			if not stats or stats.Humanoid.Health <= 0 or StatusService.has(ctx.Caster, States.Paralyzed) then
				break
			end
			if not StatsService.trySpendMana(stats, row.ManaPerSecond * interval * ctx.Mods.CostMultiplier) then
				break
			end
			local target, point =
				Targeting.aimTrace(ctx.Caster, ctx.Origin, Context.direction(ctx), Units.meters(row.RangeMeters), 1.2)
			if target then
				Context.damage(ctx, target, row.Damage * interval)
				Context.tryProc(ctx, target, interval)
			end
			vfxFast:FireAllClients("ArcaneBeam", {
				Caster = ctx.Caster,
				To = if target then Targeting.position(target) else point,
				Hit = target ~= nil,
				School = row.School,
			})
			task.wait(interval)
		end
		ctx.Stopped = true
		if ctx.Caster.Parent then
			ctx.Caster:SetAttribute("Channeling", nil)
		end
		vfx:FireAllClients("ChannelEnd", { Caster = ctx.Caster })
		if ctx.OnEnded then
			ctx.OnEnded()
		end
	end)
end

function Beam.lance(ctx: Context.Context)
	local row = ctx.Spell.Row
	local charge = if row.EffectValue > 0 then row.EffectValue else 1
	vfx:FireAllClients("LanceCharge", { Caster = ctx.Caster, Duration = charge, School = row.School })
	task.delay(charge, function()
		if not StatsService.isAlive(ctx.Caster) then
			return
		end
		local from = Targeting.muzzle(ctx.Caster)
		local range = Units.meters(row.RangeMeters)
		-- So paredes param o laser.
		local _, wallPoint = Targeting.aimTrace(ctx.Caster, ctx.Origin, Context.direction(ctx), range, 0.3)
		local direction = (wallPoint - from)
		direction = if direction.Magnitude > 1e-3 then direction.Unit else Context.direction(ctx)
		local to = from + direction * range
		vfx:FireAllClients("FirmamentLance", { Caster = ctx.Caster, From = from, To = to, School = row.School })
		for _, target in Targeting.hostilesInRadius(ctx.Caster, (from + to) / 2, range / 2 + LANCE_WIDTH) do
			local p = Targeting.position(target)
			local along = math.clamp((p - from):Dot(direction), 0, range)
			if (from + direction * along - p).Magnitude <= LANCE_WIDTH then
				Context.damage(ctx, target, row.Damage)
				Context.tryProc(ctx, target)
			end
		end
	end)
end

return Beam
