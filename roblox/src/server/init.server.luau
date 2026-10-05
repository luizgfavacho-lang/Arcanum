--!strict
-- Ponto de entrada do servidor. Cada servico expoe init() (preparo, sem esperar nada) e start()
-- (loops e conexoes). A ordem importa so no init.

local Services = script.Services

local ORDER = {
	"WorldService",
	"ProgressionService",
	"StatsService",
	"StatusService",
	"DamageService",
	"SpellService",
	"EnemyService",
}

local loaded = {}
for _, name in ORDER do
	local service = require(Services:FindFirstChild(name) :: ModuleScript) :: any
	if service.init then
		service.init()
	end
	table.insert(loaded, service)
end

for _, service in loaded do
	if service.start then
		task.spawn(service.start)
	end
end

print("[Arcanum] servidor pronto")
