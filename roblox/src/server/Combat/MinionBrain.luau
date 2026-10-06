--!strict
-- IA dos servos invocados (Necromancia): seguem o dono, escolhem o inimigo mais perto (dele ou
-- do dono), se aproximam e golpeiam (dano da linha do servo em Enemies.csv). Somem ao fim do tempo
-- ou se o dono morrer. Servidor, ~10 vezes por segundo (Spells/Summon chama stepAll).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Shared.Net)
local Services = script.Parent.Parent.Services
local DamageService = require(Services.DamageService)
local StatsService = require(Services.StatsService)
local Targeting = require(script.Parent.Targeting)

local vfx = Net.get("Vfx")

local FLAT = Vector3.new(1, 0, 1)
local SEARCH_STUDS = 28 -- procura inimigos ate essa distancia do servo ou do dono
local LEASH_STUDS = 45 -- longe demais do dono: larga o alvo e volta

export type Minion = {
	Model: Model,
	Humanoid: Humanoid,
	Root: BasePart,
	Owner: Model,
	Row: any,
	Big: boolean,
	Slot: number,
	Anims: { [string]: AnimationTrack },
	Target: Model?,
	NextAttack: number,
	ExpiresAt: number,
}

local MinionBrain = {}

local minions: { [Model]: Minion } = {}

function MinionBrain.add(minion: Minion)
	minions[minion.Model] = minion
end

function MinionBrain.ofOwner(owner: Model, rowName: string?): { Minion }
	local list = {}
	for _, m in minions do
		if m.Owner == owner and (rowName == nil or m.Model.Name == rowName) then
			table.insert(list, m)
		end
	end
	table.sort(list, function(a, b)
		return a.ExpiresAt < b.ExpiresAt
	end)
	return list
end

function MinionBrain.dismiss(minion: Minion)
	minions[minion.Model] = nil
	if minion.Humanoid.Health > 0 then
		minion.Humanoid.Health = 0
	end
end

local function face(minion: Minion, position: Vector3)
	local root = minion.Root
	local look = (position - root.Position) * FLAT
	if look.Magnitude > 0.5 then
		root.CFrame = CFrame.lookAt(root.Position, root.Position + look)
	end
end

local function step(minion: Minion, now: number)
	local owner = minion.Owner
	if now > minion.ExpiresAt or not StatsService.isAlive(owner) then
		MinionBrain.dismiss(minion)
		return
	end
	local root, humanoid = minion.Root, minion.Humanoid
	local ownerPos = Targeting.position(owner)

	local target = minion.Target
	if
		not target
		or not Targeting.isHostile(minion.Model, target)
		or (Targeting.position(target) - ownerPos).Magnitude > LEASH_STUDS
	then
		target = Targeting.nearestHostile(minion.Model, root.Position, SEARCH_STUDS)
			or Targeting.nearestHostile(minion.Model, ownerPos, SEARCH_STUDS)
		minion.Target = target
	end

	if target then
		local targetPos = Targeting.position(target)
		local reach = if minion.Big then 8 else 5.5
		local distance = ((targetPos - root.Position) * FLAT).Magnitude
		if distance > reach then
			humanoid:MoveTo(targetPos)
		else
			humanoid:MoveTo(root.Position)
			face(minion, targetPos)
			if now >= minion.NextAttack then
				minion.NextAttack = now + (if minion.Big then 1.6 else 1.1) * (0.9 + math.random() * 0.2)
				local slash = minion.Anims.Slash
				if slash then
					slash:Play(0.05, 1, if minion.Big then 0.8 else 1.2)
				end
				task.delay(0.25, function()
					if StatsService.isAlive(minion.Model) and Targeting.isHostile(minion.Model, target) then
						DamageService.applySpellDamage(minion.Model, target, minion.Row.AttackDamage, minion.Row.School)
						vfx:FireAllClients("MinionHit", {
							Position = Targeting.position(target),
							Big = minion.Big,
							School = minion.Row.School,
						})
					end
				end)
			end
		end
		return
	end

	-- Sem alvo: acompanha o dono, cada servo num lugar em volta dele.
	local angle = minion.Slot * 1.3
	local spot = ownerPos + Vector3.new(math.cos(angle), 0, math.sin(angle)) * (if minion.Big then 7 else 5)
	if ((spot - root.Position) * FLAT).Magnitude > 3 then
		humanoid:MoveTo(spot)
	end
end

function MinionBrain.stepAll()
	local now = os.clock()
	for model, minion in minions do
		if not model.Parent or minion.Humanoid.Health <= 0 then
			minions[model] = nil
		else
			local ok, err = pcall(step, minion, now)
			if not ok then
				warn("[Minion] " .. tostring(err))
				minions[model] = nil
			end
		end
	end
end

return MinionBrain
