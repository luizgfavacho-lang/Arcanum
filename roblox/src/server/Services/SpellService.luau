--!strict
-- Grimorio (5 slots), validacao e custo de conjuracao, recargas e despacho para cada tipo de magia.
-- O cliente so pede ("quero conjurar o slot N mirando aqui"); o servidor decide tudo.
-- Slots ficam nos atributos do Player: Slot1..Slot5 = SpellId.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local Settings = require(Shared.Config.CombatSettings)
local Net = require(Shared.Net)
local SpellCatalog = require(Shared.SpellCatalog)
local Spells = require(Shared.Spells)
local States = require(Shared.States)

local StatsService = require(script.Parent.StatsService)
local StatusService = require(script.Parent.StatusService)
local ProgressionService = require(script.Parent.ProgressionService)
local StaffService = require(script.Parent.StaffService)
local SpellsFolder = script.Parent.Parent.Spells
local Modifiers = require(script.Parent.Parent.Combat.Modifiers)
local Context = require(SpellsFolder.Context)
local Hitscan = require(SpellsFolder.Hitscan)
local Projectile = require(SpellsFolder.Projectile)
local ChainLightning = require(SpellsFolder.ChainLightning)
local Area = require(SpellsFolder.Area)

type PlayerSpellState = {
	Cooldowns: { [string]: number }, -- SpellId -> instante (GetServerTimeNow) em que fica pronta
	GcdUntil: number,
	Channel: Context.Context?,
}

local SpellService = {}

local states: { [Player]: PlayerSpellState } = {}
local vfx = Net.get("Vfx")
local spellStateRemote = Net.get("SpellState")
local feedbackRemote = Net.get("CastFeedback")

local function isFiniteVector(v: any): boolean
	return typeof(v) == "Vector3"
		and v.X == v.X
		and v.Y == v.Y
		and v.Z == v.Z
		and math.abs(v.X) < 1e6
		and math.abs(v.Y) < 1e6
		and math.abs(v.Z) < 1e6
end

-- A mira vem do cliente: aceita, mas prende a origem perto da cabeca do personagem.
local function sanitizeAim(character: Model, origin: any, aimPoint: any): (Vector3?, Vector3?)
	local head = character:FindFirstChild("Head") :: BasePart?
	if not head or not isFiniteVector(origin) or not isFiniteVector(aimPoint) then
		return nil, nil
	end
	local o = origin :: Vector3
	if (o - head.Position).Magnitude > Settings.MaxAimOriginOffset then
		o = head.Position
	end
	local a = aimPoint :: Vector3
	if (a - o).Magnitude < 0.1 then
		a = o + head.CFrame.LookVector
	end
	return o, a
end

local function stopChannel(player: Player)
	local state = states[player]
	if state and state.Channel then
		state.Channel.Stopped = true
		state.Channel = nil
	end
end

local function cast(player: Player, slot: any, origin: any, aimPoint: any)
	local state = states[player]
	local character = player.Character
	if not state or not character or typeof(slot) ~= "number" or state.Channel then
		return
	end
	local spellId = player:GetAttribute("Slot" .. tostring(math.floor(slot)))
	local spell = if typeof(spellId) == "string" then Spells.get(spellId) else nil
	local stats = StatsService.get(character)
	if not spell or not stats or stats.Humanoid.Health <= 0 then
		return
	end
	if StatusService.has(character, States.Paralyzed) then
		feedbackRemote:FireClient(player, "Paralyzed", slot)
		return
	end
	local aimOrigin, aimTarget = sanitizeAim(character, origin, aimPoint)
	if not aimOrigin or not aimTarget then
		return
	end

	local now = Workspace:GetServerTimeNow()
	local channeled = SpellCatalog.isChanneled(spell.Id)
	if now < state.GcdUntil then
		return -- recarga global: silenciosa (acontece ao apertar rapido)
	end
	if now < (state.Cooldowns[spell.Id] or 0) then
		feedbackRemote:FireClient(player, "Cooldown", slot)
		return
	end

	-- Custo (mana e/ou vida). Custo de vida nunca mata: precisa sobrar 1 ponto.
	local row = spell.Row
	local mods = Modifiers.gather(player, spell.Id, row.School)
	local manaCost = row.ManaCost * mods.CostMultiplier
	local healthCost = row.HealthCostPct * stats.Humanoid.MaxHealth * mods.CostMultiplier
	if stats.Mana < manaCost then
		feedbackRemote:FireClient(player, "Mana", slot)
		return
	end
	if healthCost > 0 and stats.Humanoid.Health <= healthCost + 1 then
		feedbackRemote:FireClient(player, "Health", slot)
		return
	end
	StatsService.trySpendMana(stats, manaCost)
	if healthCost > 0 then
		stats.Humanoid.Health -= healthCost
	end

	-- Recargas: da magia e global (canalizadas nao tem nenhuma das duas).
	local cooldown = row.Cooldown * mods.CooldownMultiplier / stats.CastSpeed
	if cooldown > 0 then
		state.Cooldowns[spell.Id] = now + cooldown
	end
	if not channeled then
		state.GcdUntil = now + Settings.GlobalCooldown / stats.CastSpeed
	end
	spellStateRemote:FireClient(player, spell.Id, state.Cooldowns[spell.Id] or 0, state.GcdUntil)

	ProgressionService.recordCast(player, row.School)
	StaffService.setSchool(character, row.School)
	vfx:FireAllClients("Cast", {
		Caster = character,
		School = row.School,
		Tier = row.Tier,
		SpellId = spell.Id,
		Channeled = channeled,
		Slot = math.floor(slot),
	})

	local ctx: Context.Context = {
		Player = player,
		Caster = character,
		Spell = spell,
		Mods = mods,
		Origin = aimOrigin,
		AimPoint = aimTarget,
		Stopped = false,
	}
	local kind = spell.Def.Kind
	if kind == "Projectile" then
		Projectile.cast(ctx)
	elseif kind == "Hitscan" then
		Hitscan.cast(ctx)
	elseif kind == "Strike" then
		Area.strike(ctx)
	elseif kind == "Nova" then
		Area.nova(ctx)
	elseif kind == "Line" then
		Area.line(ctx)
	elseif kind == "ChainLightning" then
		state.Channel = ctx
		ctx.OnEnded = function()
			if state.Channel == ctx then
				state.Channel = nil
			end
		end
		ChainLightning.start(ctx)
	end
end

function SpellService.equip(player: Player, spellId: string, slot: number)
	if Spells.get(spellId) and slot >= 1 and slot <= SpellCatalog.NumSlots then
		-- A mesma magia em dois slots: libera o antigo.
		for i = 1, SpellCatalog.NumSlots do
			if player:GetAttribute("Slot" .. i) == spellId then
				player:SetAttribute("Slot" .. i, nil)
			end
		end
		player:SetAttribute("Slot" .. slot, spellId)
	end
end

function SpellService.init()
	local function setup(player: Player)
		states[player] = { Cooldowns = {}, GcdUntil = 0, Channel = nil }
		for i, spellId in SpellCatalog.StartingSlots do
			player:SetAttribute("Slot" .. i, spellId)
		end
		player.CharacterRemoving:Connect(function()
			stopChannel(player)
		end)
	end
	Players.PlayerAdded:Connect(setup)
	for _, player in Players:GetPlayers() do
		setup(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		stopChannel(player)
		states[player] = nil
	end)

	Net.get("CastRequest").OnServerEvent:Connect(cast)
	Net.get("ChannelStop").OnServerEvent:Connect(function(player)
		stopChannel(player)
	end)
	Net.get("AimUpdate").OnServerEvent:Connect(function(player, origin, aimPoint)
		local state = states[player]
		local channel = state and state.Channel
		if channel and player.Character then
			local o, a = sanitizeAim(player.Character, origin, aimPoint)
			if o and a then
				channel.Origin, channel.AimPoint = o, a
			end
		end
	end)
	Net.get("EquipSpell").OnServerEvent:Connect(function(player, spellId, slot)
		if typeof(spellId) == "string" and typeof(slot) == "number" then
			SpellService.equip(player, spellId, math.floor(slot))
		end
	end)
end

function SpellService.start()
	Projectile.start()
end

return SpellService
