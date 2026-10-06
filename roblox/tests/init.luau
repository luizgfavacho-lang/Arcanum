-- Executor: `lune run tests` (dentro de roblox/). Sai com codigo 1 se algo falhar.
local process = require("@lune/process")
local TestKit = require("@self/TestKit")

require("@self/DamageMath.spec")
require("@self/ProgressionMath.spec")
require("@self/Data.spec")
require("@self/ArmIK.spec")
require("@self/CombatMath.spec")
require("@self/ComboMath.spec")
require("@self/SpellMath.spec")
require("@self/ArenaMath.spec")

if not TestKit.report() then
	process.exit(1)
end
