--!strict
-- Estados temporarios (Paralisia, Queimadura, Sangramento, Maldicao, Carga Arcana...).
-- Reaplicar renova a duracao (nao acumula). DoTs batem a cada CombatSettings.DotTickInterval.
-- Cada estado ativo vira o atributo "State_<Nome>" = true no Model (o cliente desenha efeitos).

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Settings = require(Shared.Config.CombatSettings)
local States = require(Shared.States)
local StatsService = require(script.Parent.StatsService)

type Active = {
	ExpiresAt: number,
	DamagePerSecond: number,
	Source: Model?,
	School: string?,
	NextTick: number,
	Value: number, -- intensidade do estado (ex.: +30% de dano do Fortalecido)
}

export type ApplyOptions = { DamagePerSecond: number?, Source: Model?, School: string?, Value: number? }

-- Injetado pelo DamageService (evita dependencia circular).
type DamageHandler = (source: Model?, target: Model, amount: number, school: string?, periodic: boolean) -> ()

local StatusService = {}

local active: { [Model]: { [string]: Active } } = {}
local damageHandler: DamageHandler? = nil

function StatusService.setDamageHandler(handler: DamageHandler)
	damageHandler = handler
end

local function refreshMovement(model: Model)
	local stats = StatsService.get(model)
	if not stats then
		return
	end
	local paralyzed = StatusService.has(model, States.Paralyzed)
	local boost = 1 + (StatusService.value(model, States.Empowered) or 0)
	stats.Humanoid.WalkSpeed = if paralyzed then 0 else stats.BaseWalkSpeed * boost
	stats.Humanoid.JumpHeight = if paralyzed then 0 else 7.2
end

function StatusService.has(model: Model, state: string): boolean
	local states = active[model]
	return states ~= nil and states[state] ~= nil
end

-- Valor e origem de um estado ativo (nil se nao estiver ativo).
function StatusService.value(model: Model, state: string): number?
	local states = active[model]
	local info = states and states[state]
	return if info then info.Value else nil
end

function StatusService.source(model: Model, state: string): Model?
	local states = active[model]
	local info = states and states[state]
	return if info then info.Source else nil
end

function StatusService.apply(model: Model, state: string, duration: number, options: ApplyOptions?)
	if duration <= 0 or not StatsService.isAlive(model) then
		return
	end
	local now = os.clock()
	local states = active[model]
	if not states then
		states = {}
		active[model] = states
		model.Destroying:Connect(function()
			active[model] = nil
		end)
	end
	local existing = states[state]
	states[state] = {
		ExpiresAt = now + duration,
		DamagePerSecond = options and options.DamagePerSecond or 0,
		Source = options and options.Source,
		School = options and options.School,
		Value = options and options.Value or 0,
		-- Renovar nao reinicia o relogio do DoT (evita "spam" de dano por reaplicacao).
		NextTick = if existing then existing.NextTick else now + Settings.DotTickInterval,
	}
	model:SetAttribute("State_" .. state, true)
	if state == States.Paralyzed or state == States.Empowered then
		refreshMovement(model)
	end
end

function StatusService.remove(model: Model, state: string)
	local states = active[model]
	if not states or not states[state] then
		return
	end
	states[state] = nil
	model:SetAttribute("State_" .. state, nil)
	if state == States.Paralyzed or state == States.Empowered then
		refreshMovement(model)
	end
end

function StatusService.clearAll(model: Model)
	local states = active[model]
	if states then
		for state in states do
			StatusService.remove(model, state)
		end
	end
end

local function tick()
	local now = os.clock()
	for model, states in active do
		for state, info in states do
			if now >= info.ExpiresAt then
				StatusService.remove(model, state)
			elseif States.Dot[state] and info.DamagePerSecond > 0 and now >= info.NextTick then
				info.NextTick += Settings.DotTickInterval
				local amount = info.DamagePerSecond * Settings.DotTickInterval
				-- Sangramento dobra enquanto o alvo se move.
				if state == States.Bleeding then
					local root = model:FindFirstChild("HumanoidRootPart") :: BasePart?
					if root and root.AssemblyLinearVelocity.Magnitude > 2 then
						amount *= 2
					end
				end
				if damageHandler then
					damageHandler(info.Source, model, amount, info.School, true)
				end
			end
		end
	end
end

function StatusService.start()
	RunService.Heartbeat:Connect(tick)
end

return StatusService
