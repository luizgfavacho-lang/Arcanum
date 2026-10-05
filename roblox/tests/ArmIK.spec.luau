local roblox = require("@lune/roblox")
local TestKit = require("./TestKit")
local fs = require("@lune/fs")
local luau = require("@lune/luau")

-- ArmIK usa CFrame/Vector3: carrega com os tipos do @lune/roblox.
local env = setmetatable({ CFrame = roblox.CFrame, Vector3 = roblox.Vector3 }, { __index = _G })
local source = fs.readFile("src/shared/Math/ArmIK.luau")
local ArmIK = luau.load(source, { environment = env })()

local test = TestKit.test
local V3, CF = roblox.Vector3, roblox.CFrame

test("ArmIK.MaoChegaNoAlvo", function(expect)
	local upper, lower = 1.2, 1.3
	local shoulder = CF.new(1.5, 4.5, 0)
	local targets = {
		V3.new(1.6, 2.9, -1.2), -- segurando o cajado parado
		V3.new(1.2, 3.8, -1.9), -- cajado erguido a frente
		V3.new(2.2, 3.0, 0.5), -- para tras e para o lado
		V3.new(0.8, 5.2, -1.0), -- acima do ombro
	}
	for i, target in targets do
		local plane, a, b = ArmIK.solve(shoulder, target, upper, lower)
		local hand = ArmIK.handPosition(plane, a, b, upper, lower)
		expect.near((hand - target).Magnitude, 0, 1e-3, "alvo " .. i)
	end
end)

test("ArmIK.AlvoLongeEstica", function(expect)
	local shoulder = CF.new(0, 0, 0)
	local plane, a, b = ArmIK.solve(shoulder, V3.new(0, 0, -10), 1, 1)
	local hand = ArmIK.handPosition(plane, a, b, 1, 1)
	expect.near(hand.Z, -2, 1e-3, "braco esticado ate o limite")
	expect.near(b, 0, 1e-6, "cotovelo reto")
end)
