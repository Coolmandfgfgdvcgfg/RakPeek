-- PacketScriptBuilder.lua

-- Supports:
--   - Exact mode: exact bytes -> buffer -> raknet.send / receive
--   - Reconstructed mode only (ID 0x1B): uses id + pos variables to build a packet.

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

local function makeMiniHighlighter()
	local keywords = {
		lua = {
			"and","break","or","else","elseif","if","then","until","repeat","while","do","for","in","end",
			"local","return","function","export"
		},
		rbx = {
			"game","workspace","script","math","string","table","task","wait","select","next","Enum",
			"error","warn","tick","assert","shared","loadstring","raknet","tonumber","tostring","type",
			"typeof","unpack","print","Instance","CFrame","Vector3","Vector2","Color3","UDim","UDim2","Ray","BrickColor",
			"OverlapParams","RaycastParams","Axes","Random","Region3","Rect","TweenInfo",
			"collectgarbage","not","utf8","pcall","xpcall","_G","setmetatable","getmetatable","os","pairs","ipairs"
		},
		operators = {
			"#","+","-","*","%","/","^","=","~","<",">",",",".","(",")","{","}","[","]",";",":"
		}
	}

	local colors = {
		numbers         = Color3.fromRGB(255,198,0),
		boolean         = Color3.fromRGB(214,128,23),
		operator        = Color3.fromRGB(232,210,40),
		lua             = Color3.fromRGB(160,87,248),
		rbx             = Color3.fromRGB(146,180,253),
		str             = Color3.fromRGB(56,241,87),
		comment         = Color3.fromRGB(103,110,149),
		null            = Color3.fromRGB(79,79,79),
		call            = Color3.fromRGB(130,170,255),
		self_call       = Color3.fromRGB(227,201,141),
		local_color     = Color3.fromRGB(199,146,234),
		function_color  = Color3.fromRGB(241,122,124),
		self_color      = Color3.fromRGB(146,134,234),
		local_property  = Color3.fromRGB(129,222,255),
	}

	local function makeSet(list)
		local set = {}
		for _, k in ipairs(list) do
			set[k] = true
		end
		return set
	end

	local luaSet       = makeSet(keywords.lua)
	local rbxSet       = makeSet(keywords.rbx)
	local operatorsSet = makeSet(keywords.operators)

	local function getHighlight(tokens, i)
		local token = tokens[i]

		if colors[token .. "_color"] then
			return colors[token .. "_color"]
		end

		if tonumber(token) then
			return colors.numbers
		elseif token == "nil" then
			return colors.null
		elseif token:sub(1,2) == "--" then
			return colors.comment
		elseif operatorsSet[token] then
			return colors.operator
		elseif luaSet[token] then
			-- keep swapped scheme like your original
			return colors.rbx
		elseif rbxSet[token] then
			return colors.lua
		elseif token:sub(1,1) == "\"" or token:sub(1,1) == "'" then
			return colors.str
		elseif token == "true" or token == "false" then
			return colors.boolean
		end

		if tokens[i + 1] == "(" then
			if tokens[i - 1] == ":" then
				return colors.self_call
			end
			return colors.call
		end

		if tokens[i - 1] == "." then
			if tokens[i - 2] == "Enum" then
				return colors.rbx
			end
			return colors.local_property
		end
	end

	local function run(source: string): string
		local tokens = {}
		local currentToken = ""

		local inString = false
		local inComment = false
		local commentPersist = false

		for i = 1, #source do
			local ch = source:sub(i,i)

			if inComment then
				if ch == "\n" and not commentPersist then
					table.insert(tokens, currentToken)
					table.insert(tokens, ch)
					currentToken = ""
					inComment = false
				elseif source:sub(i-1,i) == "]]" and commentPersist then
					currentToken ..= "]"
					table.insert(tokens, currentToken)
					currentToken = ""
					inComment = false
					commentPersist = false
				else
					currentToken ..= ch
				end
			elseif inString then
				if (ch == inString and source:sub(i-1,i-1) ~= "\\") or ch == "\n" then
					currentToken ..= ch
					inString = false
				else
					currentToken ..= ch
				end
			else
				if source:sub(i, i+1) == "--" then
					table.insert(tokens, currentToken)
					currentToken = "-"
					inComment = true
					commentPersist = source:sub(i+2,i+3) == "[["
				elseif ch == "\"" or ch == "'" then
					table.insert(tokens, currentToken)
					currentToken = ch
					inString = ch
				elseif operatorsSet[ch] then
					table.insert(tokens, currentToken)
					table.insert(tokens, ch)
					currentToken = ""
				elseif ch:match("[%w_]") then
					currentToken ..= ch
				else
					table.insert(tokens, currentToken)
					table.insert(tokens, ch)
					currentToken = ""
				end
			end
		end

		table.insert(tokens, currentToken)

		local highlighted = {}

		for i, tok in ipairs(tokens) do
			if tok ~= "" then
				local col = getHighlight(tokens, i)
				if col then
					local safe = tok:gsub("&", "&amp;")
						:gsub("<","&lt;")
						:gsub(">","&gt;")
					table.insert(highlighted, string.format(
						"<font color=\"#%s\">%s</font>",
						col:ToHex(), safe
					))
				else
					local safe = tok:gsub("&", "&amp;")
						:gsub("<","&lt;")
						:gsub(">","&gt;")
					table.insert(highlighted, safe)
				end
			end
		end

		return table.concat(highlighted)
	end

	return run
end

local highlightLua = makeMiniHighlighter()

local function decodePhysicsPosFromPacket(buf)
	if buffer.readu8(buf, 0) ~= 0x1B then
		return nil
	end

	local xi = buffer.readu8(buf, 0x1D)
	local yi = buffer.readu8(buf, 0x1F)
	local zi = buffer.readu8(buf, 0x21)

	local xf = buffer.readu8(buf, 0x1E) / 256
	local yf = buffer.readu8(buf, 0x20) / 256
	local zf = buffer.readu8(buf, 0x22) / 256

	return Vector3.new(xi + xf, yi + yf, zi + zf)
end


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
	table.insert(parts, string.format(
		"-- Index: %d | Dir: %s | ID: 0x%02X | Len: %d",
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

-- Reconstructed physics packet (no template, just id + pos)
local function buildReconstructedScript(entry, asReceive: boolean?)
	local buf = entry.buf
	local pos = decodePhysicsPosFromPacket(buf)
	local packetLen = entry.len or buffer.len(buf) or 64

	local parts = {}

	table.insert(parts, "-- Reconstructed physics packet (0x1B) without raw template")
	table.insert(parts, "-- Uses id + pos variables and a small converter to build a packet.")
	table.insert(parts, string.format(
		"-- Index: %d | Dir: %s | ID: 0x%02X | CapturedLen: %d",
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
	table.insert(parts, string.format(
		"    -- Adjust packetLen if needed; captured packet length was %d",
		buffer.len(buf)
	))
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
	table.insert(parts, "    -- TODO: Fill in any other fields required by your physics protocol here")
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
		local current = frame.Position
		local target = UDim2.new(
			current.X.Scale,
			current.X.Offset,
			current.Y.Scale,
			current.Y.Offset + 20
		)
		tween(frame, 0.18, {Position = target}, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		task.delay(0.19, function()
			if frame then
				frame:Destroy()
			end
		end)
	end)

	makeDraggable(header, frame)

	-- TOP BAR
	local topBar = Instance.new("Frame")
	topBar.BackgroundTransparency = 1
	topBar.Size = UDim2.new(1, -12, 0, 48)
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

	local exactBtn = makeSmallButton(rowMode, "Exact", 90)
	local reconBtn = makeSmallButton(rowMode, "Reconstructed", 110)
	local sendBtn  = makeSmallButton(rowDir,  "Send", 80)
	local recvBtn  = makeSmallButton(rowDir,  "Receive", 80)

	-- EDITOR
	local editorBg = Instance.new("Frame")
	editorBg.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
	editorBg.BorderSizePixel  = 0
	editorBg.Position = UDim2.new(0, 6, 0, 86)
	editorBg.Size = UDim2.new(1, -12, 1, -92)
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
	editorBox.TextEditable = false -- read-only; copy still works, but includes RichText tags
	editorBox.RichText = true
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

	-- STATE
	local currentEntry = entry
	local isExactMode  = true
	local isSendMode   = true

	local function setModeButtons()
		if isExactMode then
			tween(exactBtn, 0.12, {BackgroundColor3 = Color3.fromRGB(80, 130, 200)})
			tween(reconBtn, 0.12, {BackgroundColor3 = Color3.fromRGB(55, 55, 55)})
		else
			tween(exactBtn, 0.12, {BackgroundColor3 = Color3.fromRGB(55, 55, 55)})
			tween(reconBtn, 0.12, {BackgroundColor3 = Color3.fromRGB(80, 130, 200)})
		end

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

		infoLabel.Text = string.format("Index %d | Dir: %s | ID: 0x%02X | Len: %d", idx, dir, id, len)

		if id ~= 0x1B then
			reconBtn.AutoButtonColor = false
			reconBtn.Active = false
			reconBtn.TextColor3 = Color3.fromRGB(150, 150, 150)
		else
			reconBtn.Active = true
			reconBtn.TextColor3 = Color3.fromRGB(230, 230, 230)
		end
	end

	local function setEditorText(code)
		editorBox.Text = highlightLua(code)
		updateEditorCanvas()
	end

	local function refreshScript()
		if not currentEntry or not currentEntry.buf then
			setEditorText("-- No packet selected")
			return
		end

		local id = currentEntry.id or 0
		local asReceive = not isSendMode
		local code

		if id == 0x1B and not isExactMode then
			code = buildReconstructedScript(currentEntry, asReceive)
		else
			code = buildExactScript(currentEntry, asReceive)
		end

		setEditorText(code)
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
