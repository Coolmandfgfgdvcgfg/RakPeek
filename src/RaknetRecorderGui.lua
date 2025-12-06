-- RaknetRecorderGui.lua

local Gui = {}

local Players          = game:GetService("Players")
local CoreGui          = game:GetService("CoreGui")
local UserInputService = game:GetService("UserInputService")
local TweenService     = game:GetService("TweenService")

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

local function makeButton(parent, text, width)
    local btn = Instance.new("TextButton")
    btn.BackgroundColor3 = Color3.fromRGB(55, 55, 55)
    btn.TextColor3       = Color3.fromRGB(230, 230, 230)
    btn.Font             = Enum.Font.Code
    btn.TextSize         = 14
    btn.Size             = UDim2.new(0, width or 90, 0, 24)
    btn.BorderSizePixel  = 0
    btn.Text             = text
    btn.AutoButtonColor  = false

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 4)
    corner.Parent = btn

    btn.Parent = parent

    btn.MouseButton1Click:Connect(function()
        local baseW = width or 90
        tween(btn, 0.08, {Size = UDim2.new(0, baseW - 2, 0, 22)}, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
        task.delay(0.09, function()
            if btn then
                tween(btn, 0.10, {Size = UDim2.new(0, baseW, 0, 24)}, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
            end
        end)
    end)

    return btn
end

local function makeToggle(labelText, initState, parent, width, onChanged)
    parent = parent or error("parent required")
    width  = width or 100

    local container = Instance.new("Frame")
    container.Size = UDim2.new(0, width, 1, 0)
    container.BackgroundTransparency = 1
    container.Parent = parent

    local box = Instance.new("TextButton")
    box.Name = "Box"
    box.Size = UDim2.new(0, 18, 0, 18)
    box.Position = UDim2.new(0, 0, 0.5, -9)
    box.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
    box.BorderSizePixel  = 0
    box.Text             = ""
    box.AutoButtonColor  = false

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 3)
    corner.Parent = box
    box.Parent = container

    local label = Instance.new("TextLabel")
    label.BackgroundTransparency = 1
    label.Position = UDim2.new(0, 24, 0, 0)
    label.Size = UDim2.new(1, -24, 1, 0)
    label.Font = Enum.Font.Code
    label.TextSize = 12
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.TextColor3 = Color3.fromRGB(210, 210, 210)
    label.Text = labelText
    label.Parent = container

    local state = initState

    local function refresh(animated)
        local targetColor = state and Color3.fromRGB(80, 160, 80) or Color3.fromRGB(60, 60, 60)
        if animated then
            tween(box, 0.12, {BackgroundColor3 = targetColor})
        else
            box.BackgroundColor3 = targetColor
        end
    end

    box.MouseButton1Click:Connect(function()
        state = not state
        refresh(true)
        if onChanged then
            onChanged(state)
        end
    end)

    refresh(false)

    local t = {}

    function t.Get()
        return state
    end

    function t.Set(v)
        state = not not v
        refresh(true)
        if onChanged then
            onChanged(state)
        end
    end

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

-- HEX VIEWER FORMATTER

local function formatBufferHexAscii(buf)
    local len = buffer.len(buf)
    if len == 0 then
        return "(empty buffer)"
    end

    local bytesPerLine = 8
    local lines = {}

    for offset = 0, len - 1, bytesPerLine do
        local hexParts   = {}
        local asciiParts = {}

        for i = 0, bytesPerLine - 1 do
            local idx = offset + i
            if idx < len then
                local b = buffer.readu8(buf, idx)
                hexParts[#hexParts+1] = string.format("%02X", b)

                local ch
                if b >= 32 and b <= 126 then
                    ch = string.char(b)
                else
                    ch = "."
                end
                asciiParts[#asciiParts+1] = ch
            else
                hexParts[#hexParts+1]   = "  "
                asciiParts[#asciiParts+1] = " "
            end
        end

        local line = string.format("%04X ", offset)
            .. table.concat(hexParts, " ")
            .. "  |"
            .. table.concat(asciiParts)
            .. "|"

        lines[#lines+1] = line
    end

    return table.concat(lines, "\n")
end

-- MAIN GUI INIT
function Gui.init(Core, InstanceExplorer, FilterViewer, parentGuiOverride: ScreenGui?)
    local ID_NAMES       = Core.ID_NAMES
    local parsePacketId  = Core.parsePacketId
    local decodeMovement = Core.decodeMovementPacket

    local parentGui = parentGuiOverride
        or (gethui and gethui())
        or CoreGui

    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "RakPeek"
    screenGui.ResetOnSpawn = false
    screenGui.IgnoreGuiInset = true
    screenGui.Parent = parentGui

    local mainFrame = Instance.new("Frame")
    mainFrame.Name = "Main"
    mainFrame.Size = UDim2.new(0, 930, 0, 550)
    mainFrame.Position = UDim2.new(0, 80, 0, 60)
    mainFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
    mainFrame.BorderSizePixel  = 0
    mainFrame.Parent = screenGui

    do
        local uiCorner = Instance.new("UICorner")
        uiCorner.CornerRadius = UDim.new(0, 8)
        uiCorner.Parent = mainFrame
    end

    local originalPos = mainFrame.Position
    mainFrame.Position = UDim2.new(
        originalPos.X.Scale,
        originalPos.X.Offset,
        originalPos.Y.Scale,
        originalPos.Y.Offset + 20
    )
    tween(mainFrame, 0.22, {
        Position = originalPos,
    }, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

    -- HEADER
    local header = Instance.new("Frame")
    header.Name = "Header"
    header.Size = UDim2.new(1, 0, 0, 28)
    header.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    header.BorderSizePixel  = 0
    header.Parent = mainFrame

    do
        local headerCorner = Instance.new("UICorner")
        headerCorner.CornerRadius = UDim.new(0, 8)
        headerCorner.Parent = header
    end

    local titleLabel = Instance.new("TextLabel")
    titleLabel.BackgroundTransparency = 1
    titleLabel.Size = UDim2.new(1, -80, 1, 0)
    titleLabel.Position = UDim2.new(0, 8, 0, 0)
    titleLabel.Font = Enum.Font.Code
    titleLabel.TextSize = 14
    titleLabel.TextXAlignment = Enum.TextXAlignment.Left
    titleLabel.TextColor3 = Color3.fromRGB(230, 230, 230)
    titleLabel.Text = "RakPeek Packet Recorder"
    titleLabel.Parent = header

    local ICON_COLOR_IDLE   = Color3.fromRGB(220, 220, 220)
    local ICON_COLOR_ACTIVE = Color3.fromRGB(255, 255, 255)

    local filtersButton = Instance.new("ImageButton")
    filtersButton.BackgroundTransparency = 1
    filtersButton.Size = UDim2.new(0, 24, 0, 24)
    filtersButton.Position = UDim2.new(1, -52, 0.5, -12)
    filtersButton.Image = "rbxassetid://7964618035"
    filtersButton.ImageColor3 = ICON_COLOR_IDLE
    filtersButton.Parent = header

    local closeButton = Instance.new("ImageButton")
    closeButton.BackgroundTransparency = 1
    closeButton.Size = UDim2.new(0, 24, 0, 24)
    closeButton.Position = UDim2.new(1, -26, 0.5, -12)
    closeButton.Image = "rbxassetid://101883294376981"
    closeButton.ImageColor3 = ICON_COLOR_IDLE
    closeButton.Parent = header

    local function hookIconPress(btn)
        btn.MouseButton1Click:Connect(function()
            tween(btn, 0.08, {Size = UDim2.new(0, 22, 0, 22)}, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
            task.delay(0.09, function()
                if btn then
                    tween(btn, 0.10, {Size = UDim2.new(0, 24, 0, 24)}, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
                end
            end)
        end)
    end

    hookIconPress(filtersButton)
    hookIconPress(closeButton)

    makeDraggable(header, mainFrame)

    local instanceExplorerFrame = InstanceExplorer.Create(screenGui)
    instanceExplorerFrame.Visible = false

    local instOpenPos   = instanceExplorerFrame.Position
    local instClosedPos = UDim2.new(
        instOpenPos.X.Scale,
        instOpenPos.X.Offset,
        instOpenPos.Y.Scale,
        instOpenPos.Y.Offset + 20
    )
    instanceExplorerFrame.Position = instClosedPos

    local instVisible = false

    if InstanceExplorer.SetOnCloseCallback then
        InstanceExplorer.SetOnCloseCallback(function()
            instVisible = false
            tween(closeButton, 0.15, {ImageColor3 = ICON_COLOR_IDLE})
        end)
    end

    closeButton.MouseButton1Click:Connect(function()
        instVisible = not instVisible

        if instVisible then
            instanceExplorerFrame.Visible = true
            tween(instanceExplorerFrame, 0.18, {Position = instOpenPos})
            tween(closeButton, 0.15, {ImageColor3 = ICON_COLOR_ACTIVE})
        else
            tween(instanceExplorerFrame, 0.18, {Position = instClosedPos})
            tween(closeButton, 0.15, {ImageColor3 = ICON_COLOR_IDLE})
            task.delay(0.20, function()
                if not instVisible and instanceExplorerFrame then
                    instanceExplorerFrame.Visible = false
                end
            end)
        end
    end)

    local filterViewerFrame, refreshFilterViewer = nil, nil
    local filterVisible = false

    if FilterViewer then
        filterViewerFrame, refreshFilterViewer = FilterViewer.Create(screenGui, Core)

        local fOpenPos = filterViewerFrame.Position
        local fClosedPos = UDim2.new(
            fOpenPos.X.Scale,
            fOpenPos.X.Offset,
            fOpenPos.Y.Scale,
            fOpenPos.Y.Offset + 20
        )
        filterViewerFrame.Position = fClosedPos
        filterViewerFrame.Visible = false

        local function setFilterOpen(open)
            if open then
                filterVisible = true
                filterViewerFrame.Visible = true
                if refreshFilterViewer then
                    refreshFilterViewer()
                end
                tween(filterViewerFrame, 0.18, {Position = fOpenPos})
                tween(filtersButton, 0.15, {ImageColor3 = ICON_COLOR_ACTIVE})
            else
                filterVisible = false
                tween(filterViewerFrame, 0.18, {Position = fClosedPos})
                tween(filtersButton, 0.15, {ImageColor3 = ICON_COLOR_IDLE})
                task.delay(0.20, function()
                    if not filterVisible and filterViewerFrame then
                        filterViewerFrame.Visible = false
                    end
                end)
            end
        end

        if FilterViewer.SetOnCloseCallback then
            FilterViewer.SetOnCloseCallback(function()
                setFilterOpen(false)
            end)
        end

        filtersButton.MouseButton1Click:Connect(function()
            setFilterOpen(not filterVisible)
        end)
    else
        filtersButton.Visible = false
    end

    local controlsFrame = Instance.new("Frame")
    controlsFrame.Name = "Controls"
    controlsFrame.Size = UDim2.new(1, -12, 0, 130)
    controlsFrame.Position = UDim2.new(0, 6, 0, 34)
    controlsFrame.BackgroundTransparency = 1
    controlsFrame.Parent = mainFrame

    local controlsLayout = Instance.new("UIListLayout")
    controlsLayout.FillDirection = Enum.FillDirection.Vertical
    controlsLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
    controlsLayout.VerticalAlignment = Enum.VerticalAlignment.Top
    controlsLayout.Padding = UDim.new(0, 4)
    controlsLayout.Parent = controlsFrame

    -- Row1: start/stop/clear + status
    local row1 = Instance.new("Frame")
    row1.Name = "Row1"
    row1.BackgroundTransparency = 1
    row1.Size = UDim2.new(1, 0, 0, 24)
    row1.Parent = controlsFrame

    local row1Layout = Instance.new("UIListLayout")
    row1Layout.FillDirection = Enum.FillDirection.Horizontal
    row1Layout.HorizontalAlignment = Enum.HorizontalAlignment.Left
    row1Layout.VerticalAlignment = Enum.VerticalAlignment.Center
    row1Layout.Padding = UDim.new(0, 6)
    row1Layout.Parent = row1

    local startBtn = makeButton(row1, "Start Recording", 130)
    local stopBtn  = makeButton(row1, "Stop Recording", 130)
    local clearBtn = makeButton(row1, "Clear", 80)

    stopBtn.AutoButtonColor = false
    stopBtn.BackgroundColor3 = Color3.fromRGB(35, 35, 35)

    local statusLabel = Instance.new("TextLabel")
    statusLabel.BackgroundTransparency = 1
    statusLabel.Size = UDim2.new(1, -380, 1, 0)
    statusLabel.Font = Enum.Font.Code
    statusLabel.TextSize = 12
    statusLabel.TextXAlignment = Enum.TextXAlignment.Left
    statusLabel.TextColor3 = Color3.fromRGB(220, 220, 160)
    statusLabel.Text = "Status: Stopped"
    statusLabel.Parent = row1

    local function updateRecordButtons(animated)
        if Core.isRecording() then
            if animated then
                tween(startBtn, 0.12, {BackgroundColor3 = Color3.fromRGB(35, 35, 35)})
                tween(stopBtn, 0.12,  {BackgroundColor3 = Color3.fromRGB(160, 70, 70)})
            else
                startBtn.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
                stopBtn.BackgroundColor3  = Color3.fromRGB(160, 70, 70)
            end
            statusLabel.Text = "Status: Recording"
            statusLabel.TextColor3 = Color3.fromRGB(160, 240, 160)
        else
            if animated then
                tween(startBtn, 0.12, {BackgroundColor3 = Color3.fromRGB(70, 160, 70)})
                tween(stopBtn, 0.12,  {BackgroundColor3 = Color3.fromRGB(35, 35, 35)})
            else
                startBtn.BackgroundColor3 = Color3.fromRGB(70, 160, 70)
                stopBtn.BackgroundColor3  = Color3.fromRGB(35, 35, 35)
            end
            statusLabel.Text = "Status: Stopped"
            statusLabel.TextColor3 = Color3.fromRGB(220, 220, 160)
        end
    end

    -- Row2: replay + delay
    local row2 = Instance.new("Frame")
    row2.Name = "Row2"
    row2.BackgroundTransparency = 1
    row2.Size = UDim2.new(1, 0, 0, 24)
    row2.Parent = controlsFrame

    local row2Layout = Instance.new("UIListLayout")
    row2Layout.FillDirection = Enum.FillDirection.Horizontal
    row2Layout.HorizontalAlignment = Enum.HorizontalAlignment.Left
    row2Layout.VerticalAlignment = Enum.VerticalAlignment.Center
    row2Layout.Padding = UDim.new(0, 6)
    row2Layout.Parent = row2

    local replaySelBtn      = makeButton(row2, "Replay Selected", 150)
    local replayAllBtn      = makeButton(row2, "Replay All", 120)
    local replayIncomingBtn = makeButton(row2, "Replay Incoming", 140)
    local replayOutgoingBtn = makeButton(row2, "Replay Outgoing", 140)

    local delayBox = Instance.new("TextBox")
    delayBox.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    delayBox.BorderSizePixel  = 0
    delayBox.Size = UDim2.new(0, 60, 0, 20)
    delayBox.Font = Enum.Font.Code
    delayBox.TextSize = 12
    delayBox.TextColor3 = Color3.fromRGB(230, 230, 230)
    delayBox.PlaceholderText = "0.03"
    delayBox.Text = ""
    delayBox.Parent = row2

    do
        local c = Instance.new("UICorner")
        c.CornerRadius = UDim.new(0, 4)
        c.Parent = delayBox
    end

    delayBox.FocusLost:Connect(function()
        local v = tonumber(delayBox.Text)
        if v and v >= 0 then
            Core.setReplayDelay(v)
        else
            Core.setReplayDelay(0)
            delayBox.Text = ""
        end
    end)

    local PacketScriptBuilder = loadstring(game:HttpGet("https://raw.githubusercontent.com/Coolmandfgfgdvcgfg/RakPeek/refs/heads/main/src/PacketScriptBuilder.lua"))()

    local scriptUi
    
    local buildScriptBtn = makeButton(row2, "Build Script", 120)
    buildScriptBtn.MouseButton1Click:Connect(function()
        if not selectedIndex then return end
        local entry = Core.getRecordedPackets()[selectedIndex]
        if not entry then return end
    
        if scriptUi and scriptUi.Frame and scriptUi.Frame.Parent then
            scriptUi.SetEntry(entry)
        else
            scriptUi = PacketScriptBuilder.Create(screenGui, entry)
        end
    end)


    -- Row3: record SEND/RECV toggles
    local togglesFrame = Instance.new("Frame")
    togglesFrame.Name = "Toggles"
    togglesFrame.BackgroundTransparency = 1
    togglesFrame.Size = UDim2.new(1, 0, 0, 24)
    togglesFrame.Parent = controlsFrame

    local togglesLayout = Instance.new("UIListLayout")
    togglesLayout.FillDirection = Enum.FillDirection.Horizontal
    togglesLayout.Padding = UDim.new(0, 8)
    togglesLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
    togglesLayout.VerticalAlignment = Enum.VerticalAlignment.Center
    togglesLayout.Parent = togglesFrame

    local sendToggle = makeToggle("Record Send", true, togglesFrame, 120, function(state)
        Core.setRecordSend(state)
    end)

    local recvToggle = makeToggle("Record Receive", true, togglesFrame, 140, function(state)
        Core.setRecordRecv(state)
    end)

    -- Row4: block / ignore filters
    local filterRow = Instance.new("Frame")
    filterRow.Name = "FilterRow"
    filterRow.BackgroundTransparency = 1
    filterRow.Size = UDim2.new(1, 0, 0, 24)
    filterRow.Parent = controlsFrame

    local filterLayout = Instance.new("UIListLayout")
    filterLayout.FillDirection = Enum.FillDirection.Horizontal
    filterLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
    filterLayout.VerticalAlignment = Enum.VerticalAlignment.Center
    filterLayout.Padding = UDim.new(0, 6)
    filterLayout.Parent = filterRow

    local idLabel = Instance.new("TextLabel")
    idLabel.BackgroundTransparency = 1
    idLabel.Size = UDim2.new(0, 200, 1, 0)
    idLabel.Font = Enum.Font.Code
    idLabel.TextSize = 12
    idLabel.TextColor3 = Color3.fromRGB(220, 220, 220)
    idLabel.TextXAlignment = Enum.TextXAlignment.Left
    idLabel.Text = "ID:"
    idLabel.Parent = filterRow

    local filterIdBox = Instance.new("TextBox")
    filterIdBox.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    filterIdBox.BorderSizePixel  = 0
    filterIdBox.Size = UDim2.new(0, 90, 0, 22)
    filterIdBox.Font = Enum.Font.Code
    filterIdBox.TextSize = 12
    filterIdBox.TextColor3 = Color3.fromRGB(230, 230, 230)
    filterIdBox.PlaceholderText = "e.g. 0x1B"
    filterIdBox.Text = ""
    filterIdBox.Parent = filterRow

    do
        local c = Instance.new("UICorner")
        c.CornerRadius = UDim.new(0, 4)
        c.Parent = filterIdBox
    end

    local filterSendToggle = makeToggle("Send", true, filterRow, 70)
    local filterRecvToggle = makeToggle("Receive", true, filterRow, 80)

    local blockBtn    = makeButton(filterRow, "Block", 80)
    local unblockBtn  = makeButton(filterRow, "Unblock", 80)
    local ignoreBtn   = makeButton(filterRow, "Ignore", 80)
    local unignoreBtn = makeButton(filterRow, "Unignore", 90)

    local function getFilterDirs()
        local dirs = {}
        local hasSend = filterSendToggle and filterSendToggle.Get()
        local hasRecv = filterRecvToggle and filterRecvToggle.Get()

        if not hasSend and not hasRecv then
            dirs[1] = "SEND"
            dirs[2] = "RECV"
        else
            if hasSend then table.insert(dirs, "SEND") end
            if hasRecv then table.insert(dirs, "RECV") end
        end

        return dirs
    end

    local function formatIdForDisplay(id)
        if not id or id < 0 or id > 255 then
            return "ID:"
        end
        local name = ID_NAMES[id]
        if name then
            return string.format("ID: 0x%02X (%d) [%s]", id, id, name)
        else
            return string.format("ID: 0x%02X (%d)", id, id)
        end
    end

    local function isCurrentIdBlocked()
        local id = parsePacketId(filterIdBox.Text)
        if not id then return false end

        local dirs = getFilterDirs()
        for _, dir in ipairs(dirs) do
            if Core.isIdBlocked(id, dir) then
                return true
            end
        end

        return false
    end

    local function isCurrentIdIgnored()
        local id = parsePacketId(filterIdBox.Text)
        if not id then return false end

        local dirs = getFilterDirs()
        for _, dir in ipairs(dirs) do
            if Core.isIdIgnored(id, dir) then
                return true
            end
        end

        return false
    end

    local function refreshFilterButtons()
        local blocked = isCurrentIdBlocked()
        local ignored = isCurrentIdIgnored()

        if blocked then
            tween(blockBtn,   0.12, {BackgroundColor3 = Color3.fromRGB(55, 55, 55)})
            tween(unblockBtn, 0.12, {BackgroundColor3 = Color3.fromRGB(160, 70, 70)})
        else
            tween(blockBtn,   0.12, {BackgroundColor3 = Color3.fromRGB(160, 70, 70)})
            tween(unblockBtn, 0.12, {BackgroundColor3 = Color3.fromRGB(55, 55, 55)})
        end

        if ignored then
            tween(ignoreBtn,   0.12, {BackgroundColor3 = Color3.fromRGB(55, 55, 55)})
            tween(unignoreBtn, 0.12, {BackgroundColor3 = Color3.fromRGB(160, 70, 70)})
        else
            tween(ignoreBtn,   0.12, {BackgroundColor3 = Color3.fromRGB(160, 70, 70)})
            tween(unignoreBtn, 0.12, {BackgroundColor3 = Color3.fromRGB(55, 55, 55)})
        end
    end

    local function setFilterIdFromNumber(id)
        if id and id >= 0 and id <= 255 then
            filterIdBox.Text = string.format("0x%02X", id)
            idLabel.Text     = formatIdForDisplay(id)
        else
            idLabel.Text = "ID:"
        end
        refreshFilterButtons()
    end

    filterIdBox.FocusLost:Connect(function()
        local id = parsePacketId(filterIdBox.Text)
        if id then
            setFilterIdFromNumber(id)
        else
            idLabel.Text = "ID: (invalid)"
            refreshFilterButtons()
        end
    end)

    refreshFilterButtons()

    local bodyFrame = Instance.new("Frame")
    bodyFrame.Name = "Body"
    bodyFrame.Position = UDim2.new(0, 6, 0, 170)
    bodyFrame.Size = UDim2.new(1, -12, 1, -176)
    bodyFrame.BackgroundTransparency = 1
    bodyFrame.Parent = mainFrame

    local bodyLayout = Instance.new("UIListLayout")
    bodyLayout.FillDirection = Enum.FillDirection.Horizontal
    bodyLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
    bodyLayout.VerticalAlignment = Enum.VerticalAlignment.Top
    bodyLayout.Padding = UDim.new(0, 6)
    bodyLayout.Parent = bodyFrame

    -- Left pane: packet list
    local listPane = Instance.new("Frame")
    listPane.Name = "ListPane"
    listPane.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    listPane.BorderSizePixel  = 0
    listPane.Size = UDim2.new(0.5, -3, 1, 0)
    listPane.Parent = bodyFrame

    do
        local c = Instance.new("UICorner")
        c.CornerRadius = UDim.new(0, 6)
        c.Parent = listPane
    end

    local headerRow2 = Instance.new("Frame")
    headerRow2.Name = "HeaderRow"
    headerRow2.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    headerRow2.BorderSizePixel  = 0
    headerRow2.Size = UDim2.new(1, -8, 0, 20)
    headerRow2.Position = UDim2.new(0, 4, 0, 4)
    headerRow2.Parent = listPane

    local function makeHeaderLabel(text, xScale, widthScale)
        local lbl = Instance.new("TextLabel")
        lbl.BackgroundTransparency = 1
        lbl.Font = Enum.Font.Code
        lbl.TextSize = 12
        lbl.TextColor3 = Color3.fromRGB(220, 220, 220)
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.Text = text
        lbl.Position = UDim2.new(xScale, 0, 0, 0)
        lbl.Size = UDim2.new(widthScale, 0, 1, 0)
        lbl.Parent = headerRow2
        return lbl
    end

    makeHeaderLabel("#",        0.00, 0.08)
    makeHeaderLabel("Dir",      0.08, 0.10)
    makeHeaderLabel("ID/Name",  0.18, 0.32)
    makeHeaderLabel("Len",      0.50, 0.15)
    makeHeaderLabel("Time",     0.65, 0.35)

    local listScroll = Instance.new("ScrollingFrame")
    listScroll.Name = "List"
    listScroll.BackgroundTransparency = 1
    listScroll.BorderSizePixel = 0
    listScroll.Position = UDim2.new(0, 4, 0, 26)
    listScroll.Size = UDim2.new(1, -8, 1, -30)
    listScroll.ScrollBarThickness = 6
    listScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
    listScroll.Parent = listPane

    local listLayout = Instance.new("UIListLayout")
    listLayout.FillDirection = Enum.FillDirection.Vertical
    listLayout.Padding = UDim.new(0, 2)
    listLayout.SortOrder = Enum.SortOrder.LayoutOrder
    listLayout.Parent = listScroll

    local function updateCanvasSize()
        listScroll.CanvasSize = UDim2.new(0, 0, 0, listLayout.AbsoluteContentSize.Y + 4)
    end

    listLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(updateCanvasSize)

    -- Right pane: viewer
    local viewerPane = Instance.new("Frame")
    viewerPane.Name = "ViewerPane"
    viewerPane.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    viewerPane.BorderSizePixel  = 0
    viewerPane.Size = UDim2.new(0.5, -3, 1, 0)
    viewerPane.ClipsDescendants = true
    viewerPane.Parent = bodyFrame

    do
        local c = Instance.new("UICorner")
        c.CornerRadius = UDim.new(0, 6)
        c.Parent = viewerPane
    end

    local viewerHeader = Instance.new("TextLabel")
    viewerHeader.Name = "ViewerHeader"
    viewerHeader.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    viewerHeader.BorderSizePixel  = 0
    viewerHeader.Size = UDim2.new(1, -8, 0, 20)
    viewerHeader.Position = UDim2.new(0, 4, 0, 4)
    viewerHeader.Font = Enum.Font.Code
    viewerHeader.TextSize = 12
    viewerHeader.TextColor3 = Color3.fromRGB(230, 230, 230)
    viewerHeader.TextXAlignment = Enum.TextXAlignment.Left
    viewerHeader.Text = "Packet Viewer – No selection"
    viewerHeader.Parent = viewerPane

    do
        local c = Instance.new("UICorner")
        c.CornerRadius = UDim.new(0, 6)
        c.Parent = viewerHeader
    end

    local packetInfoLabel = Instance.new("TextLabel")
    packetInfoLabel.Name = "Info"
    packetInfoLabel.BackgroundTransparency = 1
    packetInfoLabel.Position = UDim2.new(0, 8, 0, 26)
    packetInfoLabel.Size = UDim2.new(1, -12, 0, 18)
    packetInfoLabel.Font = Enum.Font.Code
    packetInfoLabel.TextSize = 12
    packetInfoLabel.TextXAlignment = Enum.TextXAlignment.Left
    packetInfoLabel.TextColor3 = Color3.fromRGB(210, 210, 210)
    packetInfoLabel.Text = "No packet selected"
    packetInfoLabel.Parent = viewerPane

    local viewerScroll = Instance.new("ScrollingFrame")
    viewerScroll.Name = "ViewerScroll"
    viewerScroll.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
    viewerScroll.BorderSizePixel  = 0
    viewerScroll.Position = UDim2.new(0, 4, 0, 48)
    viewerScroll.Size = UDim2.new(1, -8, 1, -52)
    viewerScroll.ScrollBarThickness = 6
    viewerScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
    viewerScroll.ClipsDescendants = true
    viewerScroll.Parent = viewerPane

    do
        local c = Instance.new("UICorner")
        c.CornerRadius = UDim.new(0, 4)
        c.Parent = viewerScroll
    end

    local packetViewerTextBox = Instance.new("TextBox")
    packetViewerTextBox.Name = "ViewerText"
    packetViewerTextBox.BackgroundTransparency = 1
    packetViewerTextBox.BorderSizePixel  = 0
    packetViewerTextBox.Position = UDim2.new(0, 2, 0, 2)
    packetViewerTextBox.Size = UDim2.new(1, -4, 0, 0)
    packetViewerTextBox.Font = Enum.Font.Code
    packetViewerTextBox.TextSize = 13
    packetViewerTextBox.TextColor3 = Color3.fromRGB(235, 235, 235)
    packetViewerTextBox.TextXAlignment = Enum.TextXAlignment.Left
    packetViewerTextBox.TextYAlignment = Enum.TextYAlignment.Top
    packetViewerTextBox.MultiLine = true
    packetViewerTextBox.ClearTextOnFocus = false
    packetViewerTextBox.TextEditable = false
    packetViewerTextBox.TextWrapped = false
    packetViewerTextBox.Text = ""
    packetViewerTextBox.Parent = viewerScroll

    local function updateViewerCanvas()
        local ok, bounds = pcall(function()
            return packetViewerTextBox.TextBounds
        end)
        if not ok or not bounds then return end

        packetViewerTextBox.Size = UDim2.new(1, -4, 0, bounds.Y + 8)
        viewerScroll.CanvasSize  = UDim2.new(0, 0, 0, packetViewerTextBox.AbsoluteSize.Y + 4)
    end

    packetViewerTextBox:GetPropertyChangedSignal("TextBounds"):Connect(updateViewerCanvas)

    -- LIST / SELECTION
    local rowInstances = {}
    local selectedIndex = nil

    local ROW_COLOR    = Color3.fromRGB(45, 45, 45)
    local ROW_SELECTED = Color3.fromRGB(70, 70, 100)

    local function updatePacketViewer(entry)
        if not entry then
            viewerHeader.Text        = "Packet Viewer – No selection"
            packetInfoLabel.Text     = "No packet selected"
            packetViewerTextBox.Text = ""
            return
        end

        local relTime = Core.getRelativeTime(entry)
        local idName  = ID_NAMES[entry.id] or "Unknown"

        viewerHeader.Text = string.format(
            "Packet Viewer – %s 0x%02X [%s] (Len %d)",
            entry.dir,
            entry.id,
            idName,
            entry.len
        )

        packetInfoLabel.Text = string.format(
            "Index: %d | Dir: %s | ID: 0x%02X [%s] | Len: %d | Time: %.4fs",
            entry.index,
            entry.dir,
            entry.id,
            idName,
            entry.len,
            relTime
        )

        local hexDump = formatBufferHexAscii(entry.buf)

        if entry.id == 0x1B then
            local decoded = decodeMovement(entry.buf)
            packetViewerTextBox.Text = decoded .. "\n\n" .. hexDump
        else
            packetViewerTextBox.Text = hexDump
        end
    end

    local function setSelectedIndex(idx)
        selectedIndex = idx

        for i, row in pairs(rowInstances) do
            if row then
                local target = (i == selectedIndex) and ROW_SELECTED or ROW_COLOR
                tween(row, 0.12, {BackgroundColor3 = target})
            end
        end

        if selectedIndex then
            local entry = Core.getRecordedPackets()[selectedIndex]
            updatePacketViewer(entry)
            if entry then
                setFilterIdFromNumber(entry.id)
            end
        else
            updatePacketViewer(nil)
            setFilterIdFromNumber(nil)
        end
    end

    local function createRow(entry)
        local row = Instance.new("TextButton")
        row.Name = "Row" .. entry.index
        row.Size = UDim2.new(1, 0, 0, 20)
        row.BackgroundColor3 = ROW_COLOR
        row.BorderSizePixel  = 0
        row.AutoButtonColor  = false
        row.Text             = ""
        row.LayoutOrder      = entry.index
        row.Parent           = listScroll

        local function mk(text, xScale, widthScale)
            local lbl = Instance.new("TextLabel")
            lbl.BackgroundTransparency = 1
            lbl.Font = Enum.Font.Code
            lbl.TextSize = 12
            lbl.TextColor3 = Color3.fromRGB(220, 220, 220)
            lbl.TextXAlignment = Enum.TextXAlignment.Left
            lbl.Text = text
            lbl.Position = UDim2.new(xScale, 0, 0, 0)
            lbl.Size = UDim2.new(widthScale, 0, 1, 0)
            lbl.Parent = row
            return lbl
        end

        local relTime = Core.getRelativeTime(entry)
        local idName  = ID_NAMES[entry.id]
        local idText
        if idName then
            idText = string.format("0x%02X %s", entry.id, idName)
        else
            idText = string.format("0x%02X", entry.id)
        end

        mk(tostring(entry.index),           0.00, 0.08)
        mk(entry.dir,                       0.08, 0.10)
        mk(idText,                          0.18, 0.32)
        mk(tostring(entry.len),             0.50, 0.15)
        mk(string.format("%.4f", relTime),  0.65, 0.35)

        row.MouseButton1Click:Connect(function()
            setSelectedIndex(entry.index)
        end)

        rowInstances[entry.index] = row
        updateCanvasSize()

        row.BackgroundTransparency = 1
        tween(row, 0.15, {BackgroundTransparency = 0})
    end

    local function rebuildList()
        for _, row in pairs(rowInstances) do
            if row then row:Destroy() end
        end
        rowInstances = {}

        for _, entry in ipairs(Core.getRecordedPackets()) do
            createRow(entry)
        end

        setSelectedIndex(nil)
    end

    -- BUTTON CALLBACKS
    startBtn.MouseButton1Click:Connect(function()
        Core.startRecording()
        updateRecordButtons(true)
    end)

    stopBtn.MouseButton1Click:Connect(function()
        Core.stopRecording()
        updateRecordButtons(true)
    end)

    clearBtn.MouseButton1Click:Connect(function()
        Core.clearPackets()
        rebuildList()
    end)

    replaySelBtn.MouseButton1Click:Connect(function()
        if not selectedIndex then return end
        Core.replayEntryByIndex(selectedIndex)
    end)

    replayAllBtn.MouseButton1Click:Connect(function()
        Core.replayAll()
    end)

    replayIncomingBtn.MouseButton1Click:Connect(function()
        Core.replayAllDir("RECV")
    end)

    replayOutgoingBtn.MouseButton1Click:Connect(function()
        Core.replayAllDir("SEND")
    end)

    local function applyBlockAction(kind, enable)
        local id = parsePacketId(filterIdBox.Text)
        if not id then
            print("[RakPeek Packet Recorder] Invalid packet ID")
            return
        end

        local dirs = getFilterDirs()
        for _, dir in ipairs(dirs) do
            if kind == "block" then
                Core.setIdBlocked(id, dir, enable)
            else
                Core.setIdIgnored(id, dir, enable)
            end
        end

        refreshFilterButtons()
        if refreshFilterViewer then
            refreshFilterViewer()
        end
    end

    blockBtn.MouseButton1Click:Connect(function()
        applyBlockAction("block", true)
    end)

    unblockBtn.MouseButton1Click:Connect(function()
        applyBlockAction("block", false)
    end)

    ignoreBtn.MouseButton1Click:Connect(function()
        applyBlockAction("ignore", true)
    end)

    unignoreBtn.MouseButton1Click:Connect(function()
        applyBlockAction("ignore", false)
    end)

    updateRecordButtons(false)

    -- HOOK CORE -> GUI 
    Core.onPacketRecorded(function(entry)
        task.defer(createRow, entry)
    end)

    return {
        ScreenGui = screenGui,
        MainFrame = mainFrame,
        InstanceExplorer = instanceExplorerFrame,
    }
end

return Gui
