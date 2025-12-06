local base = "https://raw.githubusercontent.com/Coolmandfgfgdvcgfg/RakPeek/main/src/"

local function loadModule(name)
    local nonce = tostring(math.random(1, 1e9))

    local url = string.format("%s%s.lua?cache=%s", base, name, nonce)
    local src = game:HttpGet(url)

    local fn = loadstring(src)
    return fn()
end

local Core             = loadModule("RaknetRecorderCore")
local InstanceExplorer = loadModule("InstanceExplorer")
local FilterViewer     = loadModule("RaknetFilterViewer")
local Gui              = loadModule("RaknetRecorderGui")

Core.installHooks()
Gui.init(Core, InstanceExplorer, FilterViewer)
