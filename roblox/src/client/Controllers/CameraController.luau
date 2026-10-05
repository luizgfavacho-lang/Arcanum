--!strict
-- Camera de ombro para conjurar: atras do ombro ESQUERDO, um pouco mais alta e afastada.
-- O cajado fica do lado direito, entao a gema, a conjuracao e o comeco do trajeto aparecem
-- a direita da mira. Mouse travado no centro; o personagem vira com a camera.
-- Alt esquerdo solta o mouse (para clicar na interface).
--
-- Mira: raio pelo centro da tela + assistencia leve (esfera de AIM_ASSIST_RADIUS). Se passar perto
-- de um inimigo, a mira trava no centro do corpo dele (o HUD pinta a mira de vermelho).

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer

local SHOULDER_OFFSET = Vector3.new(-2.4, 1.4, 0) -- ombro esquerdo, acima da cabeca
local ZOOM = 16
local FIELD_OF_VIEW = 72
local AIM_DISTANCE = 600
local AIM_ASSIST_RADIUS = 1.6

local CameraController = {}

CameraController.MouseFree = false
-- Atualizado a cada quadro (o HUD usa para colorir a mira).
CameraController.AimTarget = nil :: Model?

local function isHostile(model: Model): boolean
	local character = player.Character
	local myTeam = character and character:GetAttribute("Team")
	local team = model:GetAttribute("Team")
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	return team ~= nil and team ~= myTeam and humanoid ~= nil and humanoid.Health > 0
end

local function combatantOf(instance: Instance): Model?
	local model = instance:FindFirstAncestorOfClass("Model")
	while model do
		if model:GetAttribute("Team") ~= nil then
			return model
		end
		model = model:FindFirstAncestorOfClass("Model")
	end
	return nil
end

local function aimParams(): RaycastParams
	-- Ignora todos os jogadores (sem fogo amigo) e os efeitos visuais.
	local ignore: { Instance } = {}
	for _, other in Players:GetPlayers() do
		if other.Character then
			table.insert(ignore, other.Character)
		end
	end
	local effects = Workspace:FindFirstChild("ClientEffects")
	if effects then
		table.insert(ignore, effects)
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignore
	return params
end

-- Retorna (origem para o servidor, ponto mirado, alvo travado ou nil).
function CameraController.getAim(): (Vector3, Vector3, Model?)
	local camera = Workspace.CurrentCamera
	local viewport = camera.ViewportSize
	local ray = camera:ViewportPointToRay(viewport.X / 2, viewport.Y / 2)
	local params = aimParams()

	-- 1) Assistencia: esfera fina pelo centro da tela procura um inimigo.
	local target: Model? = nil
	local assist = Workspace:Spherecast(ray.Origin, AIM_ASSIST_RADIUS, ray.Direction * AIM_DISTANCE, params)
	if assist then
		local model = combatantOf(assist.Instance)
		if model and isHostile(model) then
			target = model
		end
	end

	-- 2) Ponto mirado: centro do inimigo travado, ou o que o raio exato acertar.
	local aimPoint: Vector3
	local root = target and target:FindFirstChild("HumanoidRootPart") :: BasePart?
	if root then
		aimPoint = root.Position
	else
		local result = Workspace:Raycast(ray.Origin, ray.Direction * AIM_DISTANCE, params)
		aimPoint = if result then result.Position else ray.Origin + ray.Direction * AIM_DISTANCE
	end

	local character = player.Character
	local head = character and character:FindFirstChild("Head") :: BasePart?
	local origin = if head then head.Position else ray.Origin
	return origin, aimPoint, target
end

local function onCharacter(character: Model)
	local humanoid = character:WaitForChild("Humanoid") :: Humanoid
	humanoid.CameraOffset = SHOULDER_OFFSET
	humanoid.AutoRotate = false
end

function CameraController.start()
	player.CameraMinZoomDistance = ZOOM
	player.CameraMaxZoomDistance = ZOOM
	Workspace.CurrentCamera.FieldOfView = FIELD_OF_VIEW
	player.CharacterAdded:Connect(onCharacter)
	if player.Character then
		onCharacter(player.Character)
	end

	UserInputService.InputBegan:Connect(function(input, processed)
		if not processed and input.KeyCode == Enum.KeyCode.LeftAlt then
			CameraController.MouseFree = not CameraController.MouseFree
		end
	end)

	RunService:BindToRenderStep("ArcanumCamera", Enum.RenderPriority.Camera.Value + 1, function()
		UserInputService.MouseBehavior = if CameraController.MouseFree
			then Enum.MouseBehavior.Default
			else Enum.MouseBehavior.LockCenter
		UserInputService.MouseIconEnabled = CameraController.MouseFree

		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if root and humanoid and humanoid.Health > 0 and humanoid.WalkSpeed > 0 then
			local look = Workspace.CurrentCamera.CFrame.LookVector
			local flat = Vector3.new(look.X, 0, look.Z)
			if flat.Magnitude > 1e-3 then
				root.CFrame = CFrame.lookAt(root.Position, root.Position + flat)
			end
		end

		local _, _, target = CameraController.getAim()
		CameraController.AimTarget = target
	end)
end

return CameraController
