-- RaknetRecorderCore.lua

local Core = {}

-- STATE

local recording       = false
local recordedPackets = {} -- { index, dir, id, len, time, buf }
local startClockBase  = os.clock()

local recordSend      = true
local recordRecv      = true

local blockedIds      = { SEND = {}, RECV = {} }
local ignoredIds      = { SEND = {}, RECV = {} }

local userReplayDelay = 0

-- listeners that get called when a packet is recorded: fn(entry)
local packetListeners = {}

-- ID NAMES -- these are probably incorrect, please add more packets i have no idea what the actual names are

local ID_NAMES = {
    [0x1B] = "ID_PHYSICS",
    [0x83] = "ID_REPLICATION",
}

Core.ID_NAMES = ID_NAMES

-- SMALL HELPERS

local function cloneBuffer(buf)
    local len = buffer.len(buf)
    local new = buffer.create(len)
    buffer.copy(new, 0, buf, 0, len)
    return new
end

local function getPacketId(buf)
    if buffer.len(buf) <= 0 then
        return -1
    end
    return buffer.readu8(buf, 0)
end

local function parsePacketId(text)
    if not text or text == "" then return nil end
    text = text:gsub("%s+", "")
    text = text:upper()

    local num
    if text:sub(1, 2) == "0X" then
        num = tonumber(text, 16)
    elseif text:find("[A-F]") then
        num = tonumber(text, 16)
    else
        num = tonumber(text, 10)
    end

    if not num then return nil end
    num = math.floor(num)
    if num < 0 or num > 255 then return nil end
    return num
end

Core.parsePacketId = parsePacketId

-- MOVEMENT / TIMESTAMP DECODING

local function readu16_le(buf: buffer, offset: number): number
    local lo = buffer.readu8(buf, offset)
    local hi = buffer.readu8(buf, offset + 1)
    return lo + hi * 256
end

local function getinstanceidfrompacket(buf: buffer)
    if buffer.readu8(buf, 0) ~= 0x1B then
        return nil
    end
    if buffer.len(buf) < 0x15 then
        return nil
    end

    return readu16_le(buf, 0x13)
end

local function decodetimestamppos(buf: buffer): Vector3?
    if buffer.readu8(buf, 0) ~= 0x1B then
        return nil
    end

    local xi = buffer.readu8(buf, 0x1D)
    local yi = buffer.readu8(buf, 0x1F)
    local zi = buffer.readu8(buf, 0x21)

    local xf = buffer.readu8(buf, 0x1E) / 256
    local yf = buffer.readu8(buf, 0x20) / 256
    local zf = buffer.readu8(buf, 0x22) / 256

    local x = xi + xf
    local y = yi + yf
    local z = zi + zf

    return Vector3.new(x, y, z)
end

local function decodeMovementPacket(buf: buffer): string
    if buffer.len(buf) < 0x22 then
        return "Movement decode: buffer too short."
    end

    -- 1) Physics instance id (u16 LE @ 0x13)
    local instId = getinstanceidfrompacket(buf)
    local instIdStr
    if instId then
        instIdStr = string.format("ID: %d (0x%04X)", instId, instId)
    else
        instIdStr = "ID: <unavailable>"
    end

    -- 2) Timestamp position
    local pos = decodetimestamppos(buf)
    local posStr
    if pos then
        posStr = string.format(
            "Position (XYZ): (%.4f, %.4f, %.4f)",
            pos.X, pos.Y, pos.Z
        )
    else
        posStr = "Position: <failed decode>"
    end

    return table.concat({
        instIdStr,
        posStr,
    }, "\n")
end

Core.decodeMovementPacket = decodeMovementPacket

-- PUBLIC STATE API

function Core.isRecording()
    return recording
end

function Core.startRecording()
    recording = true
    startClockBase = os.clock()
end

function Core.stopRecording()
    recording = false
end

function Core.clearPackets()
    recordedPackets = {}
end

function Core.getRecordedPackets()
    return recordedPackets
end

function Core.getRelativeTime(entry)
    local relTime = entry.time - startClockBase
    if relTime < 0 then
        relTime = 0
    end
    return relTime
end

function Core.setRecordSend(enabled: boolean)
    recordSend = not not enabled
end

function Core.setRecordRecv(enabled: boolean)
    recordRecv = not not enabled
end

function Core.setReplayDelay(seconds: number)
    if type(seconds) ~= "number" or seconds < 0 then
        seconds = 0
    end
    userReplayDelay = seconds
end

-- BLOCK / IGNORE API

function Core.setIdBlocked(id: number, dir: "SEND" | "RECV", enabled: boolean)
    if not blockedIds[dir] then return end
    if enabled then
        blockedIds[dir][id] = true
    else
        blockedIds[dir][id] = nil
    end
end

function Core.setIdIgnored(id: number, dir: "SEND" | "RECV", enabled: boolean)
    if not ignoredIds[dir] then return end
    if enabled then
        ignoredIds[dir][id] = true
    else
        ignoredIds[dir][id] = nil
    end
end

function Core.isIdBlocked(id: number, dir: "SEND" | "RECV")
    local map = blockedIds[dir]
    return map and map[id] or false
end

function Core.isIdIgnored(id: number, dir: "SEND" | "RECV")
    local map = ignoredIds[dir]
    return map and map[id] or false
end

function Core.getBlockedIds()
    local result = {}
    for dir, map in pairs(blockedIds) do
        for id, _ in pairs(map) do
            table.insert(result, {
                dir = dir,
                id  = id,
            })
        end
    end

    table.sort(result, function(a, b)
        if a.dir == b.dir then
            return a.id < b.id
        end
        return a.dir < b.dir
    end)

    return result
end

function Core.getIgnoredIds()
    local result = {}
    for dir, map in pairs(ignoredIds) do
        for id, _ in pairs(map) do
            table.insert(result, {
                dir = dir,
                id  = id,
            })
        end
    end

    table.sort(result, function(a, b)
        if a.dir == b.dir then
            return a.id < b.id
        end
        return a.dir < b.dir
    end)

    return result
end

-- PACKET RECORDING / REPLAY

local function addPacket(direction, buf)
    local idx   = #recordedPackets + 1
    local clone = cloneBuffer(buf)

    local entry = {
        index = idx,
        dir   = direction,              -- "SEND" / "RECV"
        id    = getPacketId(clone),
        len   = buffer.len(clone),
        time  = os.clock(),             -- absolute clock
        buf   = clone,
    }

    recordedPackets[idx] = entry

    -- Notify listeners
    for _, fn in ipairs(packetListeners) do
        local ok, err = pcall(fn, entry)
        if not ok then
            warn("[RaknetRecorderCore] listener error:", err)
        end
    end

    return entry
end

local function replayPacket(entry)
    if not entry or not entry.buf then return end

    if entry.dir == "SEND" then
        raknet.send(entry.buf)
    elseif entry.dir == "RECV" then
        raknet.receive(entry.buf)
    end
end

local function replaySequence(seq)
    if #seq == 0 then return end

    table.sort(seq, function(a, b)
        return a.time < b.time
    end)

    local prev = nil
    for _, entry in ipairs(seq) do
        if userReplayDelay > 0 then
            task.wait(userReplayDelay)
        elseif prev then
            local gap = entry.time - prev.time
            if gap < 0.001 then gap = 0.001 end
            task.wait(gap)
        end

        replayPacket(entry)
        prev = entry
    end
end

function Core.replayEntryByIndex(idx: number)
    local entry = recordedPackets[idx]
    if entry then
        replayPacket(entry)
    end
end

function Core.replayAll()
    replaySequence(recordedPackets)
end

function Core.replayAllDir(dir: "SEND" | "RECV")
    local seq = {}
    for _, e in ipairs(recordedPackets) do
        if e.dir == dir then
            table.insert(seq, e)
        end
    end
    replaySequence(seq)
end

-- HOOK / HANDLER

local function handlePacket(direction, packetData)
    local id = getPacketId(packetData)

    -- Blocked IDs: drop packet entirely
    if blockedIds[direction][id] then
        return false
    end

    -- Recording
    if recording then
        if direction == "SEND" and not recordSend then
            return true
        end
        if direction == "RECV" and not recordRecv then
            return true
        end

        if not ignoredIds[direction][id] then
            addPacket(direction, packetData)
        end
    end

    return true
end

function Core.onSendHook(packetData)
    return handlePacket("SEND", packetData)
end

function Core.onReceiveHook(packetData)
    return handlePacket("RECV", packetData)
end

function Core.installHooks()
    raknet.add_send_hook(Core.onSendHook)
    raknet.add_receive_hook(Core.onReceiveHook)
end

function Core.onPacketRecorded(fn)
    if type(fn) == "function" then
        table.insert(packetListeners, fn)
    end
end

return Core
