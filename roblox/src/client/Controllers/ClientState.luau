--!strict
-- Estado local do cliente: slot selecionado e recargas recebidas do servidor.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Net = require(Shared.Net)
local Signal = require(Shared.Signal)
local SpellCatalog = require(Shared.SpellCatalog)

local ClientState = {}

ClientState.SelectedSlot = 1
ClientState.SelectedChanged = Signal.new()
ClientState.Cooldowns = {} :: { [string]: number } -- SpellId -> readyAt (GetServerTimeNow)
ClientState.GcdUntil = 0

function ClientState.select(slot: number)
	ClientState.SelectedSlot = (slot - 1) % SpellCatalog.NumSlots + 1
	ClientState.SelectedChanged:Fire(ClientState.SelectedSlot)
end

function ClientState.start()
	Net.get("SpellState").OnClientEvent:Connect(function(spellId: string, readyAt: number, gcdUntil: number)
		ClientState.Cooldowns[spellId] = readyAt
		ClientState.GcdUntil = gcdUntil
	end)
end

return ClientState
