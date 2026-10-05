--!strict
-- Teclas 1-5 conjuram o slot; clique esquerdo conjura o slot selecionado; roda do mouse troca.
-- Canalizadas: segurar envia a mira a cada 0,1 s; soltar encerra.
-- Controle: RT conjura o selecionado, LB/RB trocam.
-- Q / Shift esquerdo / B: esquiva na direcao do movimento (parado: para tras). O impulso e aplicado
-- aqui mesmo (o cliente e dono da fisica do personagem); o servidor so abre a invulnerabilidade.

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local Net = require(Shared.Net)
local Settings = require(Shared.Config.CombatSettings)
local SpellCatalog = require(Shared.SpellCatalog)
local CameraController = require(script.Parent.CameraController)
local ClientState = require(script.Parent.ClientState)
local HudController = require(script.Parent.HudController)
local VfxController = require(script.Parent.VfxController)

local player = Players.LocalPlayer
local castRemote = Net.get("CastRequest")
local aimRemote = Net.get("AimUpdate")
local stopRemote = Net.get("ChannelStop")
local dodgeRemote = Net.get("Dodge")

local AIM_UPDATE_INTERVAL = 0.1
local SLOT_KEYS = { Enum.KeyCode.One, Enum.KeyCode.Two, Enum.KeyCode.Three, Enum.KeyCode.Four, Enum.KeyCode.Five }

local InputController = {}

local heldSlot: number? = nil
local lastDodge = -math.huge

local function dodge()
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not character or not root or not humanoid or humanoid.Health <= 0 then
		return
	end
	if character:GetAttribute("State_Paralyzed") then
		return
	end
	local now = os.clock()
	if now - lastDodge < Settings.DodgeCooldown then
		return
	end
	lastDodge = now

	local move = humanoid.MoveDirection
	local direction: Vector3
	if move.Magnitude > 0.1 then
		direction = Vector3.new(move.X, 0, move.Z).Unit
	else
		local look = Workspace.CurrentCamera.CFrame.LookVector
		local back = Vector3.new(-look.X, 0, -look.Z)
		direction = if back.Magnitude > 0.01 then back.Unit else -root.CFrame.LookVector
	end
	dodgeRemote:FireServer(direction)

	-- Impulso horizontal curto (a gravidade continua agindo).
	local attachment = root:FindFirstChild("DodgeAttachment") :: Attachment?
	if not attachment then
		local a = Instance.new("Attachment")
		a.Name = "DodgeAttachment"
		a.Parent = root
		attachment = a
	end
	local dash = Instance.new("LinearVelocity")
	dash.Attachment0 = attachment
	dash.RelativeTo = Enum.ActuatorRelativeTo.World
	dash.VelocityConstraintMode = Enum.VelocityConstraintMode.Plane
	dash.PrimaryTangentAxis = Vector3.xAxis
	dash.SecondaryTangentAxis = Vector3.zAxis
	dash.PlaneVelocity = Vector2.new(direction.X, direction.Z) * Settings.DodgeSpeed
	dash.MaxForce = math.huge
	dash.Parent = root
	Debris:AddItem(dash, Settings.DodgeDuration)

	HudController.dodged(Settings.DodgeCooldown)
	VfxController.dodgeLocal(character, direction)
end

local function press(slot: number)
	if CameraController.MouseFree then
		return
	end
	local origin, aimPoint = CameraController.getAim()
	castRemote:FireServer(slot, origin, aimPoint)

	local spellId = player:GetAttribute("Slot" .. slot)
	if typeof(spellId) == "string" and SpellCatalog.isChanneled(spellId) then
		heldSlot = slot
		task.spawn(function()
			while heldSlot == slot do
				task.wait(AIM_UPDATE_INTERVAL)
				if heldSlot ~= slot then
					break
				end
				local o, a = CameraController.getAim()
				aimRemote:FireServer(o, a)
			end
		end)
	end
end

local function release(slot: number)
	if heldSlot == slot then
		heldSlot = nil
		stopRemote:FireServer(slot)
	end
end

local function handle(slot: number, state: Enum.UserInputState)
	if state == Enum.UserInputState.Begin then
		press(slot)
	elseif state == Enum.UserInputState.End or state == Enum.UserInputState.Cancel then
		release(slot)
	end
end

function InputController.start()
	for slot, key in SLOT_KEYS do
		ContextActionService:BindAction("ArcanumSlot" .. slot, function(_, state)
			handle(slot, state)
			return Enum.ContextActionResult.Sink
		end, false, key)
	end

	-- O slot selecionado e lido no momento do clique (pode mudar entre press e release).
	local selectedHeld = 1
	ContextActionService:BindAction("ArcanumCastSelected", function(_, state)
		if state == Enum.UserInputState.Begin then
			selectedHeld = ClientState.SelectedSlot
		end
		handle(selectedHeld, state)
		return Enum.ContextActionResult.Sink
	end, false, Enum.UserInputType.MouseButton1, Enum.KeyCode.ButtonR2)

	ContextActionService:BindAction("ArcanumCycle", function(_, state, input)
		if state == Enum.UserInputState.Begin then
			ClientState.select(ClientState.SelectedSlot + (if input.KeyCode == Enum.KeyCode.ButtonL1 then -1 else 1))
		end
		return Enum.ContextActionResult.Sink
	end, false, Enum.KeyCode.ButtonL1, Enum.KeyCode.ButtonR1)

	ContextActionService:BindAction("ArcanumDodge", function(_, state)
		if state == Enum.UserInputState.Begin then
			dodge()
		end
		return Enum.ContextActionResult.Sink
	end, false, Enum.KeyCode.Q, Enum.KeyCode.LeftShift, Enum.KeyCode.ButtonB)

	UserInputService.InputChanged:Connect(function(input, processed)
		if not processed and input.UserInputType == Enum.UserInputType.MouseWheel then
			ClientState.select(ClientState.SelectedSlot + (if input.Position.Z > 0 then -1 else 1))
		end
	end)
end

return InputController
