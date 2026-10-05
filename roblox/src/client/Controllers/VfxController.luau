--!strict
-- Recebe os eventos visuais do servidor (Vfx/VfxFast) e aciona os modulos de client/Vfx.
-- Tudo aqui e cosmetico: nenhuma regra de jogo roda no cliente.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Net = require(Shared.Net)
local Spells = require(Shared.Spells)

local Vfx = script.Parent.Parent.Vfx
local Lib = require(Vfx.Lib)
local Effects = require(Vfx.Effects)
local Lightning = require(Vfx.Lightning)
local Projectiles = require(Vfx.Projectiles)
local LifeStream = require(Vfx.LifeStream)
local Numbers = require(Vfx.Numbers)
local Staff = require(Vfx.Staff)
local Auras = require(Vfx.Auras)
local ClientState = require(script.Parent.ClientState)

local player = Players.LocalPlayer

local VfxController = {}

local HANDLERS: { [string]: (any) -> () } = {
	Cast = function(p)
		if not p.Caster or not p.Caster.Parent then
			return
		end
		local palette = Lib.palette(p.School)
		Staff.cast(p.Caster, palette)
		Effects.castSignature(p.Caster, palette, p.Tier or 1)
	end,

	-- Faisca: raio ramificado que tremula, faiscas com gravidade e clarao no alvo.
	Bolt = function(p)
		local palette = Lib.palette(p.School)
		local from = Lib.muzzleOf(p.Caster, p.From)
		Lightning.bolt(from, p.To, palette, { Width = 0.22, Forks = 3, Flickers = 3, Duration = 0.2 })
		Effects.flash(from, palette, 0.8, false)
		if p.Hit then
			Effects.flash(p.To, palette, 1.4, true)
			Lib.burst(p.To, "Spark", palette, 18)
		end
	end,

	-- Drenar Vida: corrente de vida do alvo ate a gema.
	LifeStream = function(p)
		local palette = Lib.palette(p.School)
		if p.Hit and p.Caster then
			LifeStream.play(p.To, p.Caster, palette)
			Effects.flash(p.To, palette, 1, false)
		else
			Lib.burst(p.To, "Wisp", palette, 6)
		end
	end,

	ProjectileSpawn = Projectiles.spawn,
	ProjectileEnd = Projectiles.finish,

	-- Corrente em Cadeia: a cada tick, fios trancados por elo e faiscas em cada alvo.
	Chain = function(p)
		local palette = Lib.palette(p.School)
		local points = table.clone(p.Points)
		points[1] = Lib.muzzleOf(p.Caster, points[1])
		for i = 1, #points - 1 do
			Lightning.braid(points[i], points[i + 1], palette, if i == 1 then 7 else 5, 0.12)
			if math.random() < 0.5 then
				Lib.burst(points[i + 1], "Spark", palette, 4)
			end
		end
		if math.random() < 0.3 then
			Lib.burst(points[1], "Star", palette, 3, { Speed = NumberRange.new(2, 5) })
		end
	end,

	ChannelEnd = function(_) end,

	Damage = function(p)
		if p.Target and p.Target.Parent then
			Numbers.damage(p.Target, p.Amount, Lib.palette(p.School), p.Periodic == true)
		end
	end,

	Heal = function(p)
		if p.Target and p.Target.Parent then
			Numbers.heal(p.Target, p.Amount)
			local root = Lib.rootPosition(p.Target)
			if root then
				Lib.burst(root, "Wisp", Lib.palette("Necromancy"), 8)
			end
		end
	end,
}

local function dispatch(kind: string, payload: any)
	local handler = HANDLERS[kind]
	if handler then
		handler(payload)
	end
end

-- A gema do proprio cajado mostra a escola da magia selecionada.
local function tintSelected()
	local spellId = player:GetAttribute("Slot" .. ClientState.SelectedSlot)
	local spell = if typeof(spellId) == "string" then Spells.get(spellId) else nil
	if spell then
		Staff.tintLocal(player.Character, Lib.palette(spell.Row.School))
	end
end

function VfxController.start()
	Lib.folder()
	Projectiles.start()
	Numbers.start()
	Staff.start()
	Auras.start()

	Net.get("Vfx").OnClientEvent:Connect(dispatch)
	Net.get("VfxFast").OnClientEvent:Connect(dispatch)

	ClientState.SelectedChanged:Connect(tintSelected)
	player.CharacterAdded:Connect(function(character)
		character:WaitForChild("ArcanumStaff", 10)
		tintSelected()
	end)
end

return VfxController
