--!strict
-- Recebe os eventos visuais do servidor (Vfx/VfxFast/CastFeedback) e aciona os modulos de
-- client/Vfx, o HUD e a camera. Tudo aqui e cosmetico: nenhuma regra de jogo roda no cliente.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

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
local Audio = require(Vfx.Audio)
local ClientState = require(script.Parent.ClientState)
local CameraController = require(script.Parent.CameraController)
local HudController = require(script.Parent.HudController)

local player = Players.LocalPlayer

local VfxController = {}

local function isMine(model: any): boolean
	return model ~= nil and model == player.Character
end

local function distanceToMe(position: Vector3): number
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	return if root then (root.Position - position).Magnitude else math.huge
end

-- Tremor proporcional a distancia (impactos perto tremem mais).
local function shakeNear(position: Vector3, strength: number, radius: number)
	local d = distanceToMe(position)
	if d < radius then
		CameraController.shake(strength * (1 - d / radius))
	end
end

-- Flash branco rapido no corpo atingido.
local function hitFlash(model: Model)
	local existing = model:FindFirstChild("ArcanumHitFlash")
	if existing then
		existing:Destroy()
	end
	local highlight = Instance.new("Highlight")
	highlight.Name = "ArcanumHitFlash"
	highlight.FillColor = Color3.new(1, 1, 1)
	highlight.FillTransparency = 0.35
	highlight.OutlineTransparency = 1
	highlight.DepthMode = Enum.HighlightDepthMode.Occluded
	highlight.Parent = model
	TweenService:Create(highlight, TweenInfo.new(0.14), { FillTransparency = 1 }):Play()
	task.delay(0.15, function()
		highlight:Destroy()
	end)
end

-- Morte: o corpo se desfaz em luz da escola e sobe levemente.
local function dissolve(model: Model, palette: Lib.Palette, boss: boolean)
	local root = Lib.rootPosition(model)
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
			part.CanCollide = false
			TweenService:Create(part, TweenInfo.new(1.1, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
				Transparency = 1,
				Color = palette.Halo,
			}):Play()
		elseif part:IsA("Decal") then
			TweenService:Create(part, TweenInfo.new(0.8), { Transparency = 1 }):Play()
		end
	end
	if root then
		local scale = if boss then 2.5 else 1
		Effects.flash(root, palette, 1.6 * scale, true)
		Lib.burst(root, "Wisp", palette, math.floor(24 * scale), { Speed = NumberRange.new(3, 9) })
		Lib.burst(root, "Star", palette, math.floor(14 * scale))
		Effects.shockwave(root - Vector3.new(0, 2.8, 0), palette, 5 * scale)
		Audio.play("Death", root)
	end
end

local HANDLERS: { [string]: (any) -> () } = {
	Cast = function(p)
		if not p.Caster or not p.Caster.Parent then
			return
		end
		local palette = Lib.palette(p.School)
		Staff.cast(p.Caster, palette)
		Effects.castSignature(p.Caster, palette, p.Tier or 1)
		local muzzle = Lib.muzzleOf(p.Caster, Lib.rootPosition(p.Caster) or Vector3.zero)
		if not p.Channeled then
			Effects.flash(muzzle, palette, 0.9, false)
		end
		Audio.play("Cast_" .. tostring(p.School), muzzle)
		if isMine(p.Caster) then
			HudController.castPulse(p.Slot or ClientState.SelectedSlot)
			CameraController.shake(0.12 + 0.05 * (p.Tier or 1))
			CameraController.kick(1.5 + (p.Tier or 1))
		end
	end,

	-- Faisca: raio ramificado que tremula, faiscas caindo e clarao no alvo.
	Bolt = function(p)
		local palette = Lib.palette(p.School)
		local from = Lib.muzzleOf(p.Caster, p.From)
		Lightning.bolt(from, p.To, palette, { Width = 0.22, Forks = 3, Flickers = 3, Duration = 0.2 })
		Audio.play("Bolt", from)
		if p.Hit then
			Effects.flash(p.To, palette, 1.4, true)
			Lib.burst(p.To, "Spark", palette, 18)
			shakeNear(p.To, 0.15, 40)
		end
	end,

	-- Drenar Vida: corrente de vida do alvo ate a gema.
	LifeStream = function(p)
		local palette = Lib.palette(p.School)
		if p.Hit and p.Caster then
			LifeStream.play(p.To, p.Caster, palette)
			Effects.flash(p.To, palette, 1, false)
			Audio.play("LifeDrain", p.To)
		else
			Lib.burst(p.To, "Wisp", palette, 6)
		end
	end,

	ProjectileSpawn = Projectiles.spawn,
	ProjectileEnd = function(p)
		Projectiles.finish(p)
		Audio.play("Impact_" .. tostring(p.School), p.Position)
		shakeNear(p.Position, if p.Radius and p.Radius > 0 then 0.6 else 0.35, 55)
	end,

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
		if isMine(p.Caster) then
			CameraController.shake(0.04)
		end
	end,

	ChannelEnd = function(_) end,

	Damage = function(p)
		local target = p.Target
		if not target or not target.Parent then
			return
		end
		Numbers.damage(target, p.Amount, Lib.palette(p.School), p.Periodic == true)
		if not p.Periodic then
			hitFlash(target)
		end
		if isMine(p.Source) and not p.Periodic then
			HudController.hitmarker(p.Killed == true)
		end
		if isMine(target) then
			CameraController.shake(math.clamp(p.Amount / 8, 0.15, 0.6))
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

	Death = function(p)
		if p.Model and p.Model.Parent then
			dissolve(p.Model, Lib.palette(p.School), p.Boss == true)
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

-- Subiu de nivel: circulo dourado e luz subindo em volta do mago.
local function levelUpEffect()
	local character = player.Character
	local root = character and Lib.rootPosition(character)
	if not root then
		return
	end
	local gold = {
		Core = Color3.fromRGB(255, 250, 220),
		Halo = Color3.fromRGB(255, 200, 80),
		Accent = Color3.fromRGB(255, 150, 40),
		Shape = "",
	}
	Effects.runeCircle(root - Vector3.new(0, 2.9, 0), gold, 5, 1.4)
	Effects.shockwave(root - Vector3.new(0, 2.9, 0), gold, 9)
	Lib.burst(root, "Wisp", gold, 40, { Speed = NumberRange.new(4, 10) })
	Audio.play("LevelUp", root)
	CameraController.kick(4)
end

function VfxController.start()
	Lib.folder()
	Projectiles.start()
	Numbers.start()
	Staff.start()
	Auras.start()

	Net.get("Vfx").OnClientEvent:Connect(dispatch)
	Net.get("VfxFast").OnClientEvent:Connect(dispatch)
	Net.get("CastFeedback").OnClientEvent:Connect(function(reason: string, slot: number)
		HudController.feedback(reason, slot)
		Audio.play("Fail", nil)
	end)

	ClientState.SelectedChanged:Connect(function()
		tintSelected()
		Audio.play("Select", nil)
	end)
	player.CharacterAdded:Connect(function(character)
		character:WaitForChild("ArcanumStaff", 10)
		task.wait(0.2)
		tintSelected()
	end)

	local lastLevel = player:GetAttribute("Level") or 1
	player:GetAttributeChangedSignal("Level"):Connect(function()
		local level = player:GetAttribute("Level") or 1
		if level > lastLevel then
			levelUpEffect()
		end
		lastLevel = level
	end)
end

return VfxController
