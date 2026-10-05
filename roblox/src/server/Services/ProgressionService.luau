--!strict
-- Nivel, XP e afinidade por jogador. Estado nos atributos do Player (replicam para o HUD):
--   Level, XP, XPToNext, Affinity_<Escola>, AffinityUses_<Escola>
-- TODO(M1): persistir com DataStore (ProfileStore).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local ProgressionMath = require(Shared.Math.ProgressionMath)
local Levels = require(Shared.Data.Levels) :: any
local Signal = require(Shared.Signal)

local CAST_XP_PER_MINUTE_CAP = 30

local ProgressionService = {}

-- (player, newLevel)
ProgressionService.LevelChanged = Signal.new()

local castXpWindow: { [Player]: { start: number, count: number } } = {}

export type Bonuses = { MaxHealth: number, MaxMana: number, ManaRegen: number, SpellPower: number }

-- Soma dos bonus de Levels.csv do nivel 2 ate o nivel atual.
function ProgressionService.getBonuses(player: Player): Bonuses
	local level = player:GetAttribute("Level") or 1
	local bonuses = { MaxHealth = 0, MaxMana = 0, ManaRegen = 0, SpellPower = 0 }
	for l = 2, level do
		local row = Levels[l]
		if row then
			bonuses.MaxHealth += row.MaxHealthBonus
			bonuses.MaxMana += row.MaxManaBonus
			bonuses.ManaRegen += row.ManaRegenBonus
			bonuses.SpellPower += row.SpellPowerBonus
		end
	end
	return bonuses
end

function ProgressionService.addXP(player: Player, amount: number)
	if amount <= 0 then
		return
	end
	local oldLevel = player:GetAttribute("Level") or 1
	local level, xp = ProgressionMath.applyXP(oldLevel, (player:GetAttribute("XP") or 0) + amount)
	player:SetAttribute("Level", level)
	player:SetAttribute("XP", xp)
	player:SetAttribute("XPToNext", ProgressionMath.xpToNextLevel(level))
	if level ~= oldLevel then
		ProgressionService.LevelChanged:Fire(player, level)
	end
end

-- Cada conjuracao: +1 XP (limite por minuto) e +1 uso de afinidade da escola.
function ProgressionService.recordCast(player: Player, school: string)
	local now = os.clock()
	local window = castXpWindow[player]
	if not window or now - window.start > 60 then
		window = { start = now, count = 0 }
		castXpWindow[player] = window
	end
	if window.count < CAST_XP_PER_MINUTE_CAP then
		window.count += 1
		ProgressionService.addXP(player, 1)
	end

	local affinity = player:GetAttribute("Affinity_" .. school) or 0
	local uses = (player:GetAttribute("AffinityUses_" .. school) or 0) + 1
	local needed = ProgressionMath.affinityUsesToNext(affinity)
	if needed > 0 and uses >= needed then
		affinity += 1
		uses -= needed
		player:SetAttribute("Affinity_" .. school, affinity)
	end
	player:SetAttribute("AffinityUses_" .. school, uses)
end

function ProgressionService.getAffinity(player: Player, school: string): number
	return player:GetAttribute("Affinity_" .. school) or 0
end

function ProgressionService.init()
	local function setup(player: Player)
		player:SetAttribute("Level", 1)
		player:SetAttribute("XP", 0)
		player:SetAttribute("XPToNext", ProgressionMath.xpToNextLevel(1))
	end
	Players.PlayerAdded:Connect(setup)
	for _, player in Players:GetPlayers() do
		setup(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		castXpWindow[player] = nil
	end)
end

return ProgressionService
