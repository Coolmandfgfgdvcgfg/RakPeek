local base = "https://raw.githubusercontent.com/Coolmandfgfgdvcgfg/RakPeek/main/src/"

local function loadModule(name)
    local src = game:HttpGet(base .. name .. ".lua")
    local fn = loadstring(src)
    return fn()
end

local Core = loadModule("RaknetRecorderCore")
local InstanceExplorer = loadModule("InstanceExplorer")
local Gui = loadModule("RaknetRecorderGui")

Core.installHooks()
Gui.init(Core, InstanceExplorer)
