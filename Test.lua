Atem = require("AtemLib")



local Events= {}

local function handler(name,...)
	Events[name](...)
end

local Conn = Atem.Connect("192.168.1.100",handler)
assert(Conn)
print("Connected")
function Events.PrgI(Me,prg)
	Conn:SetPreview(Me,prg)
end

for k,v in pairs(Events) do
	Conn:RegisterEvent(k)
end

Atem.MainLoop()
