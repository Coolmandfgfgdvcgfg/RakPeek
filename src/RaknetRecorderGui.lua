-- RaknetRecorderGui.lua

local Gui = {}

local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")
local UserInputService = game:GetService("UserInputService")

local function makeButton(parent, text, width)
    local btn = Instance.new("TextButton")
    btn.BackgroundColor3 = Color3.fromRGB(55, 55, 55)
    btn.TextColor3       = Color3.fromRGB(230, 230, 230)
    btn.Font             = Enum.Font.Code
    btn.TextSize         = 14
    btn.Size             = UDim2.new(0, width or 90, 0, 24)
    btn.BorderSizePixel  = 0
    btn.Text             = text

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 4)
    corner.Parent = btn

    btn.Parent = parent
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

    local function refresh()
        if state then
            box.BackgroundColor3 = Color3.fromRGB(80, 160, 80)
        else
            box.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
        end
    end

    box.MouseButton1Click:Connect(function()
        state = not state
        refresh()
        if onChanged then
            onChanged(state)
        end
    end)

    refresh()

    local t = {}

    function t.Get()
        return state
    end

    function t.Set(v)
        state = not not v
        refresh()
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

-- INSTANCE EXPLORER / DEBUG-ID CACHE

local AllInstances : {Instance}? = nil
local DebugIdMap   : {[string]: Instance}? = nil

local function BuildInstanceCache()
    if AllInstances then
        return
    end

    AllInstances = {}
    DebugIdMap   = {}

    table.insert(AllInstances, game)

    local descendants = game:GetDescendants()
    for i = 1, #descendants do
        table.insert(AllInstances, descendants[i])
    end

    for _, inst in ipairs(AllInstances) do
        local ok, id = pcall(inst.GetDebugId, inst, math.huge)
        if ok and type(id) == "string" then
            DebugIdMap[id] = inst
        end
    end
end

local function GetInstanceById(id: any): Instance?
    BuildInstanceCache()
    return DebugIdMap and DebugIdMap[tostring(id)] or nil
end

local instanceExplorerFrame: Frame? = nil
local closeButton: TextButton? = nil

local function createInstanceExplorer(parentGui: ScreenGui): Frame
    BuildInstanceCache()

    local PAGE_SIZE = 200
    local entries   = {}
    local loadedCount = 0

    local explorer = Instance.new("Frame")
    explorer.Name = "InstanceExplorer"
    explorer.Size = UDim2.new(0, 600, 0, 400)
    explorer.Position = UDim2.new(0, 920, 0, 60)
    explorer.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
    explorer.BorderSizePixel = 0
    explorer.Parent = parentGui

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = explorer

    local header = Instance.new("Frame")
    header.Size = UDim2.new(1, 0, 0, 26)
    header.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    header.BorderSizePixel  = 0
    header.Parent = explorer

    local hCorner = Instance.new("UICorner")
    hCorner.CornerRadius = UDim.new(0, 8)
    hCorner.Parent = header

    local title = Instance.new("TextLabel")
    title.BackgroundTransparency = 1
    title.Size = UDim2.new(1, -60, 1, 0)
    title.Position = UDim2.new(0, 8, 0, 0)
    title.Font = Enum.Font.Code
    title.TextSize = 14
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.TextColor3 = Color3.fromRGB(230, 230, 230)
    title.Text = "Instance Explorer"
    title.Parent = header

    local close = Instance.new("TextButton")
    close.BackgroundTransparency = 1
    close.Size = UDim2.new(0, 24, 1, 0)
    close.Position = UDim2.new(1, -26, 0, 0)
    close.Font = Enum.Font.Code
    close.TextSize = 16
    close.TextColor3 = Color3.fromRGB(255, 80, 80)
    close.Text = "X"
    close.Parent = header

    close.MouseButton1Click:Connect(function()
        explorer.Visible = false
        if closeButton then
            closeButton.Text = ">"
        end
    end)

    makeDraggable(header, explorer)

    local searchBox = Instance.new("TextBox")
    searchBox.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    searchBox.BorderSizePixel  = 0
    searchBox.Size = UDim2.new(1, -12, 0, 22)
    searchBox.Position = UDim2.new(0, 6, 0, 32)
    searchBox.Font = Enum.Font.Code
    searchBox.TextSize = 12
    searchBox.TextColor3 = Color3.fromRGB(230, 230, 230)
    searchBox.PlaceholderText = "Search by ID or name/path..."
    searchBox.Text = ""
    searchBox.Parent = explorer

    local sCorner = Instance.new("UICorner")
    sCorner.CornerRadius = UDim.new(0, 4)
    sCorner.Parent = searchBox

    local body = Instance.new("Frame")
    body.BackgroundTransparency = 1
    body.Position = UDim2.new(0, 6, 0, 60)
    body.Size = UDim2.new(1, -12, 1, -66)
    body.Parent = explorer

    local bodyLayout = Instance.new("UIListLayout")
    bodyLayout.FillDirection = Enum.FillDirection.Horizontal
    bodyLayout.Padding = UDim.new(0, 6)
    bodyLayout.Parent = body

    local listFrame = Instance.new("Frame")
    listFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    listFrame.BorderSizePixel = 0
    listFrame.Size = UDim2.new(0.55, 0, 1, 0)
    listFrame.Parent = body

    local listCorner = Instance.new("UICorner")
    listCorner.CornerRadius = UDim.new(0, 6)
    listCorner.Parent = listFrame

    local detailFrame = Instance.new("Frame")
    detailFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    detailFrame.BorderSizePixel = 0
    detailFrame.Size = UDim2.new(0.45, 0, 1, 0)
    detailFrame.Parent = body

    local detailCorner = Instance.new("UICorner")
    detailCorner.CornerRadius = UDim.new(0, 6)
    detailCorner.Parent = detailFrame

    local listScroll = Instance.new("ScrollingFrame")
    listScroll.BackgroundTransparency = 1
    listScroll.BorderSizePixel = 0
    listScroll.Position = UDim2.new(0, 4, 0, 4)
    listScroll.Size = UDim2.new(1, -8, 1, -32)
    listScroll.ScrollBarThickness = 6
    listScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
    listScroll.Parent = listFrame

    local listLayout = Instance.new("UIListLayout")
    listLayout.FillDirection = Enum.FillDirection.Vertical
    listLayout.SortOrder = Enum.SortOrder.LayoutOrder
    listLayout.Padding = UDim.new(0, 2)
    listLayout.Parent = listScroll

    listLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        listScroll.CanvasSize = UDim2.new(0, 0, 0, listLayout.AbsoluteContentSize.Y + 4)
    end)

    local loadMoreBtn = Instance.new("TextButton")
    loadMoreBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
    loadMoreBtn.BorderSizePixel  = 0
    loadMoreBtn.Size = UDim2.new(1, -8, 0, 22)
    loadMoreBtn.Position = UDim2.new(0, 4, 1, -24)
    loadMoreBtn.Font = Enum.Font.Code
    loadMoreBtn.TextSize = 12
    loadMoreBtn.TextColor3 = Color3.fromRGB(230, 230, 230)
    loadMoreBtn.Text = "Load More"
    loadMoreBtn.Parent = listFrame

    local lmCorner = Instance.new("UICorner")
    lmCorner.CornerRadius = UDim.new(0, 4)
    lmCorner.Parent = loadMoreBtn

    local detailTitle = Instance.new("TextLabel")
    detailTitle.BackgroundTransparency = 1
    detailTitle.Position = UDim2.new(0, 6, 0, 6)
    detailTitle.Size = UDim2.new(1, -12, 0, 18)
    detailTitle.Font = Enum.Font.Code
    detailTitle.TextSize = 13
    detailTitle.TextXAlignment = Enum.TextXAlignment.Left
    detailTitle.TextColor3 = Color3.fromRGB(230, 230, 230)
    detailTitle.Text = "No selection"
    detailTitle.Parent = detailFrame

    local detailText = Instance.new("TextLabel")
    detailText.BackgroundTransparency = 1
    detailText.Position = UDim2.new(0, 6, 0, 26)
    detailText.Size = UDim2.new(1, -12, 1, -32)
    detailText.Font = Enum.Font.Code
    detailText.TextSize = 12
    detailText.TextXAlignment = Enum.TextXAlignment.Left
    detailText.TextYAlignment = Enum.TextYAlignment.Top
    detailText.TextColor3 = Color3.fromRGB(210, 210, 210)
    detailText.TextWrapped = true
    detailText.Text = ""
    detailText.Parent = detailFrame

    local function describeInstance(inst: Instance, id: string?): string
        local pieces = {}
        table.insert(pieces, string.format("ClassName: %s", inst.ClassName))
        table.insert(pieces, string.format("Name: %s", inst.Name))
        table.insert(pieces, string.format("ID: %s", id or "<none>"))

        local ok, full = pcall(inst.GetFullName, inst)
        if ok then
            table.insert(pieces, "FullName:")
            table.insert(pieces, "  " .. full)
        end

        if inst:IsA("BasePart") then
            local p = inst.Position
            local s = inst.Size
            table.insert(pieces, string.format("Position: (%.3f, %.3f, %.3f)", p.X, p.Y, p.Z))
            table.insert(pieces, string.format("Size    : (%.3f, %.3f, %.3f)", s.X, s.Y, s.Z))
        end

        return table.concat(pieces, "\n")
    end

    local function ensureRow(entry)
        if entry.row and entry.row.Parent then
            return entry.row
        end

        local row = Instance.new("TextButton")
        row.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
        row.BorderSizePixel  = 0
        row.AutoButtonColor  = false
        row.Size             = UDim2.new(1, 0, 0, 20)
        row.Text             = ""
        row.LayoutOrder      = #entries
        row.Parent           = listScroll

        local lbl = Instance.new("TextLabel")
        lbl.BackgroundTransparency = 1
        lbl.Font = Enum.Font.Code
        lbl.TextSize = 12
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.TextColor3 = Color3.fromRGB(220, 220, 220)

        local ok, full = pcall(entry.inst.GetFullName, entry.inst)
        local fullName = ok and full or entry.inst.Name

        lbl.Text = string.format("[%s] %s", entry.idStr or "no-id", fullName)
        lbl.Position = UDim2.new(0, 4, 0, 0)
        lbl.Size = UDim2.new(1, -8, 1, 0)
        lbl.Parent = row

        row.MouseButton1Click:Connect(function()
            for _, e in ipairs(entries) do
                if e.row and e.row.Parent then
                    e.row.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
                end
            end
            row.BackgroundColor3 = Color3.fromRGB(70, 70, 100)
            detailTitle.Text = entry.inst.Name
            detailText.Text  = describeInstance(entry.inst, entry.idStr)
        end)

        entry.row = row
        row:SetAttribute("SearchText", entry.searchText)

        return row
    end

    for _, inst in ipairs(AllInstances :: {Instance}) do
        local idStr = nil
        local ok, id = pcall(inst.GetDebugId, inst, math.huge)
        if ok and type(id) == "string" then
            idStr = id
        end

        local fullName
        do
            local ok2, full = pcall(inst.GetFullName, inst)
            fullName = ok2 and full or inst.Name
        end

        local searchText = ((idStr or "") .. " " .. fullName):lower()

        table.insert(entries, {
            inst       = inst,
            idStr      = idStr,
            searchText = searchText,
            row        = nil,
        })
    end

    local function renderMore(count)
        local target = math.min(#entries, loadedCount + count)
        for i = loadedCount + 1, target do
            local entry = entries[i]
            ensureRow(entry)
            entry.row.Visible = true
        end
        loadedCount = target

        if loadedCount >= #entries then
            loadMoreBtn.Text = "All loaded"
            loadMoreBtn.AutoButtonColor = false
            loadMoreBtn.Active = false
        else
            loadMoreBtn.Text = string.format("Load More (%d/%d)", loadedCount, #entries)
        end
    end

    local function applyFilter()
        local q = searchBox.Text:lower()

        if q == "" then
            if loadedCount == 0 then
                renderMore(PAGE_SIZE)
            end
            for i, entry in ipairs(entries) do
                if entry.row then
                    entry.row.Visible = (i <= loadedCount)
                end
            end
        else
            for _, entry in ipairs(entries) do
                local match = string.find(entry.searchText, q, 1, true) ~= nil
                if match then
                    local row = ensureRow(entry)
                    row.Visible = true
                else
                    if entry.row then
                        entry.row.Visible = false
                    end
                end
            end
        end
    end

    loadMoreBtn.MouseButton1Click:Connect(function()
        if searchBox.Text == "" then
            renderMore(PAGE_SIZE)
        end
    end)

    searchBox:GetPropertyChangedSignal("Text"):Connect(applyFilter)

    renderMore(PAGE_SIZE)
    applyFilter()

    return explorer
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

function Gui.init(Core, parentGuiOverride: ScreenGui?)
    local ID_NAMES       = Core.ID_NAMES
    local parsePacketId  = Core.parsePacketId
    local decodeMovement = Core.decodeMovementPacket

    local parentGui = parentGuiOverride
        or (gethui and gethui())
        or CoreGui

    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "RaknetPacketRecorder"
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

    -- Instance explorer window:
    instanceExplorerFrame = createInstanceExplorer(screenGui)
    instanceExplorerFrame.Visible = false

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
    titleLabel.Size = UDim2.new(1, -60, 1, 0)
    titleLabel.Position = UDim2.new(0, 8, 0, 0)
    titleLabel.Font = Enum.Font.Code
    titleLabel.TextSize = 14
    titleLabel.TextXAlignment = Enum.TextXAlignment.Left
    titleLabel.TextColor3 = Color3.fromRGB(230, 230, 230)
    titleLabel.Text = "RakNet Packet Recorder"
    titleLabel.Parent = header

    closeButton = Instance.new("TextButton")
    closeButton.BackgroundTransparency = 1
    closeButton.Size = UDim2.new(0, 24, 1, 0)
    closeButton.Position = UDim2.new(1, -26, 0, 0)
    closeButton.Font = Enum.Font.Code
    closeButton.TextSize = 16
    closeButton.TextColor3 = Color3.fromRGB(241, 157, 0)
    closeButton.Text = ">"
    closeButton.Parent = header

    closeButton.MouseButton1Click:Connect(function()
        if instanceExplorerFrame then
            instanceExplorerFrame.Visible = not instanceExplorerFrame.Visible
            closeButton.Text = instanceExplorerFrame.Visible and "<" or ">"
        end
    end)

    makeDraggable(header, mainFrame)

    -- CONTROLS AREA (TOP)
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

    local function updateRecordButtons()
        if Core.isRecording() then
            startBtn.AutoButtonColor = false
            startBtn.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
            stopBtn.AutoButtonColor = true
            stopBtn.BackgroundColor3 = Color3.fromRGB(160, 70, 70)
            statusLabel.Text = "Status: Recording"
            statusLabel.TextColor3 = Color3.fromRGB(160, 240, 160)
        else
            startBtn.AutoButtonColor = true
            startBtn.BackgroundColor3 = Color3.fromRGB(70, 160, 70)
            stopBtn.AutoButtonColor = false
            stopBtn.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
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

    local delayLabel = Instance.new("TextLabel")
    delayLabel.BackgroundTransparency = 1
    delayLabel.Size = UDim2.new(0, 80, 1, 0)
    delayLabel.Font = Enum.Font.Code
    delayLabel.TextSize = 12
    delayLabel.TextXAlignment = Enum.TextXAlignment.Left
    delayLabel.TextColor3 = Color3.fromRGB(220, 220, 220)
    delayLabel.Text = "Delay (s):"
    delayLabel.Parent = row2

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

    local function refreshBlockButtons()
        local blocked = isCurrentIdBlocked()
        if blocked then
            blockBtn.BackgroundColor3   = Color3.fromRGB(55, 55, 55)
            unblockBtn.BackgroundColor3 = Color3.fromRGB(160, 70, 70)
        else
            blockBtn.BackgroundColor3   = Color3.fromRGB(160, 70, 70)
            unblockBtn.BackgroundColor3 = Color3.fromRGB(55, 55, 55)
        end
    end

    local function setFilterIdFromNumber(id)
        if id and id >= 0 and id <= 255 then
            filterIdBox.Text = string.format("0x%02X", id)
            idLabel.Text     = formatIdForDisplay(id)
        else
            idLabel.Text = "ID:"
        end
        refreshBlockButtons()
    end

    filterIdBox.FocusLost:Connect(function()
        local id = parsePacketId(filterIdBox.Text)
        if id then
            setFilterIdFromNumber(id)
        else
            idLabel.Text = "ID: (invalid)"
            refreshBlockButtons()
        end
    end)

    refreshBlockButtons()

    -----------------------------------------------------------------
    -- BODY: LIST + VIEWER
    -----------------------------------------------------------------
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

    local headerRow = Instance.new("Frame")
    headerRow.Name = "HeaderRow"
    headerRow.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    headerRow.BorderSizePixel  = 0
    headerRow.Size = UDim2.new(1, -8, 0, 20)
    headerRow.Position = UDim2.new(0, 4, 0, 4)
    headerRow.Parent = listPane

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
        lbl.Parent = headerRow
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
            if row and row.BackgroundColor3 then
                row.BackgroundColor3 = (i == selectedIndex)
                    and Color3.fromRGB(70, 70, 100)
                    or  Color3.fromRGB(45, 45, 45)
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
        row.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
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
        updateRecordButtons()
    end)

    stopBtn.MouseButton1Click:Connect(function()
        Core.stopRecording()
        updateRecordButtons()
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
            print("[RakNet Packet Recorder] Invalid packet ID")
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

        refreshBlockButtons()
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

    updateRecordButtons()

    -- HOOK CORE -> GUI (new packets)
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
