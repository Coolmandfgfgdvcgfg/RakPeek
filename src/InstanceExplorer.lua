-- InstanceExplorer.lua

local InstanceExplorer = {}

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

-- INSTANCE EXPLORER / DEBUG-ID CACHE

local AllInstances : {Instance}? = nil
local DebugIdMap   : {[string]: Instance}? = nil

local OnCloseCallback: (() -> ())? = nil

function InstanceExplorer.SetOnCloseCallback(cb: (() -> ())?)
	OnCloseCallback = cb
end

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

function InstanceExplorer.GetInstanceById(id: any): Instance?
	BuildInstanceCache()
	return DebugIdMap and DebugIdMap[tostring(id)] or nil
end

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

local function playOpenAnimation(frame: Frame)
	if not frame then return end

	local uiScale = frame:FindFirstChildOfClass("UIScale")
	if not uiScale then
		uiScale = Instance.new("UIScale")
		uiScale.Scale = 0.9
		uiScale.Parent = frame
	else
		uiScale.Scale = 0.9
	end

	local originalPos = frame.Position
	frame.Position = originalPos + UDim2.new(0, 0, 0, 10)

	frame.Visible = true

	local tweenInfo = TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

	TweenService:Create(uiScale, tweenInfo, {
		Scale = 1.0,
	}):Play()

	TweenService:Create(frame, tweenInfo, {
		Position = originalPos,
	}):Play()
end

local function playCloseAnimation(frame: Frame, onDone: (() -> ())?)
	if not frame then
		if onDone then onDone() end
		return
	end

	local uiScale = frame:FindFirstChildOfClass("UIScale")
	if not uiScale then
		uiScale = Instance.new("UIScale")
		uiScale.Scale = 1.0
		uiScale.Parent = frame
	end

	local tweenInfo = TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.In)

	local posTween = TweenService:Create(frame, tweenInfo, {
		Position = frame.Position + UDim2.new(0, 0, 0, 10),
	})

	local scaleTween = TweenService:Create(uiScale, tweenInfo, {
		Scale = 0.9,
	})

	scaleTween:Play()
	posTween:Play()

	posTween.Completed:Connect(function()
		frame.Visible = false
		uiScale.Scale = 1.0
		if onDone then
			onDone()
		end
	end)
end

function InstanceExplorer.Create(parentGui: ScreenGui): Frame
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
		playCloseAnimation(explorer, function()
			if OnCloseCallback then
				OnCloseCallback()
			end
		end)
	end)

	-- Dragging
	local dragging = false
	local dragStart
	local startPos

	header.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			dragging  = true
			dragStart = input.Position
			startPos  = explorer.Position

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
			explorer.Position = UDim2.new(
				startPos.X.Scale,
				startPos.X.Offset + delta.X,
				startPos.Y.Scale,
				startPos.Y.Offset + delta.Y
			)
		end
	end)

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

	playOpenAnimation(explorer)

	return explorer
end

return InstanceExplorer
