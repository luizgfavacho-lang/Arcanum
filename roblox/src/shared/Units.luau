--!strict
-- Conversao de unidades. Os CSV usam metros; o Roblox usa studs (1 stud = 0,28 m).

local Units = {}

Units.STUDS_PER_METER = 1 / 0.28

function Units.meters(m: number): number
	return m * Units.STUDS_PER_METER
end

return table.freeze(Units)
