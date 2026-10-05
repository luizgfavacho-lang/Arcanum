--!strict
-- Da um cajado a todo mago (jogadores e criaturas magicas), preso a mao direita pela Weld
-- "StaffGrip". A gema muda para a cor da escola da ultima magia conjurada (replica para todos).
-- O cliente anima a pose de conjuracao localmente (client/Vfx/Staff.luau).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Schools = require(ReplicatedStorage.Shared.Schools)
local StaffBuilder = require(script.Parent.Parent.Combat.StaffBuilder)

local StaffService = {}

-- Haste vertical na mao, um pouco a frente; o eixo X da haste vira o eixo Y da mao.
local GRIP_C0 = CFrame.new(0, 1.05, -0.15) * CFrame.Angles(0, 0, math.rad(90))

function StaffService.equip(character: Model, school: string?)
	if character:FindFirstChild("ArcanumStaff") then
		return
	end
	local hand = character:WaitForChild("RightHand", 10) :: BasePart?
	if not hand then
		return
	end
	local palette = Schools[school or "Energy"] or Schools.Energy
	local staff = StaffBuilder.build(palette.Halo)
	local shaft = staff.PrimaryPart :: BasePart

	local grip = Instance.new("Weld")
	grip.Name = "StaffGrip"
	grip.Part0 = hand
	grip.Part1 = shaft
	grip.C0 = GRIP_C0
	grip.Parent = shaft

	staff.Parent = character
end

function StaffService.getMuzzle(character: Model): Attachment?
	local staff = character:FindFirstChild("ArcanumStaff")
	local gem = staff and staff:FindFirstChild("Gem")
	return gem and gem:FindFirstChild("Muzzle") :: Attachment?
end

-- A gema assume a cor da escola conjurada.
function StaffService.setSchool(character: Model, school: string)
	local palette = Schools[school]
	local staff = character:FindFirstChild("ArcanumStaff")
	if not palette or not staff then
		return
	end
	character:SetAttribute("StaffSchool", school)
	for _, name in { "Gem", "GemShell" } do
		local part = staff:FindFirstChild(name) :: BasePart?
		if part then
			part.Color = palette.Halo
		end
	end
	local gem = staff:FindFirstChild("Gem")
	local light = gem and gem:FindFirstChild("GemLight") :: PointLight?
	if light then
		light.Color = palette.Halo
	end
	local muzzle = gem and gem:FindFirstChild("Muzzle")
	local glow = muzzle and muzzle:FindFirstChild("GemGlow") :: ParticleEmitter?
	if glow then
		glow.Color = ColorSequence.new(palette.Halo)
	end
end

function StaffService.init()
	local function watch(player: Player)
		player.CharacterAdded:Connect(function(character)
			StaffService.equip(character, "Energy")
		end)
		if player.Character then
			task.spawn(StaffService.equip, player.Character, "Energy")
		end
	end
	Players.PlayerAdded:Connect(watch)
	for _, player in Players:GetPlayers() do
		watch(player)
	end
end

return StaffService
