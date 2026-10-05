--!strict
-- Da um cajado a todo mago (jogadores e criaturas magicas).
-- O cajado e preso ao HumanoidRootPart (Weld "StaffGrip", pose Idle de StaffPose), e NAO a mao:
-- assim ele nao balanca com a animacao. Cada cliente suaviza a transicao Idle <-> Cast e posiciona
-- o braco direito por IK para a mao ficar sempre na empunhadura (client/Vfx/Staff.luau).
-- O cajado recebe a tag "ArcanumStaff" (CollectionService) para os clientes o encontrarem.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Schools = require(Shared.Schools)
local StaffPose = require(Shared.StaffPose)
local StaffBuilder = require(script.Parent.Parent.Combat.StaffBuilder)

local StaffService = {}

local TAG = "ArcanumStaff"

function StaffService.equip(character: Model, school: string?)
	if character:FindFirstChild("ArcanumStaff") then
		return
	end
	local rootPart = character:WaitForChild("HumanoidRootPart", 10) :: BasePart?
	character:WaitForChild("RightHand", 10)
	if not rootPart then
		return
	end
	local palette = Schools[school or "Energy"] or Schools.Energy
	local staff = StaffBuilder.build(school, palette.Halo)
	local staffRoot = staff.PrimaryPart :: BasePart

	local grip = Instance.new("Weld")
	grip.Name = "StaffGrip"
	grip.Part0 = rootPart
	grip.Part1 = staffRoot
	grip.C0 = StaffPose.Poses.Idle * StaffPose.AXIS
	grip.Parent = staffRoot

	staff.Parent = character
	CollectionService:AddTag(staff, TAG)
end

-- A gema assume a cor da escola conjurada (replica para todos).
function StaffService.setSchool(character: Model, school: string)
	local palette = Schools[school]
	local staff = character:FindFirstChild("ArcanumStaff")
	if not palette or not staff then
		return
	end
	character:SetAttribute("StaffSchool", school)
	for _, part in staff:GetChildren() do
		if
			part:IsA("BasePart")
			and (part.Name == "Gem" or part.Name == "GemShell" or part.Name:match("^Shard") or part.Name:match("^Tip"))
		then
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
			StaffService.equip(character, nil)
		end)
		if player.Character then
			task.spawn(StaffService.equip, player.Character, nil)
		end
	end
	Players.PlayerAdded:Connect(watch)
	for _, player in Players:GetPlayers() do
		watch(player)
	end
end

return StaffService
