package = "AtemLib"
version = "0.1-1"

source = {
    url = "git://github.com/Andols0/AtemLib",
    tag = "v0.1" 
}

build = {
    type = "builtin",
    modules = {
        ["atemlib"] = "AtemLib.lua",
        ["atemlib.cmd"] = "AtemLib/CMD.lua",
        ["atemlib.events"] = "AtemLib/Events.lua"
    }

}

dependencies = {
	"lua >= 5.1",
}