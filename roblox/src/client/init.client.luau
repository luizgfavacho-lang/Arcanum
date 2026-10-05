--!strict
-- Ponto de entrada do cliente. O cliente so desenha e pede: nenhuma regra de jogo roda aqui.

local Controllers = script.Controllers

for _, name in { "ClientState", "CameraController", "HudController", "EnemyBars", "VfxController", "InputController" } do
	local controller = require(Controllers:FindFirstChild(name) :: ModuleScript) :: any
	if controller.start then
		controller.start()
	end
end
