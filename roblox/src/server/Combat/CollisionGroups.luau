--!strict
-- Grupos de colisao: "Monsters" (corpos das criaturas) e "SpellWalls" (Muralha de Chamas).
-- A muralha bloqueia so as criaturas; jogadores e servos atravessam.

local PhysicsService = game:GetService("PhysicsService")

local CollisionGroups = {}

CollisionGroups.MONSTERS = "Monsters"
CollisionGroups.SPELL_WALLS = "SpellWalls"

local ready = false

function CollisionGroups.ensure()
	if ready then
		return
	end
	ready = true
	pcall(function()
		PhysicsService:RegisterCollisionGroup(CollisionGroups.MONSTERS)
		PhysicsService:RegisterCollisionGroup(CollisionGroups.SPELL_WALLS)
		PhysicsService:CollisionGroupSetCollidable(CollisionGroups.SPELL_WALLS, "Default", false)
		PhysicsService:CollisionGroupSetCollidable(CollisionGroups.SPELL_WALLS, CollisionGroups.MONSTERS, true)
	end)
end

function CollisionGroups.assign(model: Model, group: string)
	CollisionGroups.ensure()
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			part.CollisionGroup = group
		end
	end
end

return CollisionGroups
