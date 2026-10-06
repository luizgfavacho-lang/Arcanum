--!strict
-- Ponto de entrada do cliente. O cliente so desenha e pede: nenhuma regra de jogo roda aqui.
-- Cada controlador inicia isolado: um erro aparece no Output sem derrubar os outros.

local Controllers = script.Controllers

for _, name in
	{
		"ClientState",
		"CameraController",
		"HudController",
		"EssenceController",
		"EnemyBars",
		"VfxController",
		"AimIndicator",
		"ArenaController",
		"GrimoireController",
		"InputController",
	}
do
	local ok, err = pcall(function()
		local controller = require(Controllers:FindFirstChild(name) :: ModuleScript) :: any
		if controller.start then
			controller.start()
		end
	end)
	if not ok then
		warn(string.format("[Arcanum] ERRO no cliente (%s): %s", name, tostring(err)))
	end
end
print("[Arcanum] cliente pronto")
