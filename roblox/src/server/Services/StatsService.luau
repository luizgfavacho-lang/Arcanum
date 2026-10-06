--!strict
-- Atributos de combate de cada combatente (jogadores e criaturas): o equivalente ao AttributeSet.
-- Vida = Humanoid.Health/MaxHealth (escala do mod: jogador com 20). O resto fica aqui e e
-- espelhado como atributos do Model para o HUD: Mana, MaxMana, Team.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Settings = require(Shared.Config.CombatSettings)
local DamageMath = require(Shared.Math.DamageMath)
local Net = require(Shared.Net)
local ProgressionService = require(script.Parent.ProgressionService)

export type Stats = {
	Model: Model,
	Humanoid: Humanoid,
	Player: Player?,
	Team: string,
	Mana: number,
	MaxMana: number,
	ManaRegen: number,
	SpellPower: number,
	CastSpeed: number,
	Armor: number,
	LastCombat: number,
	BaseWalkSpeed: number,
}

export type RegisterOptions = {
	Team: string,
	Player: Player?,
	MaxHealth: number,
	MaxMana: number?,
	ManaRegen: number?,
	SpellPower: number?,
	Armor: number?,
	WalkSpeed: number?,
}

local StatsService = {}

local registry: { [Model]: Stats } = {}

function StatsService.register(model: Model, options: RegisterOptions): Stats?
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		warn("[Stats] Model sem Humanoid: " .. model:GetFullName())
		return nil
	end

	humanoid.MaxHealth = options.MaxHealth
	humanoid.Health = options.MaxHealth
	if options.WalkSpeed then
		humanoid.WalkSpeed = options.WalkSpeed
	end

	local stats: Stats = {
		Model = model,
		Humanoid = humanoid,
		Player = options.Player,
		Team = options.Team,
		Mana = options.MaxMana or 0,
		MaxMana = options.MaxMana or 0,
		ManaRegen = options.ManaRegen or 0,
		SpellPower = options.SpellPower or 0,
		CastSpeed = 1,
		Armor = options.Armor or 0,
		LastCombat = -math.huge,
		BaseWalkSpeed = humanoid.WalkSpeed,
	}
	registry[model] = stats

	model:SetAttribute("Team", stats.Team)
	model:SetAttribute("MaxMana", stats.MaxMana)
	model:SetAttribute("Mana", stats.Mana)

	model.Destroying:Connect(function()
		registry[model] = nil
	end)
	return stats
end

function StatsService.get(model: Model?): Stats?
	return if model then registry[model] else nil
end

function StatsService.all(): { [Model]: Stats }
	return registry
end

function StatsService.isAlive(model: Model?): boolean
	local stats = StatsService.get(model)
	return stats ~= nil and stats.Humanoid.Health > 0
end

function StatsService.setMana(stats: Stats, value: number)
	stats.Mana = math.clamp(value, 0, stats.MaxMana)
	stats.Model:SetAttribute("Mana", stats.Mana)
end

-- Modo de teste (CombatSettings.DevInfiniteResources): jogador nao gasta mana nem perde vida.
function StatsService.isInfinite(stats: Stats?): boolean
	return Settings.DevInfiniteResources == true and stats ~= nil and stats.Player ~= nil
end

-- Dreno continuo (canalizadas): ManaPerSecond por tique; sem mana, o efeito apaga.
-- No modo de teste (mana infinita) nao gasta nada.
function StatsService.drainMana(stats: Stats, amount: number): boolean
	return StatsService.trySpendMana(stats, amount)
end

function StatsService.trySpendMana(stats: Stats, amount: number): boolean
	if StatsService.isInfinite(stats) then
		return true
	end
	if stats.Mana < amount then
		return false
	end
	StatsService.setMana(stats, stats.Mana - amount)
	return true
end

-- Causou ou recebeu dano: pausa a regeneracao de mana.
function StatsService.notifyCombat(stats: Stats?)
	if stats then
		stats.LastCombat = os.clock()
	end
end

function StatsService.getAffinity(stats: Stats, school: string): number
	return if stats.Player then ProgressionService.getAffinity(stats.Player, school) else 0
end

local function registerCharacter(player: Player, character: Model)
	character:WaitForChild("Humanoid")
	local bonuses = ProgressionService.getBonuses(player)
	StatsService.register(character, {
		Team = "Player",
		Player = player,
		MaxHealth = Settings.PlayerBaseHealth + bonuses.MaxHealth,
		MaxMana = Settings.PlayerBaseMana + bonuses.MaxMana,
		ManaRegen = Settings.PlayerBaseManaRegen + bonuses.ManaRegen,
		SpellPower = bonuses.SpellPower,
		WalkSpeed = Settings.PlayerWalkSpeed,
	})
end

function StatsService.init()
	local function watch(player: Player)
		player.CharacterAdded:Connect(function(character)
			registerCharacter(player, character)
		end)
		if player.Character then
			task.spawn(registerCharacter, player, player.Character)
		end
	end
	Players.PlayerAdded:Connect(watch)
	for _, player in Players:GetPlayers() do
		watch(player)
	end

	-- Subiu de nivel: vida e mana maximas sobem (Levels.csv) e o ganho entra tambem no valor atual.
	ProgressionService.LevelChanged:Connect(function(player: Player)
		local stats = StatsService.get(player.Character)
		if not stats then
			return
		end
		local bonuses = ProgressionService.getBonuses(player)
		local humanoid = stats.Humanoid
		local healthGain = Settings.PlayerBaseHealth + bonuses.MaxHealth - humanoid.MaxHealth
		local manaGain = Settings.PlayerBaseMana + bonuses.MaxMana - stats.MaxMana
		humanoid.MaxHealth = Settings.PlayerBaseHealth + bonuses.MaxHealth
		if humanoid.Health > 0 then
			humanoid.Health = math.min(humanoid.Health + math.max(healthGain, 0), humanoid.MaxHealth)
		end
		stats.MaxMana = Settings.PlayerBaseMana + bonuses.MaxMana
		stats.ManaRegen = Settings.PlayerBaseManaRegen + bonuses.ManaRegen
		stats.SpellPower = bonuses.SpellPower
		stats.Model:SetAttribute("MaxMana", stats.MaxMana)
		StatsService.setMana(stats, stats.Mana + math.max(manaGain, 0))
		Net.get("Vfx"):FireClient(player, "LevelGains", {
			Health = healthGain,
			Mana = manaGain,
			MaxHealth = humanoid.MaxHealth,
			MaxMana = stats.MaxMana,
		})
	end)
end

function StatsService.start()
	local interval = Settings.ManaRegenTickInterval
	while true do
		task.wait(interval)
		local now = os.clock()
		for _, stats in registry do
			if
				stats.Mana < stats.MaxMana
				and stats.Humanoid.Health > 0
				and DamageMath.canRegenerateMana(now, stats.LastCombat, Settings.ManaRegenCombatDelay)
			then
				StatsService.setMana(stats, stats.Mana + stats.ManaRegen * interval)
			end
		end
	end
end

return StatsService
