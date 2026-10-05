--!strict
-- Esquiva do jogador. O cliente e dono da fisica do personagem, entao ele mesmo aplica o impulso
-- (resposta instantanea) e avisa o servidor, que valida a recarga e abre a janela de
-- invulnerabilidade (CombatSettings.DodgeInvulnerability). Um golpe direto evitado dentro da
-- janela e uma "esquiva perfeita": devolve um pouco de mana (uma vez por esquiva).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")

local Shared = ReplicatedStorage.Shared
local Settings = require(Shared.Config.CombatSettings)
local CombatMath = require(Shared.Math.CombatMath)
local Net = require(Shared.Net)
local States = require(Shared.States)
local StatsService = require(script.Parent.StatsService)
local StatusService = require(script.Parent.StatusService)

type DodgeState = { Start: number, Perfect: boolean }

local DodgeService = {}

local dodges: { [Model]: DodgeState } = setmetatable({}, { __mode = "k" }) :: any
local vfx = Net.get("Vfx")

-- Folga para a latencia: o cliente ja respeita a recarga inteira.
local LATENCY_SLACK = 0.15

-- Chamado pelo DamageService antes de um golpe direto. true = o golpe nao acerta.
function DodgeService.tryEvade(target: Model): boolean
	local dodge = dodges[target]
	if not dodge or not CombatMath.isInvulnerable(os.clock(), dodge.Start, Settings.DodgeInvulnerability) then
		return false
	end
	if not dodge.Perfect then
		dodge.Perfect = true
		local stats = StatsService.get(target)
		if stats then
			StatsService.setMana(stats, stats.Mana + Settings.PerfectDodgeMana)
		end
		vfx:FireAllClients("PerfectDodge", { Model = target })
	end
	return true
end

local function request(player: Player, direction: any)
	local character = player.Character
	local stats = StatsService.get(character)
	if not character or not stats or stats.Humanoid.Health <= 0 then
		return
	end
	if StatusService.has(character, States.Paralyzed) then
		return
	end
	local now = os.clock()
	local last = dodges[character]
	if last and not CombatMath.dodgeReady(now, last.Start, Settings.DodgeCooldown - LATENCY_SLACK) then
		return
	end
	dodges[character] = { Start = now, Perfect = false }

	-- Direcao so para o visual dos outros clientes (plana e unitaria).
	local flat: Vector3? = nil
	if typeof(direction) == "Vector3" and direction.X == direction.X and direction.Z == direction.Z then
		local d = Vector3.new(direction.X, 0, direction.Z)
		flat = if d.Magnitude > 0.1 and d.Magnitude < 1e4 then d.Unit else nil
	end
	vfx:FireAllClients("Dodge", { Model = character, Direction = flat })
end

function DodgeService.init()
	Net.get("Dodge").OnServerEvent:Connect(request)
	-- Shift esquiva: desliga a trava de mouse padrao do Roblox (tambem no Shift). A camera do
	-- jogo ja prende o mouse sozinha (client/Controllers/CameraController).
	StarterPlayer.EnableMouseLockOption = false
	local function noMouseLock(player: Player)
		player.DevEnableMouseLock = false
	end
	Players.PlayerAdded:Connect(noMouseLock)
	for _, player in Players:GetPlayers() do
		noMouseLock(player)
	end
end

return DodgeService
