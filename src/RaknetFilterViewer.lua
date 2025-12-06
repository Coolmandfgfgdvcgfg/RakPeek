-- RaknetFilterViewer.lua

local FilterViewer = {}

function FilterViewer.Create(parentGui: ScreenGui, Core)
    local ID_NAMES = Core.ID_NAMES

    local frame = Instance.new("Frame")
    frame.Name = "FilterViewer"
    frame.Size = UDim2.new(0, 420, 0, 260)
    frame.Position = UDim2.new(0, 520, 0, 100)
    frame.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
    frame.BorderSizePixel = 0
    frame.Visible = true
    frame.Parent = parentGui

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = frame

    -- Header
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
    title.Size = UDim2.new(1, -60, 1, 0)
    title.Position = UDim2.new(0, 8, 0, 0)
    title.Font = Enum.Font.Code
    title.TextSize = 14
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.TextColor3 = Color3.fromRGB(230, 230, 230)
    title.Text = "Blocked / Ignored Packets"
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
        frame.Visible = false
    end)

    local dragging = false
    local dragStart
    local startPos

    header.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging  = true
            dragStart = input.Position
            startPos  = frame.Position

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
            frame.Position = UDim2.new(
                startPos.X.Scale,
                startPos.X.Offset + delta.X,
                startPos.Y.Scale,
                startPos.Y.Offset + delta.Y
            )
        end
    end)

    -- Top row
    local topRow = Instance.new("Frame")
    topRow.BackgroundTransparency = 1
    topRow.Size = UDim2.new(1, -8, 0, 24)
    topRow.Position = UDim2.new(0, 4, 0, 30)
    topRow.Parent = frame

    local refreshBtn = Instance.new("TextButton")
    refreshBtn.BackgroundColor3 = Color3.fromRGB(55, 55, 55)
    refreshBtn.BorderSizePixel  = 0
    refreshBtn.Size = UDim2.new(0, 80, 1, 0)
    refreshBtn.Font = Enum.Font.Code
    refreshBtn.TextSize = 12
    refreshBtn.TextColor3 = Color3.fromRGB(230, 230, 230)
    refreshBtn.Text = "Refresh"
    refreshBtn.Parent = topRow

    local rCorner = Instance.new("UICorner")
    rCorner.CornerRadius = UDim.new(0, 4)
    rCorner.Parent = refreshBtn

    local hintLabel = Instance.new("TextLabel")
    hintLabel.BackgroundTransparency = 1
    hintLabel.Position = UDim2.new(0, 90, 0, 0)
    hintLabel.Size = UDim2.new(1, -90, 1, 0)
    hintLabel.Font = Enum.Font.Code
    hintLabel.TextSize = 12
    hintLabel.TextXAlignment = Enum.TextXAlignment.Left
    hintLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    hintLabel.Text = "Shows IDs currently blocked / ignored per direction."
    hintLabel.Parent = topRow

    -- List area
    local listFrame = Instance.new("Frame")
    listFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    listFrame.BorderSizePixel  = 0
    listFrame.Size = UDim2.new(1, -8, 1, -60)
    listFrame.Position = UDim2.new(0, 4, 0, 58)
    listFrame.Parent = frame

    local listCorner = Instance.new("UICorner")
    listCorner.CornerRadius = UDim.new(0, 6)
    listCorner.Parent = listFrame

    local headerRow = Instance.new("Frame")
    headerRow.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    headerRow.BorderSizePixel  = 0
    headerRow.Size = UDim2.new(1, -8, 0, 20)
    headerRow.Position = UDim2.new(0, 4, 0, 4)
    headerRow.Parent = listFrame

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

    makeHeaderLabel("#",       0.00, 0.07)
    makeHeaderLabel("Type",    0.07, 0.18)
    makeHeaderLabel("Dir",     0.25, 0.12)
    makeHeaderLabel("ID/Name", 0.37, 0.33)
    makeHeaderLabel("Note",    0.70, 0.30)

    local listScroll = Instance.new("ScrollingFrame")
    listScroll.BackgroundTransparency = 1
    listScroll.BorderSizePixel = 0
    listScroll.Position = UDim2.new(0, 4, 0, 26)
    listScroll.Size = UDim2.new(1, -8, 1, -30)
    listScroll.ScrollBarThickness = 6
    listScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
    listScroll.Parent = listFrame

    local listLayout = Instance.new("UIListLayout")
    listLayout.FillDirection = Enum.FillDirection.Vertical
    listLayout.Padding = UDim.new(0, 2)
    listLayout.SortOrder = Enum.SortOrder.LayoutOrder
    listLayout.Parent = listScroll

    listLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        listScroll.CanvasSize = UDim2.new(0, 0, 0, listLayout.AbsoluteContentSize.Y + 4)
    end)

    local rows = {}

    local function clearRows()
        for _, row in ipairs(rows) do
            row:Destroy()
        end
        rows = {}
    end

    local function createRow(idx, kind, dir, id)
        local row = Instance.new("Frame")
        row.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
        row.BorderSizePixel  = 0
        row.Size = UDim2.new(1, 0, 0, 20)
        row.LayoutOrder = idx
        row.Parent = listScroll

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

        local name = ID_NAMES and ID_NAMES[id]
        local idText = name and string.format("0x%02X %s", id, name) or string.format("0x%02X", id)
        local note = ""

        if kind == "Blocked" then
            note = "Packet will not be sent/received"
        else
            note = "Hidden from recorder list"
        end

        mk(tostring(idx),  0.00, 0.07)
        mk(kind,           0.07, 0.18)
        mk(dir,            0.25, 0.12)
        mk(idText,         0.37, 0.33)
        mk(note,           0.70, 0.30)

        table.insert(rows, row)
    end

    local function refresh()
        clearRows()

        if not Core.getBlockedIds or not Core.getIgnoredIds then
            createRow(1, "Info", "-", 0)
            rows[1]:FindFirstChildOfClass("TextLabel").Text =
                "Core.getBlockedIds / getIgnoredIds not implemented."
            return
        end

        local blocked  = Core.getBlockedIds()  or {}
        local ignored  = Core.getIgnoredIds()  or {}

        local idx = 0

        for _, entry in ipairs(blocked) do
            idx += 1
            createRow(idx, "Blocked", entry.dir or "?", entry.id or 0)
        end

        for _, entry in ipairs(ignored) do
            idx += 1
            createRow(idx, "Ignored", entry.dir or "?", entry.id or 0)
        end

        if idx == 0 then
            createRow(1, "Info", "-", 0)
            rows[1]:FindFirstChildOfClass("TextLabel").Text = "No blocked / ignored IDs."
        end
    end

    refreshBtn.MouseButton1Click:Connect(refresh)

    return frame, refresh
end

return FilterViewer
