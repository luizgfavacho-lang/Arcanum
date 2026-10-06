--!strict
-- Indicador de mira no chao (como em LoL/DotA): mostra a area da magia SELECIONADA antes de
-- conjurar. Circulo no ponto mirado (limitado ao alcance), circulo em volta do mago, faixa a frente
-- (Espinhos) ou faixa atravessada (Muralha). Forma em Shared/AimShape; so visual, nada vai ao servidor.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local AimShape = require(Shared.AimShape)
local Spells = require(Shared.Spells)
local Units = require(Shared.Units)
local Vfx = script.Parent.Parent.Vfx
local Lib = require(Vfx.Lib)
local ClientState = require(script.Parent.ClientState)
local CameraController = require(script.Parent.CameraController)

local AimIndicator = {}

local FLAT = Vector3.new(1, 0, 1)
local UP = Vector3.yAxis

type Visual = {
	SpellId: string,
	Shape: AimShape.Shape,
	Ring: Lib.GroundDecal?,
	Seal: Lib.GroundDecal?,
	Strip: BasePart?,
	Edges: { BasePart },
}

local current: Visual? = nil
local player = Players.LocalPlayer

local function clear()
	local visual = current
	if not visual then
		return
	end
	current = nil
	for _, decal in { visual.Ring, visual.Seal } do
		if decal then
			decal.Part:Destroy()
		end
	end
	if visual.Strip then
		visual.Strip:Destroy()
	end
	for _, edge in visual.Edges do
		edge:Destroy()
	end
end

local function build(spellId: string, shape: AimShape.Shape, palette: Lib.Palette): Visual
	local visual: Visual = { SpellId = spellId, Shape = shape, Ring = nil, Seal = nil, Strip = nil, Edges = {} }
	if shape.Kind == "Target" or shape.Kind == "Self" then
		local size = Units.meters(shape.Radius) * 2
		visual.Ring = Lib.groundDecal(Vector3.zero, size * 1.05, Lib.Catalog.SoftRing, palette.Halo, {
			Brightness = 1.2,
			Transparency = 0.35,
		})
		visual.Seal = Lib.groundDecal(Vector3.zero, size, Lib.circleTexture(palette), palette.Halo, {
			Brightness = 1,
			Transparency = 0.78,
			Lift = 0.33,
		})
	else
		visual.Strip = Lib.part(Vector3.one, palette.Halo, CFrame.identity, {
			Material = Enum.Material.SmoothPlastic,
			Transparency = 0.78,
		})
		for _ = 1, 2 do
			table.insert(visual.Edges, Lib.part(Vector3.one, palette.Halo, CFrame.identity, { Transparency = 0.35 }))
		end
	end
	return visual
end

-- Faixa no chao: centro, direcao do comprimento, comprimento e largura.
local function placeStrip(visual: Visual, center: Vector3, along: Vector3, length: number, width: number)
	local frame = CFrame.lookAt(center + UP * 0.35, center + UP * 0.35 + along)
	local strip = visual.Strip :: BasePart
	strip.Size = Vector3.new(width, 0.06, length)
	strip.CFrame = frame
	local side = along:Cross(UP)
	for i, edge in visual.Edges do
		local s = if i == 1 then -1 else 1
		edge.Size = Vector3.new(0.12, 0.1, length)
		edge.CFrame = frame + side * s * width / 2
	end
end

local function aimDirection(root: Vector3, aim: Vector3): Vector3
	local flat = (aim - root) * FLAT
	if flat.Magnitude < 1e-3 then
		local camera = Workspace.CurrentCamera
		flat = camera.CFrame.LookVector * FLAT
	end
	return if flat.Magnitude > 1e-3 then flat.Unit else Vector3.zAxis
end

local function update()
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local spellId = player:GetAttribute("Slot" .. ClientState.SelectedSlot)
	if
		not character
		or not root
		or not humanoid
		or humanoid.Health <= 0
		or typeof(spellId) ~= "string"
		or ClientState.GrimoireOpen
		or CameraController.MouseFree
	then
		clear()
		return
	end
	local spell = Spells.get(spellId)
	local shape = spell and AimShape.of(spell.Def, spell.Row)
	if not spell or not shape then
		clear()
		return
	end
	if not current or current.SpellId ~= spellId then
		clear()
		current = build(spellId, shape, Lib.palette(spell.Row.School))
	end
	local visual = current :: Visual
	local _, aim = CameraController.getAim()
	local rootPosition = root.Position
	local direction = aimDirection(rootPosition, aim)
	local t = os.clock()

	if shape.Kind == "Target" or shape.Kind == "Wall" then
		-- Ponto mirado, puxado de volta para dentro do alcance.
		local range = Units.meters(shape.Range)
		local offset = (aim - rootPosition) * FLAT
		local point = if offset.Magnitude > range then rootPosition + offset.Unit * range else aim
		local ground = Lib.groundBelow(Vector3.new(point.X, math.max(point.Y, rootPosition.Y) + 4, point.Z), character)
		if shape.Kind == "Target" then
			for i, decal in { visual.Ring, visual.Seal } do
				if decal then
					local lift = if i == 1 then 0.35 else 0.33
					decal.Part.CFrame = CFrame.new(ground + UP * lift) * CFrame.Angles(0, t * 0.6 * i, 0)
				end
			end
		else
			placeStrip(visual, ground, direction:Cross(UP), Units.meters(shape.Width), 1.2)
		end
	elseif shape.Kind == "Self" then
		local ground = Lib.groundBelow(rootPosition, character)
		for i, decal in { visual.Ring, visual.Seal } do
			if decal then
				local lift = if i == 1 then 0.35 else 0.33
				decal.Part.CFrame = CFrame.new(ground + UP * lift) * CFrame.Angles(0, t * 0.6 * i, 0)
			end
		end
	elseif shape.Kind == "Line" then
		local length = Units.meters(shape.Range)
		local start = Lib.groundBelow(rootPosition, character) + direction * 1.5
		placeStrip(visual, start + direction * length / 2, direction, length, Units.meters(shape.Width))
	end
end

function AimIndicator.start()
	RunService.RenderStepped:Connect(update)
end

-- Para o teste de fumaca: um quadro com a magia do slot selecionado.
AimIndicator.debugStep = update

return AimIndicator
