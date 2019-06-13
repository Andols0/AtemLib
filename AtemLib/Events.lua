local Event = {}

local tinsert = table.insert

function Event.PrgI(data)
	local ME = tonumber(data:sub(1,2))
	local Source = tonumber(data:sub(5,8),16)
	return ME, Source
end

function Event.PrvI(data)
	local ME = tonumber(data:sub(1,2))
	local Source = tonumber(data:sub(5,8),16)
	return ME, Source
end

function Event.TlIn(data)
	local Output = {}
	local n = 5
	local i=1
	while n<#data do
		local Pgm, Prv
		local Info= data:sub(n,n+1)
		i = i+1
		if Info == "00" then
			Pgm = false
			Prv = false
		elseif Info == "01" then
			Pgm = true
			Prv = false
		elseif Info == "02" then
			Pgm = false
			Prv = true
		elseif Info == "03" then
			Pgm = true
			Prv = true
		end
		n=n+2
		tinsert(Output,{Pgm = Pgm, Prv = Prv})
	end
	return Output
end

return Event
