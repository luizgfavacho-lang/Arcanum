--!strict
-- Essencias (moeda, como os bolts de Ratchet & Clank) e a loja do Grimorio. Regras em
-- Shared/Math/EssenceMath. O servidor decide tudo:
--   * criatura derrotada -> EssenceService.drop: um monte no chao (o cliente espalha as pecas);
--   * depois de ReadyDelay, o jogador vivo mais perto dentro de MagnetStuds leva o monte inteiro
--     (o cliente faz as pecas voarem ate ele);
--   * BuySpell(spellId): confere preco e saldo, desconta e libera a magia.
-- Estado no Player (replica para o HUD e o Grimorio): Essence (saldo) e Unlocked (lista "A,B,C").
-- TODO(RT-04): persistir saldo e magias liberadas com o save.

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local EssenceMath = require(Shared.Math.EssenceMath)
local Net = require(Shared.Net)
local SpellCatalog = require(Shared.SpellCatalog)
local SpellData = require(Shared.Data.Spells) :: any
local StatsService = require(script.Parent.StatsService)

local EssenceService = {}

type Drop = { Id: string, Position: Vector3, Value: number, ReadyAt: number, ExpiresAt: number }

local TICK = 0.1

local drops: { [string]: Drop } = {}
local vfx = Net.get("Vfx")

function EssenceService.get(player: Player): number
	local value = player:GetAttribute("Essence")
	return if typeof(value) == "number" then value else 0
end

function EssenceService.add(player: Player, amount: number)
	if amount ~= 0 then
		player:SetAttribute("Essence", math.max(EssenceService.get(player) + math.floor(amount), 0))
	end
end

local function unlocked(player: Player): { [string]: boolean }
	local text = player:GetAttribute("Unlocked")
	return EssenceMath.decode(if typeof(text) == "string" then text else nil)
end

function EssenceService.isUnlocked(player: Player, spellId: string): boolean
	return unlocked(player)[spellId] == true
end

-- Derrama `value` essencias em `position` (criatura derrotada, bau, recompensa).
function EssenceService.drop(position: Vector3, value: number)
	if value <= 0 then
		return
	end
	local now = os.clock()
	local drop: Drop = {
		Id = HttpService:GenerateGUID(false),
		Position = position,
		Value = value,
		ReadyAt = now + EssenceMath.Config.ReadyDelay,
		ExpiresAt = now + EssenceMath.Config.LifetimeSeconds,
	}
	drops[drop.Id] = drop
	vfx:FireAllClients("EssenceDrop", {
		Id = drop.Id,
		Position = position,
		Value = value,
		Pieces = EssenceMath.pieces(value),
		Delay = EssenceMath.Config.ReadyDelay,
	})
end

-- Compra no Grimorio.
function EssenceService.buy(player: Player, spellId: string)
	local row = SpellData[spellId]
	if not row or not SpellCatalog.Defs[spellId] then
		return
	end
	local owned = unlocked(player)
	local price = EssenceMath.price(row.Tier)
	local balance = EssenceService.get(player)
	if not EssenceMath.canBuy(balance, row.Tier, owned[spellId] == true) then
		vfx:FireClient(player, "SpellBuyFailed", {
			Id = spellId,
			Reason = if owned[spellId] then "Owned" else "Essence",
			Missing = math.max(price - balance, 0),
		})
		return
	end
	owned[spellId] = true
	player:SetAttribute("Essence", balance - price)
	player:SetAttribute("Unlocked", EssenceMath.encode(owned))
	vfx:FireClient(player, "SpellBought", { Id = spellId, Price = price })
end

local function collect(now: number)
	for id, drop in drops do
		if now >= drop.ExpiresAt then
			drops[id] = nil
			vfx:FireAllClients("EssenceExpire", { Id = id })
			continue
		end
		if now < drop.ReadyAt then
			continue
		end
		local best: Player? = nil
		local bestDistance = EssenceMath.Config.MagnetStuds
		for _, player in Players:GetPlayers() do
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if character and root and StatsService.isAlive(character) then
				local distance = (root.Position - drop.Position).Magnitude
				if distance <= bestDistance then
					best, bestDistance = player, distance
				end
			end
		end
		if best then
			drops[id] = nil
			EssenceService.add(best, drop.Value)
			vfx:FireAllClients("EssenceCollect", { Id = id, Model = best.Character, Amount = drop.Value })
		end
	end
end

function EssenceService.init()
	local function setup(player: Player)
		player:SetAttribute("Essence", 0)
		local owned: { [string]: boolean } = {}
		for _, id in SpellCatalog.StartingSlots do
			owned[id] = true
		end
		player:SetAttribute("Unlocked", EssenceMath.encode(owned))
	end
	Players.PlayerAdded:Connect(setup)
	for _, player in Players:GetPlayers() do
		setup(player)
	end
	Net.get("BuySpell").OnServerEvent:Connect(function(player, spellId)
		if typeof(spellId) == "string" then
			EssenceService.buy(player, spellId)
		end
	end)
end

function EssenceService.start()
	while true do
		task.wait(TICK)
		collect(os.clock())
	end
end

return EssenceService
