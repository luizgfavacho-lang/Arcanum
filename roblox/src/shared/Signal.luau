--!strict
-- Sinal minimo (sem dependencias) para eventos entre modulos do mesmo lado (servidor ou cliente).

export type Connection = { Disconnect: (self: Connection) -> () }
export type Signal<T...> = {
	Connect: (self: Signal<T...>, fn: (T...) -> ()) -> Connection,
	Fire: (self: Signal<T...>, T...) -> (),
}

local Signal = {}

function Signal.new<T...>(): Signal<T...>
	local listeners: { [number]: ((T...) -> ())? } = {}
	local nextId = 0
	local self = {}

	function self.Connect(_, fn: (T...) -> ()): Connection
		nextId += 1
		local id = nextId
		listeners[id] = fn
		return {
			Disconnect = function()
				listeners[id] = nil
			end,
		} :: any
	end

	function self.Fire(_, ...: T...)
		for _, fn in listeners do
			if fn then
				task.spawn(fn, ...)
			end
		end
	end

	return self :: any
end

return Signal
