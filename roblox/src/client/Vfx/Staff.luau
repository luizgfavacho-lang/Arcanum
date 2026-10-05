--!strict
-- Pose de conjuracao com o cajado (cosmetica, roda em cada cliente para todos os personagens):
-- o braco direito ergue o cajado a frente, a haste fica quase vertical e inclinada para o alvo,
-- e a gema pulsa. Mantida enquanto o personagem estiver canalizando (atributo "Channeling").

local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Lib = require(script.Parent.Lib)

local Staff = {}

local RAISE = CFrame.Angles(math.rad(75), 0, 0) -- ombro: braco para a frente
local STAFF_TILT = CFrame.Angles(math.rad(-95), 0, 0) -- haste: compensa o braco e inclina 20° a frente
local HOLD_SECONDS = 0.35

type Pose = { Shoulder: Motor6D, Grip: Weld, ShoulderC0: CFrame, GripC0: CFrame, Until: number }
local posed: { [Model]: Pose } = {}

local function joints(model: Model): (Motor6D?, Weld?)
	local arm = model:FindFirstChild("RightUpperArm")
	local shoulder = arm and arm:FindFirstChild("RightShoulder") :: Motor6D?
	local staff = model:FindFirstChild("ArcanumStaff")
	local shaft = staff and staff:FindFirstChild("Shaft")
	local grip = shaft and shaft:FindFirstChild("StaffGrip") :: Weld?
	return shoulder, grip
end

local function pulseGem(model: Model, palette: Lib.Palette)
	local staff = model:FindFirstChild("ArcanumStaff")
	local gem = staff and staff:FindFirstChild("Gem") :: BasePart?
	if not gem then
		return
	end
	gem.Color = palette.Halo
	local base = Vector3.one * 0.62
	TweenService
		:Create(
			gem,
			TweenInfo.new(0.09, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, true),
			{ Size = base * 1.7 }
		)
		:Play()
	local light = gem:FindFirstChild("GemLight") :: PointLight?
	if light then
		light.Color = palette.Halo
		TweenService:Create(
			light,
			TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, true),
			{ Brightness = 6, Range = 14 }
		):Play()
	end
	-- Faiscas espiralando para dentro da gema.
	local muzzle = gem:FindFirstChild("Muzzle") :: Attachment?
	if muzzle then
		local e = Lib.emitter(muzzle, "Star", palette, {
			Speed = NumberRange.new(-6, -3),
			Lifetime = NumberRange.new(0.18, 0.25),
			Size = Lib.seq(0.3, 0),
		})
		e:Emit(10)
		task.delay(0.4, function()
			e:Destroy()
		end)
	end
end

function Staff.cast(model: Model, palette: Lib.Palette)
	pulseGem(model, palette)
	local existing = posed[model]
	if existing then
		existing.Until = os.clock() + HOLD_SECONDS
		return
	end
	local shoulder, grip = joints(model)
	if not shoulder or not grip then
		return
	end
	local pose: Pose = {
		Shoulder = shoulder,
		Grip = grip,
		ShoulderC0 = shoulder.C0,
		GripC0 = grip.C0,
		Until = os.clock() + HOLD_SECONDS,
	}
	posed[model] = pose
	local info = TweenInfo.new(0.08, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
	TweenService:Create(shoulder, info, { C0 = pose.ShoulderC0 * RAISE }):Play()
	TweenService:Create(grip, info, { C0 = STAFF_TILT * pose.GripC0 }):Play()
end

local function release(model: Model, pose: Pose)
	posed[model] = nil
	local info = TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	if pose.Shoulder.Parent then
		TweenService:Create(pose.Shoulder, info, { C0 = pose.ShoulderC0 }):Play()
	end
	if pose.Grip.Parent then
		TweenService:Create(pose.Grip, info, { C0 = pose.GripC0 }):Play()
	end
end

-- Cor local da gema do proprio personagem (feedback imediato ao trocar de magia).
function Staff.tintLocal(model: Model?, palette: Lib.Palette)
	local staff = model and model:FindFirstChild("ArcanumStaff")
	if not staff then
		return
	end
	for _, name in { "Gem", "GemShell" } do
		local part = staff:FindFirstChild(name) :: BasePart?
		if part then
			part.Color = palette.Halo
		end
	end
end

function Staff.start()
	RunService.RenderStepped:Connect(function()
		local now = os.clock()
		for model, pose in posed do
			if not model.Parent then
				posed[model] = nil
			elseif model:GetAttribute("Channeling") then
				pose.Until = now + 0.1
			elseif now > pose.Until then
				release(model, pose)
			end
		end
	end)
end

return Staff
