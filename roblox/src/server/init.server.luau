--!strict
-- Ponto de entrada do servidor. Cada servico expoe init() (preparo, sem esperar nada) e start()
-- (loops e conexoes). A ordem importa so no init.
-- Robusto: os remotes sao criados ANTES de tudo (o cliente espera por eles) e cada servico roda
-- isolado em pcall, entao um erro aparece no Output sem derrubar os outros.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

require(ReplicatedStorage.Shared.Net) -- cria a pasta Remotes

local Services = script.Services

local ORDER = {
	"WorldService",
	"ProgressionService",
	"StatsService",
	"StaffService",
	"StatusService",
	"DodgeService",
	"DamageService",
	"EssenceService",
	"SpellService",
	"EnemyService",
	"ArenaService",
}

local loaded: { [string]: any } = {}
for _, name in ORDER do
	local ok, result = pcall(function()
		local service = require(Services:FindFirstChild(name) :: ModuleScript) :: any
		if service.init then
			service.init()
		end
		return service
	end)
	if ok then
		loaded[name] = result
	else
		warn(string.format("[Arcanum] ERRO ao iniciar %s: %s", name, tostring(result)))
	end
end

for _, name in ORDER do
	local service = loaded[name]
	if service and service.start then
		task.spawn(function()
			local ok, err = pcall(service.start)
			if not ok then
				warn(string.format("[Arcanum] ERRO em %s.start: %s", name, tostring(err)))
			end
		end)
	end
end

print("[Arcanum] servidor pronto")
