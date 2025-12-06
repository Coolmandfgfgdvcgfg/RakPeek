-- PacketScriptBuilder.lua

-- Supports:
--   - Exact mode: exact bytes -> buffer -> raknet.send / receive
--   - Reconstructed mode only (ID 0x1B) atm: decode position, expose as variables,
--     and use a small converter function to rebuild the packet from id + pos only.

local PacketScriptBuilder = {}

local TweenService = game:GetService("TweenService")

local function tween(obj, time, props, style, dir)
    if not obj then return end
    local info = TweenInfo.new(
        time or 0.2,
        style or Enum.EasingStyle.Quad,
        dir or Enum.EasingDirection.Out
    )
    local t = TweenService:Create(obj, info, props)
    t:Play()
    return t
end

local function makeDraggable(header: Frame, dragTarget: Frame)
    local dragging = false
    local dragStart
    local startPos

    header.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging  = true
            dragStart = input.Position
            startPos  = dragTarget.Position

            local conn
            conn = input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                    if conn then
                        conn:Disconnect()
                    end
                end
            end)
        end
    end)

    header.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement and dragging then
            local delta = input.Position - dragStart
            dragTarget.Position = UDim2.new(
                startPos.X.Scale,
                startPos.X.Offset + delta.X,
                startPos.Y.Scale,
                startPos.Y.Offset + delta.Y
            )
        end
    end)
end

-- Physics (0x1B) position decoder

local function decodePhysicsPosFromPacket(buf)
    -- This assumes packet layout where:
    --   id   at 0x00
    --   posX: int at 0x1D, frac at 0x1E (/256)
    --   posY: int at 0x1F, frac at 0x20 (/256)
    --   posZ: int at 0x21, frac at 0x22 (/256)
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

-- Script generators

-- Turn buffer bytes into a nice Lua hex table string.
local function buildBytesTableLiteral(buf)
    local len = buffer.len(buf)
    local lines = {}
    table.insert(lines, "local bytes = {")

    local COLS = 12
    local col = 0
    local line = "    "

    for i = 0, len - 1 do
        local b = buffer.readu8(buf, i)
        line = line .. string.format("0x%02X", b)
        col += 1

        if i < len - 1 then
            line = line .. ", "
        end

        if col >= COLS then
            table.insert(lines, line)
            line = "    "
            col = 0
        end
    end

    if line ~= "    " then
        table.insert(lines, line)
    end

    table.insert(lines, "}")
    return table.concat(lines, "\n")
end

local function buildExactScript(entry, asReceive: boolean?)
    local buf = entry.buf
    local len = buffer.len(buf)

    local parts = {}

    table.insert(parts, "-- Exact replay of captured packet")
    table.insert(parts, string.format("-- Index: %d | Dir: %s | ID: 0x%02X | Len: %d",
        entry.index or -1,
        entry.dir or "?",
        entry.id or 0,
        entry.len or len
    ))
    table.insert(parts, "")

    table.insert(parts, buildBytesTableLiteral(buf))
    table.insert(parts, "")
    table.insert(parts, "local buf = buffer.create(#bytes)")
    table.insert(parts, "for i, b in ipairs(bytes) do")
    table.insert(parts, "    buffer.writeu8(buf, i-1, b)")
    table.insert(parts, "end")
    table.insert(parts, "")
    if asReceive then
        table.insert(parts, "-- Make client believe it received this packet")
        table.insert(parts, "raknet.receive(buf)")
        table.insert(parts, "")
        table.insert(parts, "-- Or send to server instead:")
        table.insert(parts, "-- raknet.send(buf)")
    else
        table.insert(parts, "-- Send packet to server")
        table.insert(parts, "raknet.send(buf)")
        table.insert(parts, "")
        table.insert(parts, "-- Or fake a receive instead:")
        table.insert(parts, "-- raknet.receive(buf)")
    end

    return table.concat(parts, "\n")
end

-- Reconstructed script for physics (0x1B).
local function buildReconstructedScript(entry, asReceive: boolean?)
    local buf = entry.buf
    local pos = decodePhysicsPosFromPacket(buf)
    local packetLen = entry.len or buffer.len(buf) or 64

    local parts = {}

    table.insert(parts, "-- Reconstructed physics packet (0x1B) without raw template")
    table.insert(parts, "-- Uses id + pos variables and a small converter to build a packet.")
    table.insert(parts, string.format("-- Index: %d | Dir: %s | ID: 0x%02X | CapturedLen: %d",
        entry.index or -1,
        entry.dir or "?",
        entry.id or 0,
        buffer.len(buf)
    ))
    table.insert(parts, "")

    table.insert(parts, "local ID_PHYSICS = 0x1B")

    if pos then
        table.insert(parts, string.format(
            "local pos = Vector3.new(%.4f, %.4f, %.4f)",
            pos.X, pos.Y, pos.Z
        ))
    else
        table.insert(parts, "-- Failed to decode position; fill in manually:")
        table.insert(parts, "local pos = Vector3.new(0, 0, 0)")
    end

    table.insert(parts, "local id  = ID_PHYSICS")
    table.insert(parts, "")

    table.insert(parts, "local function buildPhysicsPacket(id, pos)")
    table.insert(parts, string.format("    -- Adjust packetLen if needed; captured packet length was %d", buffer.len(buf)))
    table.insert(parts, string.format("    local packetLen = %d", packetLen))
    table.insert(parts, "    local buf = buffer.create(packetLen)")
    table.insert(parts, "")
    table.insert(parts, "    -- Write top-level ID")
    table.insert(parts, "    buffer.writeu8(buf, 0, id)")
    table.insert(parts, "")
    table.insert(parts, "    -- Encode position components into the packed format the game uses")
    table.insert(parts, "    local function writeComponent(offset, value)")
    table.insert(parts, "        local xi = math.floor(value)")
    table.insert(parts, "        local frac = math.clamp(value - xi, 0, 0.996)")
    table.insert(parts, "        local xf = math.floor(frac * 256 + 0.5)")
    table.insert(parts, "        buffer.writeu8(buf, offset,     xi)")
    table.insert(parts, "        buffer.writeu8(buf, offset + 1, xf)")
    table.insert(parts, "    end")
    table.insert(parts, "")
    table.insert(parts, "    -- X, Y, Z components (same offsets as decoder used)")
    table.insert(parts, "    writeComponent(0x1D, pos.X)")
    table.insert(parts, "    writeComponent(0x1F, pos.Y)")
    table.insert(parts, "    writeComponent(0x21, pos.Z)")
    table.insert(parts, "")
    table.insert(parts, "    -- TODO: Fill in any other fields required by the physics protocol")
    table.insert(parts, "    -- e.g. timestamp, velocity, flags, etc.")
    table.insert(parts, "")
    table.insert(parts, "    return buf")
    table.insert(parts, "end")
    table.insert(parts, "")
    table.insert(parts, "local pkt = buildPhysicsPacket(id, pos)")
    table.insert(parts, "")

    if asReceive then
        table.insert(parts, "-- Make client believe it received this reconstructed packet")
        table.insert(parts, "raknet.receive(pkt)")
        table.insert(parts, "")
        table.insert(parts, "-- Or send to server instead:")
        table.insert(parts, "-- raknet.send(pkt)")
    else
        table.insert(parts, "-- Send reconstructed packet to server")
        table.insert(parts, "raknet.send(pkt)")
        table.insert(parts, "")
        table.insert(parts, "-- Or fake a receive instead:")
        table.insert(parts, "-- raknet.receive(pkt)")
    end

    return table.concat(parts, "\n")
end


-- entry: {
--   index: number,
--   dir: "SEND" | "RECV",
--   id: number,
--   len: number,
--   buf: buffer,
-- }
--
-- parentGui: ScreenGui where window should live
--
-- Returns {
--   Frame = frame,
--   SetEntry = function(newEntry) ... end,
-- }
function PacketScriptBuilder.Create(parentGui: ScreenGui, entry)
    local frame = Instance.new("Frame")
    frame.Name = "PacketScriptBuilder"
    frame.Size = UDim2.new(0, 620, 0, 420)
    frame.Position = UDim2.new(0, 120, 0, 80)
    frame.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
    frame.BorderSizePixel  = 0
    frame.Parent = parentGui

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = frame

    -- slide in softly
    local originalPos = frame.Position
    frame.Position = UDim2.new(
        originalPos.X.Scale,
        originalPos.X.Offset,
        originalPos.Y.Scale,
        originalPos.Y.Offset + 20
    )
    tween(frame, 0.2, {Position = originalPos}, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

    local header = Instance.new("Frame")
    header.Size = UDim2.new(1, 0, 0, 26)
    header.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    header.BorderSizePixel  = 0
    header.Parent = frame

    local hCorner = Instance.new("UICorner")
    hCorner.CornerRadius = UDim.new(0, 8)
    hCorner.Parent = header

    local title = Instance.new("TextLabel")
    title.BackgroundTransparency = 1
    title.Size = UDim2.new(1, -80, 1, 0)
    title.Position = UDim2.new(0, 8, 0, 0)
    title.Font = Enum.Font.Code
    title.TextSize = 14
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.TextColor3 = Color3.fromRGB(230, 230, 230)
    title.Text = "Packet Script Builder"
    title.Parent = header

    local closeBtn = Instance.new("TextButton")
    closeBtn.BackgroundTransparency = 1
    closeBtn.Size = UDim2.new(0, 24, 1, 0)
    closeBtn.Position = UDim2.new(1, -26, 0, 0)
    closeBtn.Font = Enum.Font.Code
    closeBtn.TextSize = 16
    closeBtn.TextColor3 = Color3.fromRGB(255, 90, 90)
    closeBtn.Text = "X"
    closeBtn.Parent = header

    closeBtn.MouseButton1Click:Connect(function()
        -- slide down + destroy
        local target = UDim2.new(
            originalPos.X.Scale,
            originalPos.X.Offset,
            originalPos.Y.Scale,
            originalPos.Y.Offset + 20
        )
        tween(frame, 0.18, {Position = target}, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
        task.delay(0.19, function()
            if frame then
                frame:Destroy()
            end
        end)
    end)

    makeDraggable(header, frame)

    -- TOP BAR (info + mode controls)
    local topBar = Instance.new("Frame")
    topBar.BackgroundTransparency = 1
    topBar.Size = UDim2.new(1, -12, 0, 28)
    topBar.Position = UDim2.new(0, 6, 0, 32)
    topBar.Parent = frame

    local topLayout = Instance.new("UIListLayout")
    topLayout.FillDirection = Enum.FillDirection.Horizontal
    topLayout.Padding = UDim.new(0, 6)
    topLayout.VerticalAlignment = Enum.VerticalAlignment.Center
    topLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
    topLayout.Parent = topBar

    local infoLabel = Instance.new("TextLabel")
    infoLabel.BackgroundTransparency = 1
    infoLabel.Size = UDim2.new(0.55, 0, 1, 0)
    infoLabel.Font = Enum.Font.Code
    infoLabel.TextSize = 12
    infoLabel.TextXAlignment = Enum.TextXAlignment.Left
    infoLabel.TextColor3 = Color3.fromRGB(220, 220, 220)
    infoLabel.Text = ""
    infoLabel.Parent = topBar

    local modeFrame = Instance.new("Frame")
    modeFrame.BackgroundTransparency = 1
    modeFrame.Size = UDim2.new(0.45, 0, 1, 0)
    modeFrame.Parent = topBar

    local modeLayout = Instance.new("UIListLayout")
    modeLayout.FillDirection = Enum.FillDirection.Vertical
    modeLayout.Padding = UDim.new(0, 2)
    modeLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
    modeLayout.VerticalAlignment = Enum.VerticalAlignment.Center
    modeLayout.Parent = modeFrame

    local rowMode = Instance.new("Frame")
    rowMode.BackgroundTransparency = 1
    rowMode.Size = UDim2.new(1, 0, 0, 22)
    rowMode.Parent = modeFrame

    local rowModeLayout = Instance.new("UIListLayout")
    rowModeLayout.FillDirection = Enum.FillDirection.Horizontal
    rowModeLayout.Padding = UDim.new(0, 4)
    rowModeLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
    rowModeLayout.VerticalAlignment = Enum.VerticalAlignment.Center
    rowModeLayout.Parent = rowMode

    local rowDir = Instance.new("Frame")
    rowDir.BackgroundTransparency = 1
    rowDir.Size = UDim2.new(1, 0, 0, 22)
    rowDir.Parent = modeFrame

    local rowDirLayout = Instance.new("UIListLayout")
    rowDirLayout.FillDirection = Enum.FillDirection.Horizontal
    rowDirLayout.Padding = UDim.new(0, 4)
    rowDirLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
    rowDirLayout.VerticalAlignment = Enum.VerticalAlignment.Center
    rowDirLayout.Parent = rowDir

    local function makeSmallButton(parent, text, width)
        local b = Instance.new("TextButton")
        b.BackgroundColor3 = Color3.fromRGB(55, 55, 55)
        b.BorderSizePixel  = 0
        b.Size = UDim2.new(0, width or 80, 0, 22)
        b.Font = Enum.Font.Code
        b.TextSize = 12
        b.TextColor3 = Color3.fromRGB(230, 230, 230)
        b.Text = text
        b.AutoButtonColor = false

        local c = Instance.new("UICorner")
        c.CornerRadius = UDim.new(0, 4)
        c.Parent = b

        b.Parent = parent
        return b
    end

    local exactBtn  = makeSmallButton(rowMode, "Exact", 90)
    local reconBtn  = makeSmallButton(rowMode, "Reconstructed", 110)
    local sendBtn   = makeSmallButton(rowDir,  "Send", 80)
    local recvBtn   = makeSmallButton(rowDir,  "Receive", 80)

    -- EDITOR
    local editorBg = Instance.new("Frame")
    editorBg.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
    editorBg.BorderSizePixel  = 0
    editorBg.Position = UDim2.new(0, 6, 0, 66)
    editorBg.Size = UDim2.new(1, -12, 1, -72)
    editorBg.Parent = frame

    local eCorner = Instance.new("UICorner")
    eCorner.CornerRadius = UDim.new(0, 6)
    eCorner.Parent = editorBg

    local editorScroll = Instance.new("ScrollingFrame")
    editorScroll.BackgroundTransparency = 1
    editorScroll.BorderSizePixel = 0
    editorScroll.Position = UDim2.new(0, 4, 0, 4)
    editorScroll.Size = UDim2.new(1, -8, 1, -8)
    editorScroll.ScrollBarThickness = 6
    editorScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
    editorScroll.Parent = editorBg

    local editorBox = Instance.new("TextBox")
    editorBox.BackgroundTransparency = 1
    editorBox.BorderSizePixel = 0
    editorBox.Position = UDim2.new(0, 2, 0, 2)
    editorBox.Size = UDim2.new(1, -4, 0, 0)
    editorBox.Font = Enum.Font.Code
    editorBox.TextSize = 13
    editorBox.TextColor3 = Color3.fromRGB(235, 235, 235)
    editorBox.TextXAlignment = Enum.TextXAlignment.Left
    editorBox.TextYAlignment = Enum.TextYAlignment.Top
    editorBox.MultiLine = true
    editorBox.ClearTextOnFocus = false
    editorBox.TextWrapped = false
    editorBox.TextEditable = false   -- read-only; user can still copy
    editorBox.Text = ""
    editorBox.Parent = editorScroll

    local function updateEditorCanvas()
        local ok, bounds = pcall(function()
            return editorBox.TextBounds
        end)
        if not ok or not bounds then return end

        editorBox.Size = UDim2.new(1, -4, 0, bounds.Y + 8)
        editorScroll.CanvasSize = UDim2.new(0, 0, 0, editorBox.AbsoluteSize.Y + 4)
    end

    editorBox:GetPropertyChangedSignal("TextBounds"):Connect(updateEditorCanvas)

    -- STATE & REFRESH
    local currentEntry = entry
    local isExactMode  = true
    local isSendMode   = true

    local function setModeButtons()
        -- exact / recon
        if isExactMode then
            tween(exactBtn, 0.12, {BackgroundColor3 = Color3.fromRGB(80, 130, 200)})
            tween(reconBtn, 0.12, {BackgroundColor3 = Color3.fromRGB(55, 55, 55)})
        else
            tween(exactBtn, 0.12, {BackgroundColor3 = Color3.fromRGB(55, 55, 55)})
            tween(reconBtn, 0.12, {BackgroundColor3 = Color3.fromRGB(80, 130, 200)})
        end

        -- send / recv
        if isSendMode then
            tween(sendBtn, 0.12, {BackgroundColor3 = Color3.fromRGB(80, 160, 80)})
            tween(recvBtn, 0.12, {BackgroundColor3 = Color3.fromRGB(55, 55, 55)})
        else
            tween(sendBtn, 0.12, {BackgroundColor3 = Color3.fromRGB(55, 55, 55)})
            tween(recvBtn, 0.12, {BackgroundColor3 = Color3.fromRGB(160, 120, 60)})
        end
    end

    local function refreshInfo()
        if not currentEntry then
            infoLabel.Text = "No packet selected"
            return
        end

        local id  = currentEntry.id or 0
        local dir = currentEntry.dir or "?"
        local len = currentEntry.len or (currentEntry.buf and buffer.len(currentEntry.buf) or 0)
        local idx = currentEntry.index or -1

        infoLabel.Text = string.format("Index %d | Dir: %s | ID: 0x%02X | Len: %d",
            idx, dir, id, len
        )

        -- If not physics (0x1B), gray out reconstructed
        if id ~= 0x1B then
            reconBtn.AutoButtonColor = false
            reconBtn.Active = false
            reconBtn.TextColor3 = Color3.fromRGB(150, 150, 150)
        else
            reconBtn.Active = true
            reconBtn.TextColor3 = Color3.fromRGB(230, 230, 230)
        end
    end

    local function refreshScript()
        if not currentEntry or not currentEntry.buf then
            editorBox.Text = "-- No packet selected"
            return
        end

        local id = currentEntry.id or 0
        local asReceive = not isSendMode

        if id == 0x1B and not isExactMode then
            editorBox.Text = buildReconstructedScript(currentEntry, asReceive)
        else
            editorBox.Text = buildExactScript(currentEntry, asReceive)
        end
        updateEditorCanvas()
    end

    exactBtn.MouseButton1Click:Connect(function()
        if not isExactMode then
            isExactMode = true
            setModeButtons()
            refreshScript()
        end
    end)

    reconBtn.MouseButton1Click:Connect(function()
        if not currentEntry or (currentEntry.id or 0) ~= 0x1B then
            return
        end
        if isExactMode then
            isExactMode = false
            setModeButtons()
            refreshScript()
        end
    end)

    sendBtn.MouseButton1Click:Connect(function()
        if not isSendMode then
            isSendMode = true
            setModeButtons()
            refreshScript()
        end
    end)

    recvBtn.MouseButton1Click:Connect(function()
        if isSendMode then
            isSendMode = false
            setModeButtons()
            refreshScript()
        end
    end)

    local api = {}

    function api.SetEntry(newEntry)
        currentEntry = newEntry
        refreshInfo()
        refreshScript()
    end

    -- Initialize
    refreshInfo()
    setModeButtons()
    refreshScript()

    return {
        Frame = frame,
        SetEntry = api.SetEntry,
    }
end

return PacketScriptBuilder
