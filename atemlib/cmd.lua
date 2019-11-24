local CMD = {}

local function dec2hex(dec,len)  --funktion då det är nummer som modifieras.
	local hex=string.format("%x",dec)
	hex = hex:CorrectLength(len)
	return hex
end

function CMD.SetPreview(Conn,mix,input)
	local Mix = dec2hex(mix,2)
	input = dec2hex(input,4)
	--local send=GetHeader("ACK",24)..
	Conn.CMDLength = Conn.CMDLength + 12
	Conn.CMDBuffer = Conn.CMDBuffer.."000C5D0043507649"..Mix.."65"..input
end

function CMD.SetProgram(Conn,mix,input)
	local Mix = dec2hex(mix,2)
	input = dec2hex(input,4)
	Conn.CMDLength = Conn.CMDLength + 12
	Conn.CMDBuffer = Conn.CMDBuffer.."000C5D0043506749"..Mix.."65"..input
end

function CMD.SetKey(Conn,Me,Key,S)
	--Rotation, X pos, Y pos
	local O = {R = "00000000", x="00000000",y="00000000"}
	local Set
	Me = dec2hex(Me,2)
	Key = dec2hex(Key,2)
	for k,v in pairs(S) do
		if k=="Rotation" then
			Set = dec2hex(16,8)
			local rotation=string.format("%x",S.Rotation*10)
			O.R = rotation:CorrectLength(8)
		elseif k=="x" then
			Set = dec2hex(4,8)
			local x = string.format("%x",S.x*1000)
			O.x = x:CorrectLength(8)
		elseif k=="y" then
			Set = dec2hex(8,8)
			local y = string.format("%x",S.y*1000)
			O.y = y:CorrectLength(8)
		end
		Conn.CMDLength = Conn.CMDLength+72
		Conn.CMDBuffer=Conn.CMDBuffer.."00480000434B4456"..Set..Me..Key.."10010000000000000000"..O.x..O.y..O.R.."000000000000000000000000000000000000000000000000000000000000000000000000"
	end
end

function CMD.SetSS(Conn,Info)
	print("#Info",#Info)
	local Set
	for i=1,#Info do
	print("I",i)
		local O = {x="0000",y="0000"}
		local Box = dec2hex(Info[i].B,2)
		for k,v in pairs(Info[i].Data) do
			if k=="x" then
				Set = dec2hex(4,4)
				local x = string.format("%x",v*100)
				O.x = x:CorrectLength(4)
			elseif k=="y" then
				Set = dec2hex(8,4)
				local y = string.format("%x",v*100)
				O.y = y:CorrectLength(4)
			end
			--print("x",tonumber(O.x,16),"y",tonumber(O.y,16))
			--print("x",O.x,"y",O.y)
			Conn.CMDLength=Conn.CMDLength+32
			Conn.CMDBuffer=Conn.CMDBuffer.."0020fa0343534250"..Set..Box.."0f0020"..O.x..O.y.."0000000000000000000000000000"
		end
	end
end


return CMD
