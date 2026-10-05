--!strict
-- Camera de ombro para conjurar: atras do ombro ESQUERDO, um pouco mais alta e afastada.
-- O cajado fica do lado direito, entao a gema, a conjuracao e o comeco do trajeto aparecem
-- a direita da mira. Mouse travado no centro; o personagem vira com a camera.
-- Alt esquerdo solta o mouse (para clicar na interface).
--
-- Mira: raio exato pelo centro da tela (sem assistencia). AimTarget = inimigo sob a mira (so
-- para o HUD pintar a mira). "Juice": tremor (shake) e leve aumento de FOV ao conjurar.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer

local SHOULDER_OFFSET = Vector3.new(-2.4, 1.4, 0)
local ZOOM = 16
local BASE_FOV = 72
local AIM_DISTANCE = 600

local CameraController = {}

CameraController.MouseFree = false
CameraController.AimTarget = nil :: Model?
-- Intensidade global de tremor/flash (opcao de acessibilidade; 0 desliga).
CameraController.ShakeScale = 1

local trauma = 0 -- 0..1, decai sozinho; tremor = trauma^2
local fovKick = 0

-- Tremor de camera: intensity ~0.2 (leve) a 1 (forte). Soma e satura em 1.
function CameraController.shake(intensity: number)
	trauma = math.min(trauma + intensity * CameraController.ShakeScale, 1)
end

-- Aumento rapido de FOV que volta sozinho (conjuracoes fortes).
function CameraController.kick(degrees: number)
	fovKick = math.max(fovKick, degrees * CameraController.ShakeScale)
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
	-- Ignora o proprio personagem, aliados (sem fogo amigo) e os efeitos visuais.
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

-- Retorna (origem para o servidor, ponto mirado exato, inimigo sob a mira ou nil).
function CameraController.getAim(): (Vector3, Vector3, Model?)
	local camera = Workspace.CurrentCamera
	local viewport = camera.ViewportSize
	local ray = camera:ViewportPointToRay(viewport.X / 2, viewport.Y / 2)
	local result = Workspace:Raycast(ray.Origin, ray.Direction * AIM_DISTANCE, aimParams())
	local aimPoint = if result then result.Position else ray.Origin + ray.Direction * AIM_DISTANCE

	local target: Model? = nil
	if result then
		local model = combatantOf(result.Instance)
		local humanoid = model and model:FindFirstChildOfClass("Humanoid")
		local myTeam = player.Character and player.Character:GetAttribute("Team")
		if model and humanoid and humanoid.Health > 0 and model:GetAttribute("Team") ~= myTeam then
			target = model
		end
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
	player.CharacterAdded:Connect(onCharacter)
	if player.Character then
		onCharacter(player.Character)
	end

	UserInputService.InputBegan:Connect(function(input, processed)
		if not processed and input.KeyCode == Enum.KeyCode.LeftAlt then
			CameraController.MouseFree = not CameraController.MouseFree
		end
	end)

	local noiseSeed = math.random() * 100
	RunService:BindToRenderStep("ArcanumCamera", Enum.RenderPriority.Camera.Value + 1, function(dt)
		local camera = Workspace.CurrentCamera
		UserInputService.MouseBehavior = if CameraController.MouseFree
			then Enum.MouseBehavior.Default
			else Enum.MouseBehavior.LockCenter
		UserInputService.MouseIconEnabled = CameraController.MouseFree

		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if root and humanoid and humanoid.Health > 0 and humanoid.WalkSpeed > 0 then
			local look = camera.CFrame.LookVector
			local flat = Vector3.new(look.X, 0, look.Z)
			if flat.Magnitude > 1e-3 then
				-- Giro suave do corpo (nao instantaneo).
				local goal = CFrame.lookAt(root.Position, root.Position + flat)
				root.CFrame = root.CFrame:Lerp(goal, 1 - math.exp(-dt * 20))
			end
		end

		-- Tremor (ruido suave, nao aleatorio quadro a quadro) e kick de FOV.
		if trauma > 0 then
			local t = os.clock() * 28
			local amount = trauma * trauma
			local rx = math.noise(noiseSeed, t) * 0.035 * amount
			local ry = math.noise(noiseSeed + 10, t) * 0.035 * amount
			local rz = math.noise(noiseSeed + 20, t) * 0.02 * amount
			camera.CFrame = camera.CFrame * CFrame.Angles(rx, ry, rz)
			trauma = math.max(trauma - dt * 1.6, 0)
		end
		fovKick = fovKick * math.exp(-dt * 7)
		camera.FieldOfView = BASE_FOV + fovKick

		local _, _, target = CameraController.getAim()
		CameraController.AimTarget = target
	end)
end

return CameraController
