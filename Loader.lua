if getgenv and getgenv().RaknetPacketRecorderLoaded then
    warn("[RakPeek Packet Recorder] Already loaded")
    return
end

if getgenv then
    getgenv().RaknetPacketRecorderLoaded = true
end

local base = "https://raw.githubusercontent.com/Coolmandfgfgdvcgfg/RakPeek/main/src/"

local function loadModule(name)
    local url = base .. name .. ".lua"
    local src = game:HttpGet(url)
    local fn, err = loadstring(src)
    if not fn then
        error("[RakPeek Packet Recorder] Failed to load " .. name .. ": " .. tostring(err))
    end
    local ok, mod = pcall(fn)
    if not ok then
        error("[RakPeek Packet Recorder] Error running " .. name .. ": " .. tostring(mod))
    end
    return mod
end

local Core = loadModule("RaknetRecorderCore")
local Gui  = loadModule("RaknetRecorderGui")

-- Install RakNet hooks
Core.installHooks()

-- Build GUI
Gui.init(Core)
