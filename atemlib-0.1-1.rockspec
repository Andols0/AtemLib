package = "AtemLib"
version = "0.1-1"

source = {
    url = "git://github.com/Andols0/AtemLib",
    tag = "master" 
}

build = {
    type = "builtin",
    modules = {
        ["atemlib"] = "atemlib.lua",
        ["atemlib.cmd"] = "atemlib/cmd.lua",
        ["atemlib.events"] = "atemlib/events.lua"
    }

}

dependencies = {
	"lua >= 5.1",
    "luasocket",
}