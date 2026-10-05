--!strict
-- Remotes do jogo. O servidor cria; o cliente espera. Nomes centralizados aqui.
--
-- Cliente -> Servidor
--   CastRequest(slot: number, origin: Vector3, aimPoint: Vector3)
--   AimUpdate(origin: Vector3, aimPoint: Vector3)        [unreliable] mira durante canalizacao
--   ChannelStop(slot: number)
--   EquipSpell(spellId: string, slot: number)
--   Dodge(direction: Vector3)                            esquiva: o cliente ja aplicou o impulso; o
--                                                        servidor valida a recarga e abre a invulnerabilidade
-- Servidor -> Cliente(s)
--   Vfx(kind: string, payload: table)                     efeitos importantes (todos os clientes)
--   VfxFast(kind: string, payload: table)                 [unreliable] ticks de canalizacao, numeros de dano
--   SpellState(spellId: string, readyAt: number, gcdUntil: number)   recargas (so o dono)
--   CastFeedback(reason: string, slot: number)            conjuracao recusada: "Mana", "Health",
--                                                          "Cooldown", "Paralyzed" (so o dono)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local DEFINITIONS: { [string]: string } = {
	CastRequest = "RemoteEvent",
	AimUpdate = "UnreliableRemoteEvent",
	ChannelStop = "RemoteEvent",
	EquipSpell = "RemoteEvent",
	Dodge = "RemoteEvent",
	Vfx = "RemoteEvent",
	VfxFast = "UnreliableRemoteEvent",
	SpellState = "RemoteEvent",
	CastFeedback = "RemoteEvent",
}

local folder: Instance
if RunService:IsServer() then
	folder = ReplicatedStorage:FindFirstChild("Remotes") or Instance.new("Folder")
	folder.Name = "Remotes"
	for name, className in DEFINITIONS do
		if not folder:FindFirstChild(name) then
			local remote = Instance.new(className)
			remote.Name = name
			remote.Parent = folder
		end
	end
	folder.Parent = ReplicatedStorage
else
	folder = ReplicatedStorage:WaitForChild("Remotes")
end

local Net = {}

function Net.get(name: string): any
	assert(DEFINITIONS[name], "Remote desconhecido: " .. name)
	return folder:WaitForChild(name)
end

return Net
