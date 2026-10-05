--!strict
-- Camera de ombro estilo "caster": mouse travado no centro (mira), personagem vira com a camera.
-- Alt esquerdo solta o mouse (para clicar na interface).

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local SHOULDER_OFFSET = Vector3.new(2.2, 0.6, 0)
local ZOOM = 14

local CameraController = {}

CameraController.MouseFree = false

-- Ponto mirado pelo centro da tela (ignora o proprio personagem e efeitos).
function CameraController.getAim(): (Vector3, Vector3)
	local camera = Workspace.CurrentCamera
	local character = player.Character
	local viewport = camera.ViewportSize
	local ray = camera:ViewportPointToRay(viewport.X / 2, viewport.Y / 2)

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = if character then { character } else {}
	local result = Workspace:Raycast(ray.Origin, ray.Direction * 600, params)
	local aimPoint = if result then result.Position else ray.Origin + ray.Direction * 600

	local head = character and character:FindFirstChild("Head") :: BasePart?
	local origin = if head then head.Position else ray.Origin
	return origin, aimPoint
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
	end)
end

return CameraController
