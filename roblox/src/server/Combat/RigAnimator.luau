--!strict
-- Animacoes padrao do R15 (catalogo do Roblox, liberadas para qualquer jogo) para criaturas e
-- servos: idle sempre; andar/correr misturados pela velocidade; acoes (apontar, erguer os bracos,
-- gargalhar, golpear) tocadas pela IA. Cada um toca num ritmo um pouco diferente.

local RigAnimator = {}

local ANIMATIONS: { [string]: string } = {
	Idle = "rbxassetid://507766666",
	Walk = "rbxassetid://507777826",
	Run = "rbxassetid://507767714",
	Point = "rbxassetid://507770453", -- avistou o alvo
	Cheer = "rbxassetid://507770677", -- bracos para cima (preparo de pancada / rugido)
	Laugh = "rbxassetid://507770818", -- zomba ao acertar ou vencer
	Slash = "rbxassetid://522635514", -- golpe com arma (servos)
}
local ACTIONS = { "Point", "Cheer", "Laugh", "Slash" }
local RUN_ABOVE = 11 -- studs/s: acima disso corre em vez de andar

local function load(animator: Animator, id: string): AnimationTrack?
	local animation = Instance.new("Animation")
	animation.AnimationId = id
	local ok, track = pcall(function()
		return animator:LoadAnimation(animation)
	end)
	return if ok then track else nil
end

function RigAnimator.setup(humanoid: Humanoid, tempo: number): { [string]: AnimationTrack }
	local animator = humanoid:FindFirstChildOfClass("Animator") or Instance.new("Animator")
	animator.Parent = humanoid
	local tracks: { [string]: AnimationTrack } = {}
	for name, id in ANIMATIONS do
		local track = load(animator :: Animator, id)
		if track then
			tracks[name] = track
		end
	end
	local idle, walk, run = tracks.Idle, tracks.Walk, tracks.Run
	if idle then
		idle.Looped = true
		idle.Priority = Enum.AnimationPriority.Idle
		idle:Play(0.2, 1, tempo * (0.85 + math.random() * 0.3))
	end
	for _, name in ACTIONS do
		local track = tracks[name]
		if track then
			track.Looped = false
			track.Priority = Enum.AnimationPriority.Action
		end
	end
	for _, track in { walk, run } do
		if track then
			track.Looped = true
			track.Priority = Enum.AnimationPriority.Movement
		end
	end
	humanoid.Running:Connect(function(speed: number)
		local running = speed > RUN_ABOVE and run ~= nil
		local active = if running then run else walk
		local other = if running then walk else run
		if other and other.IsPlaying then
			other:Stop(0.25)
		end
		if not active then
			return
		end
		if speed > 0.5 then
			if not active.IsPlaying then
				active:Play(0.2)
			end
			local reference = if running then 20 else 12
			active:AdjustSpeed(math.clamp(speed / reference, 0.5, 1.6) * tempo)
		elseif active.IsPlaying then
			active:Stop(0.25)
		end
	end)
	return tracks
end

return RigAnimator
