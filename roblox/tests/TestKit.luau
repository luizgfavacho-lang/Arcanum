--!strict
-- Mini framework de testes para Lune (sem dependencias). Saida curta: so falhas + resumo.

local TestKit = {}

local passed, failed = 0, 0
local failures: { string } = {}
local current = ""

local function fail(message: string)
	failed += 1
	table.insert(failures, string.format("FALHOU  %s: %s", current, message))
end

local function pass()
	passed += 1
end

export type Expect = {
	near: (actual: number, expected: number, tolerance: number?, label: string?) -> (),
	equal: (actual: any, expected: any, label: string?) -> (),
	truthy: (value: any, label: string?) -> (),
}

local expect: Expect = {
	near = function(actual, expected, tolerance, label)
		if math.abs(actual - expected) <= (tolerance or 1e-3) then
			pass()
		else
			fail(string.format("%s esperado %s, veio %s", label or "", tostring(expected), tostring(actual)))
		end
	end,
	equal = function(actual, expected, label)
		if actual == expected then
			pass()
		else
			fail(string.format("%s esperado %s, veio %s", label or "", tostring(expected), tostring(actual)))
		end
	end,
	truthy = function(value, label)
		if value then
			pass()
		else
			fail(label or "valor falso")
		end
	end,
}

function TestKit.test(name: string, fn: (Expect) -> ())
	current = name
	local ok, err = pcall(fn, expect)
	if not ok then
		fail("erro: " .. tostring(err))
	end
end

function TestKit.report(): boolean
	for _, line in failures do
		print(line)
	end
	print(string.format("TESTES: %d ok, %d falha(s)", passed, failed))
	return failed == 0
end

return TestKit
