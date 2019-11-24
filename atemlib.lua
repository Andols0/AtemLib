
local ATEM = {}



local socket = require("socket")

local CMD = require("atemlib.cmd")
local Events = require("atemlib.events") --This is a collection of functions that takes the raw return from the mixer and returns separated values
local tinsert = table.insert
local tremove = table.remove
local strchar = string.char
local ATEMS = {}
local Connections = {}


-----------String modifiers
function string.FromHex(str)
    return (str:gsub('..', function (cc)
        return string.char(tonumber(cc, 16))
    end))
end

function string.hex2bin(str)
	str=string.upper(str)
    local map = {
        ['0'] = '0000',
        ['1'] = '0001',
        ['2'] = '0010',
		['3'] = '0011',
		['4'] = '0100',
		['5'] = '0101',
		['6'] = '0110',
		['7'] = '0111',
		['8'] = '1000',
		['9'] = '1001',
		['A'] = '1010',
		['B'] = '1011',
		['C'] = '1100',
		['D'] = '1101',
		['E'] = '1110',
		['F'] = '1111',
    }
    return str:gsub('[0-9A-F]', map)
end

function string.CorrectLength(str,len)
	for i=#str+1,len do
		str="0"..str
	end
	str = string.sub(str,#str-(len-1))
	return str
end
---------------

local function GetHead(hex)
	local head = hex:sub(1,4)
	local bin = head:hex2bin()
	local CmdFlag = bin:sub(1,5)
	local Packet = bin:sub(6)
	local cmd
	if CmdFlag == "10000" then
		cmd = "Response"
	elseif CmdFlag == "01000" then
		cmd = "Hello"
	elseif CmdFlag =="00100" then
		cmd = "Retransmission"
	elseif CmdFlag == "00010" then
		cmd = "Init"
	elseif CmdFlag =="00001" then
		cmd = "ACK"
	elseif CmdFlag == "10001" then
		cmd = "CMDRET"
	end
	local len=0
	for i=1,11 do
		local num = tonumber(string.sub(Packet,i,i))
		len = len + num*2^(11-i)
	end
	return cmd, len
end

function string.tohex(str)
    return (str:gsub('.', function (c)
        return string.format('%02X', string.byte(c))
    end))
end




local function CreateHeader(Type,Mixer,length)
	local Flag
	if Type=="ACK" then
		Flag="00001"
	end
	--print("length",length)
	local len = string.format("%x",length):hex2bin()
	--print("binlen",len)
	for i=string.len(len)+1,11 do
		len = "0"..len
	end
	--print("förlängd",len)
	len=string.sub(len,#len-10)
	--print("lendone",len)
	local Head=Flag..len
	local pktut = string.format("%x",Mixer.Cmdid)
	for i=string.len(pktut)+1,4 do
		pktut = "0"..pktut
	end
	Mixer.Cmdid = Mixer.Cmdid+1
	local head=0
	--print("Head",Head)
	head = tonumber(Head,2)
	--print(head)
	head = string.format("%x",head)
	for i=#head+1,4 do
		head="0"..head
	end
	--print("hexhead",head)
	return head..Mixer.Session.."0000".."0000".."0000"..pktut
end

function CMD.Close(self,reason)
	local ID = self.id
	print("LIB self id",self.id)
	ATEMS[ID]:close()
	for k,v in pairs(self) do
		v = nil
	end
	if reason then
		self.Callback("Error",reason)
	end
	Connections[ATEMS[ID]]=nil
	tremove(Connections,ID)
	tremove(ATEMS,ID)
	self=nil
	for _,Conn in pairs(Connections) do
		if Conn.id>=ID then
			Conn.id = Conn.id - 1
		end
	end

end

local function RegisterEvent(self,event)
	self.Events[event]=1
end

local function UnregisterEvent(self,event)
	self.Events[event]=1
end

local function GetEvents(data)--
	local Info = {}
	local Max = #data
	local n=1
	while n<Max do
		local Size = tonumber(data:sub(n,n+3),16)
		n = n + 4
		local Name = {}
		--print(data:sub(n,n+11))
		for i=n+4, n+11,2 do
			local Byte = data:sub(i,i+1)
			--print(Byte)
			if Byte~="00" then
				local num = tonumber(Byte,16)
				if (65 <= num and num <= 90) or (97 <= num and num <= 122) or num == 95 then
					tinsert(Name,strchar(num))
				end
			end
		end
		local Data = data:sub(n+12,n+Size*2-5)
		n = n + Size*2-4
		local Name = table.concat(Name)
		tinsert(Info,{Name = Name, Data = Data})
	end
	return Info
end

local function ACK(Conn,pkt,cpkt)
	local Obj = Connections[Conn]
	local pktut = string.format("%x",Obj.Cpkt)
	for i=string.len(pktut)+1,4 do
		pktut = "0"..pktut
	end
	Obj.Cpkt = Obj.Cpkt +1
	Conn:send(string.FromHex("800c"..Obj.Session..pkt.."0000"..pktut.."0000"))
end

local function Reconnect(Mixer)
print("LIB Reconnecting")
	local Conn = Connections[Mixer]
	Conn.Cpkt = 1
	Conn.Cmdid = 1
	local Init = "101453AB00000000003A00000100000000000000" --"1014"..session.."00000000003A00000100000000000000"
	Mixer:send(Init:FromHex())
	Mixer:settimeout(1) --Wait one second for the ATEM to answer
	local data = Mixer:receive()
	if data then
		local hexdata = data:tohex()
		local pktid = hexdata:sub(21,24)
		local CMD, LEN = GetHead(hexdata)
		if CMD == "Init" and LEN == 20 then
			ACK(Mixer,"0000")
			Conn.Init = 1--Set initiation status 1 so that we know to grab the real session id on the next recieve
		end
		print("LIB Reconnected sucessfully")
		return true
	end
	return false
end

function ATEM.Connect(ip,callback,forever)
	local udp = socket.udp()

	Connections[udp] = {}
	local Connection = Connections[udp]

	Connection.Session="53AB"--Ska dessa värden vara random? Byt till bättre förklarade namn
	Connection.Cpkt = 1
	Connection.Recon = forever
	Connection.Cmdid = 1
	Connection.Events = {}
	local Init = "101453AB00000000003A00000100000000000000" --"1014"..session.."00000000003A00000100000000000000"
	udp:setpeername(ip, 9910)
	print(udp:send(Init:FromHex()))
	udp:settimeout(1) --Wait one second for the ATEM to answer

	local data, err = udp:receive()
	if data then
		local hexdata = data:tohex()
		local pktid = hexdata:sub(21,24)
		local Event, LEN = GetHead(hexdata)
		if Event == "Init" and LEN == 20 then
			ACK(udp,"0000")
			Connection.Init = 1--Set initiation status 1 so that we know to grab the real session id on the next recieve
		end

		tinsert(ATEMS,udp) --Inited with the ATEM store the udp connection and "object"
		tinsert(Connections,Connection)
		Connection.id = #ATEMS
		Connection.Callback = callback
		Connection.UnregisterEvent = UnregisterEvent
		Connection.RegisterEvent = RegisterEvent
		--udp.id = #ATEMS

		for k,v in pairs(CMD) do--Insert Commands in every connection
			Connection[k]=v
		end

		Connection.CMDLength = 0
		Connection.CMDBuffer = ""
		Connection.Lasttime=socket.gettime()
		return Connection
	else
		print(err, udp)
		udp:close()
		Connections[udp]=nil
		return false
	end
end

function ATEM.Main()
	local canread = socket.select(ATEMS,nil,0)
	for _,Mixer in ipairs(canread) do
		local data = Mixer:receive()
		local Conn = Connections[Mixer]
		local hexdata = data:tohex()
		local pktid = hexdata:sub(21,24)
		Conn.Lasttime = socket:gettime()
		if Conn.Init == 1 then
			Conn.Session = hexdata:sub(5,8)
			Conn.Init = 2
		end
		local CMD ,LEN = GetHead(hexdata)
		if (CMD == "ACK" or CMD == "CMDRET") and LEN == 12 then --Heartbeat
			ACK(Mixer,pktid)
		elseif (CMD == "ACK" or CMD== "CMDRET") and LEN > 12 then
			ACK(Mixer,pktid)
			local EventList = GetEvents(hexdata:sub(25))
			--print("events")
			for i=1, #EventList do
				local Event = EventList[i]
				local Name = Event.Name
				--print(Name)
				if Conn.Events[Name] then
					Conn.Callback(Name,Events[Name](Event.Data))
				end
			end
		end
		--if CMD == "CMDRET" then
			--ACK(Mixer,pktid)
		--end
	end
	for _,Mixer in ipairs(ATEMS) do --Look for timeouts
		local Conn = Connections[Mixer]
		if socket:gettime()-Conn.Lasttime > 5 then ---------Vad är mixerns timeout tid?
			local status = Reconnect(Mixer)

			if status == false then
				Conn.Tries = Conn.Tries or 0
				Conn.Tries = Conn.Tries + 1
				if Conn.Tries == 1 and Conn.Recon then
					Conn.Callback("Error","Reconnecting")
				end
				if Conn.Tries >=5  and not Conn.Recon then
					Conn:Close("LostConnection")
				end
			else
				if Conn.Tries and Conn.Tries > 1 then
					Conn.Callback("Error","Connection Resumed")
				end
				Conn.Tries = 0
				Conn.Lasttime = socket:gettime()
			end
		end
	end
	for i,Conn in ipairs(Connections) do--Send and clear the buffers.
		if Conn.CMDBuffer~="" then
			local Mixer = ATEMS[i]
			local send = CreateHeader("ACK",Conn,12+Conn.CMDLength)..Conn.CMDBuffer
			Mixer:send(send:FromHex())
			Conn.CMDBuffer=""
			Conn.CMDLength=0
			socket.sleep(0.02) --The mixer can get to many messages, just to make sure it dosn't crash.
		end
	end
	if #Connections==0 then
		return false
	else
		return true
	end
end




function ATEM.MainLoop()
	local Continue = true
	while Continue do
		Continue = ATEM.Main()
	end
end

return ATEM

