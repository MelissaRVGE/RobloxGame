-- Клиентское состояние профиля (приходит с сервера)
local State = { data = nil }
local ev = Instance.new("BindableEvent")
State.Changed = ev.Event

function State.Set(d)
	State.data = d
	ev:Fire(d)
end

return State
