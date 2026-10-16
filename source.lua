--[[
	Picon UI Library  v2.4.0
	------------------------------------------------------------
	Удобства:
	 • Вкладки (Tabs)
	 • Система флагов (Flag) — Get/Set значений по имени
	 • Сворачиваемые секции
	 • ColorPicker, ProgressBar, Tooltip
	 • Поиск по элементам окна
	 • Confirm-диалог
	 • Пресеты темы
	 • Улучшенные Notify (клик = закрыть, стек)
	 • MiniButton: Left / Center / Right
	 • Прозрачность наследуется нотификациями
	 • Toggle-бинд не срабатывает при захвате клавиши
]]

local Picon = {}
Picon.__index = Picon
Picon.Version = "2.0.0"

------------------------------------------------------------
-- SERVICES
------------------------------------------------------------
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")
local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
local Camera = workspace.CurrentCamera

------------------------------------------------------------
-- CONFIG / THEME
------------------------------------------------------------
Picon.BaseResolution = Vector2.new(1920, 1080)
Picon.MinScale = 0.85
Picon.RootDisplayOrder = 999999999
Picon.WindowTransparency = 0
Picon._CapturingKeybind = false
Picon._Flags = {}          -- глобальное хранилище флагов
Picon._NotifyStack = {}    -- активные нотификации

Picon.Theme = {
	Background = Color3.fromRGB(28, 28, 34),
	Secondary  = Color3.fromRGB(38, 38, 46),
	Tertiary   = Color3.fromRGB(48, 48, 58),
	Accent     = Color3.fromRGB(88, 101, 242),
	Success    = Color3.fromRGB(67, 181, 129),
	Warning    = Color3.fromRGB(250, 166, 26),
	Error      = Color3.fromRGB(237, 66, 69),
	Text       = Color3.fromRGB(235, 235, 240),
	SubText    = Color3.fromRGB(170, 170, 180),
	Stroke     = Color3.fromRGB(55, 55, 65),
	Font       = Enum.Font.Gotham,
	FontBold   = Enum.Font.GothamBold,
}

Picon.Themes = {
	Default = {
		Background = Color3.fromRGB(28, 28, 34),
		Secondary  = Color3.fromRGB(38, 38, 46),
		Tertiary   = Color3.fromRGB(48, 48, 58),
		Accent     = Color3.fromRGB(88, 101, 242),
		Success    = Color3.fromRGB(67, 181, 129),
		Warning    = Color3.fromRGB(250, 166, 26),
		Error      = Color3.fromRGB(237, 66, 69),
		Text       = Color3.fromRGB(235, 235, 240),
		SubText    = Color3.fromRGB(170, 170, 180),
		Stroke     = Color3.fromRGB(55, 55, 65),
	},
	Midnight = {
		Background = Color3.fromRGB(12, 14, 22),
		Secondary  = Color3.fromRGB(20, 24, 36),
		Tertiary   = Color3.fromRGB(30, 36, 52),
		Accent     = Color3.fromRGB(99, 102, 241),
		Success    = Color3.fromRGB(52, 211, 153),
		Warning    = Color3.fromRGB(251, 191, 36),
		Error      = Color3.fromRGB(248, 113, 113),
		Text       = Color3.fromRGB(240, 242, 250),
		SubText    = Color3.fromRGB(148, 163, 184),
		Stroke     = Color3.fromRGB(40, 48, 68),
	},
	Ocean = {
		Background = Color3.fromRGB(15, 23, 32),
		Secondary  = Color3.fromRGB(22, 32, 44),
		Tertiary   = Color3.fromRGB(30, 42, 56),
		Accent     = Color3.fromRGB(14, 165, 233),
		Success    = Color3.fromRGB(34, 197, 94),
		Warning    = Color3.fromRGB(234, 179, 8),
		Error      = Color3.fromRGB(239, 68, 68),
		Text       = Color3.fromRGB(236, 242, 248),
		SubText    = Color3.fromRGB(148, 163, 184),
		Stroke     = Color3.fromRGB(45, 58, 72),
	},
	Rose = {
		Background = Color3.fromRGB(28, 20, 24),
		Secondary  = Color3.fromRGB(40, 28, 34),
		Tertiary   = Color3.fromRGB(52, 36, 44),
		Accent     = Color3.fromRGB(244, 63, 94),
		Success    = Color3.fromRGB(74, 222, 128),
		Warning    = Color3.fromRGB(251, 146, 60),
		Error      = Color3.fromRGB(239, 68, 68),
		Text       = Color3.fromRGB(250, 240, 244),
		SubText    = Color3.fromRGB(180, 160, 170),
		Stroke     = Color3.fromRGB(60, 42, 50),
	},
}

function Picon.SetTheme(nameOrTable)
	local t = typeof(nameOrTable) == "table" and nameOrTable or Picon.Themes[nameOrTable]
	if not t then return end
	for k, v in pairs(t) do
		Picon.Theme[k] = v
	end
end

------------------------------------------------------------
-- FLAGS
------------------------------------------------------------
function Picon.SetFlag(name, value)
	Picon._Flags[name] = value
end

function Picon.GetFlag(name, default)
	local v = Picon._Flags[name]
	if v == nil then return default end
	return v
end

function Picon.GetFlags()
	local copy = {}
	for k, v in pairs(Picon._Flags) do
		copy[k] = v
	end
	return copy
end

-- Сериализация флагов в JSON-строку (Enum.KeyCode → имя)
function Picon.FlagsToJSON()
	local out = {}
	for k, v in pairs(Picon._Flags) do
		if typeof(v) == "EnumItem" then
			out[k] = { __enum = v.EnumType.Name, name = v.Name }
		elseif typeof(v) == "Color3" then
			out[k] = { __color = true, r = v.R, g = v.G, b = v.B }
		else
			out[k] = v
		end
	end
	return HttpService:JSONEncode(out)
end

function Picon.FlagsFromJSON(json)
	local ok, data = pcall(function() return HttpService:JSONDecode(json) end)
	if not ok or typeof(data) ~= "table" then return end
	for k, v in pairs(data) do
		if typeof(v) == "table" and v.__enum then
			local et = Enum[v.__enum]
			if et then Picon._Flags[k] = et[v.name] end
		elseif typeof(v) == "table" and v.__color then
			Picon._Flags[k] = Color3.new(v.r, v.g, v.b)
		else
			Picon._Flags[k] = v
		end
	end
end

------------------------------------------------------------
-- UTILITIES
------------------------------------------------------------
local function New(className, props, children)
	local inst = Instance.new(className)
	if props then
		for k, v in pairs(props) do inst[k] = v end
	end
	if children then
		for _, c in ipairs(children) do c.Parent = inst end
	end
	return inst
end

local function Tween(inst, info, props)
	local t = TweenService:Create(inst, info, props)
	t:Play()
	return t
end

local CurrentUIScale = 1

local function MakeDraggable(handle, target)
	local dragging = false
	local dragStart, startPos
	local conns = {}

	table.insert(conns, handle.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			dragStart = input.Position
			startPos = target.Position
			local ended
			ended = input.Changed:Connect(function()
				if input.UserInputState == Enum.UserInputState.End then
					dragging = false
					if ended then ended:Disconnect() end
				end
			end)
		end
	end))

	table.insert(conns, UserInputService.InputChanged:Connect(function(input)
		if not dragging then return end
		if input.UserInputType ~= Enum.UserInputType.MouseMovement
			and input.UserInputType ~= Enum.UserInputType.Touch then
			return
		end
		local scale = math.max(CurrentUIScale, 0.01)
		local delta = (input.Position - dragStart) / scale
		target.Position = UDim2.new(
			startPos.X.Scale, startPos.X.Offset + delta.X,
			startPos.Y.Scale, startPos.Y.Offset + delta.Y
		)
	end))

	return function()
		for _, c in ipairs(conns) do c:Disconnect() end
	end
end

local function ApplyAutoLayout(content, opts)
	opts = opts or {}
	New("UIListLayout", {
		FillDirection = opts.FillDirection or Enum.FillDirection.Vertical,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, opts.Spacing or 10),
		HorizontalAlignment = opts.HorizontalAlignment or Enum.HorizontalAlignment.Left,
		VerticalAlignment = opts.VerticalAlignment or Enum.VerticalAlignment.Top,
	}).Parent = content
	New("UIPadding", {
		PaddingLeft   = UDim.new(0, opts.Padding or 14),
		PaddingRight  = UDim.new(0, opts.Padding or 14),
		PaddingTop    = UDim.new(0, opts.Padding or 14),
		PaddingBottom = UDim.new(0, opts.Padding or 14),
	}).Parent = content
end

local function PopulateButtonVisual(btn, opts, size)
	local hasIcon = opts.Icon and opts.Icon ~= ""
	local hasText = opts.Text and opts.Text ~= ""
	local spacing = opts.Spacing or 8

	if hasIcon and hasText then
		local inner = New("Frame", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
		}, {
			New("UIListLayout", {
				FillDirection = Enum.FillDirection.Horizontal,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
				Padding = UDim.new(0, spacing),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
		})
		inner.Parent = btn
		local iconSize = opts.IconSize or Vector2.new(math.max(size.Y - 16, 16), math.max(size.Y - 16, 16))
		New("ImageLabel", {
			Size = UDim2.fromOffset(iconSize.X, iconSize.Y),
			BackgroundTransparency = 1,
			Image = opts.Icon,
			LayoutOrder = 1,
		}).Parent = inner
		New("TextLabel", {
			Size = UDim2.fromOffset(math.max(size.X - iconSize.X - spacing * 3, 12), size.Y),
			BackgroundTransparency = 1,
			Text = opts.Text,
			TextColor3 = opts.TextColor or Color3.new(1, 1, 1),
			Font = Picon.Theme.FontBold,
			TextSize = opts.TextSize or 17,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Center,
			LayoutOrder = 2,
		}).Parent = inner
	elseif hasIcon then
		New("ImageLabel", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(
				opts.IconSize and opts.IconSize.X or (size.Y - 16),
				opts.IconSize and opts.IconSize.Y or (size.Y - 16)
			),
			BackgroundTransparency = 1,
			Image = opts.Icon,
		}).Parent = btn
	elseif hasText then
		btn.Text = opts.Text
		btn.TextColor3 = opts.TextColor or Color3.new(1, 1, 1)
		btn.Font = Picon.Theme.FontBold
		btn.TextSize = opts.TextSize or 17
	end
end

local function MiniPositionFromSide(side, miniSize)
	local margin = 28
	local y = margin + miniSize.Y / 2
	side = string.lower(tostring(side or "Left"))
	if side == "center" then
		return Vector2.new(Picon.BaseResolution.X / 2, y)
	elseif side == "right" then
		return Vector2.new(Picon.BaseResolution.X - margin - miniSize.X / 2, y)
	else
		return Vector2.new(margin + miniSize.X / 2, y)
	end
end

-- Простой tooltip
local TooltipFrame
local function ShowTooltip(text, anchor)
	EnsureRootExists()
	if not TooltipFrame then
		TooltipFrame = New("Frame", {
			Name = "PiconTooltip",
			Size = UDim2.fromOffset(0, 0),
			AutomaticSize = Enum.AutomaticSize.XY,
			BackgroundColor3 = Picon.Theme.Tertiary,
			BorderSizePixel = 0,
			Visible = false,
			ZIndex = 500,
		}, {
			New("UICorner", { CornerRadius = UDim.new(0, 6) }),
			New("UIStroke", { Color = Picon.Theme.Stroke, Thickness = 1 }),
			New("UIPadding", {
				PaddingTop = UDim.new(0, 6),
				PaddingBottom = UDim.new(0, 6),
				PaddingLeft = UDim.new(0, 10),
				PaddingRight = UDim.new(0, 10),
			}),
			New("TextLabel", {
				Name = "Label",
				Size = UDim2.fromOffset(0, 0),
				AutomaticSize = Enum.AutomaticSize.XY,
				BackgroundTransparency = 1,
				TextColor3 = Picon.Theme.Text,
				Font = Picon.Theme.Font,
				TextSize = 14,
				TextWrapped = false,
				ZIndex = 501,
			}),
		})
		TooltipFrame.Parent = ScaleRootGlobal
	end
	TooltipFrame.Label.Text = text
	TooltipFrame.Visible = true
	-- позиция чуть ниже курсора / элемента
	local abs = anchor.AbsolutePosition
	local asz = anchor.AbsoluteSize
	local scale = math.max(CurrentUIScale, 0.01)
	local x = (abs.X + asz.X / 2) / scale - ScaleRootGlobal.AbsolutePosition.X / scale
	local y = (abs.Y + asz.Y + 8) / scale - ScaleRootGlobal.AbsolutePosition.Y / scale
	-- fallback: просто рядом
	TooltipFrame.Position = UDim2.fromOffset(
		math.clamp(x - 40, 8, Picon.BaseResolution.X - 200),
		math.clamp(y, 8, Picon.BaseResolution.Y - 40)
	)
end

local function HideTooltip()
	if TooltipFrame then
		TooltipFrame.Visible = false
	end
end

local function AttachTooltip(gui, text)
	if not text or text == "" then return end
	gui.MouseEnter:Connect(function()
		ShowTooltip(text, gui)
	end)
	gui.MouseLeave:Connect(HideTooltip)
end

------------------------------------------------------------
-- ELEMENT BASE
------------------------------------------------------------
local Element = {}
Element.__index = Element

function Element:SetPosition(x, y)
	self.Instance.Position = UDim2.fromOffset(x, y)
end
function Element:SetSize(w, h)
	self.Instance.Size = UDim2.fromOffset(w, h)
end
function Element:SetVisible(v)
	self.Instance.Visible = v
end
function Element:Destroy()
	self.Instance:Destroy()
end

------------------------------------------------------------
-- CONTAINER
------------------------------------------------------------
local Container = setmetatable({}, Element)
Container.__index = Container

local function bindFlag(obj, flag, getFn, setFn)
	if not flag then return end
	obj._flag = flag
	function obj:GetFlag()
		return Picon.GetFlag(flag)
	end
	-- начальное значение из флага, если уже есть
	local existing = Picon.GetFlag(flag)
	if existing ~= nil and setFn then
		setFn(existing)
	end
end

function Container:AddFrame(opts)
	opts = opts or {}
	local size = opts.Size or Vector2.new(220, 110)
	local pos = opts.Position or Vector2.new(0, 0)
	local frame = New("Frame", {
		Name = opts.Name or "Frame",
		Size = opts.FillWidth and UDim2.new(1, 0, 0, size.Y) or UDim2.fromOffset(size.X, size.Y),
		Position = UDim2.fromOffset(pos.X, pos.Y),
		BackgroundColor3 = opts.Color or Picon.Theme.Secondary,
		BackgroundTransparency = opts.Transparency or 0,
		BorderSizePixel = 0,
		ClipsDescendants = opts.ClipsDescendants ~= false,
		LayoutOrder = opts.LayoutOrder or 0,
	}, {
		New("UICorner", { CornerRadius = UDim.new(0, opts.CornerRadius or 8) }),
	})
	frame.Parent = self.Content or self.Instance
	if opts.AutoLayout ~= false then
		ApplyAutoLayout(frame, opts)
	end
	return setmetatable({ Instance = frame, Content = frame }, Container)
end

function Container:AddLabel(opts)
	opts = opts or {}
	local size = opts.Size or Vector2.new(220, 28)
	local pos = opts.Position or Vector2.new(0, 0)
	local label = New("TextLabel", {
		Name = opts.Name or "Label",
		Size = opts.FillWidth and UDim2.new(1, 0, 0, size.Y) or UDim2.fromOffset(size.X, size.Y),
		Position = UDim2.fromOffset(pos.X, pos.Y),
		BackgroundTransparency = 1,
		Text = opts.Text or "Label",
		TextColor3 = opts.Color or Picon.Theme.Text,
		Font = opts.Bold and Picon.Theme.FontBold or Picon.Theme.Font,
		TextSize = opts.TextSize or 17,
		TextXAlignment = opts.Align or Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Center,
		TextWrapped = true,
		LayoutOrder = opts.LayoutOrder or 0,
	})
	label.Parent = self.Content or self.Instance
	AttachTooltip(label, opts.Tooltip)
	local obj = setmetatable({ Instance = label }, Element)
	function obj:SetText(t) label.Text = t end
	return obj
end

function Container:AddParagraph(opts)
	opts = opts or {}
	local size = opts.Size or Vector2.new(220, 56)
	local pos = opts.Position or Vector2.new(0, 0)
	local label = New("TextLabel", {
		Name = opts.Name or "Paragraph",
		Size = opts.FillWidth and UDim2.new(1, 0, 0, size.Y) or UDim2.fromOffset(size.X, size.Y),
		Position = UDim2.fromOffset(pos.X, pos.Y),
		BackgroundTransparency = 1,
		Text = opts.Text or "",
		TextColor3 = opts.Color or Picon.Theme.SubText,
		Font = Picon.Theme.Font,
		TextSize = opts.TextSize or 15,
		TextXAlignment = opts.Align or Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextWrapped = true,
		LayoutOrder = opts.LayoutOrder or 0,
	})
	label.Parent = self.Content or self.Instance
	local obj = setmetatable({ Instance = label }, Element)
	function obj:SetText(t) label.Text = t end
	return obj
end

function Container:AddButton(opts)
	opts = opts or {}
	local size = opts.Size or Vector2.new(180, 40)
	local pos = opts.Position or Vector2.new(0, 0)
	local color = opts.Color or Picon.Theme.Accent
	local btn = New("TextButton", {
		Name = opts.Name or "Button",
		Size = opts.FillWidth and UDim2.new(1, 0, 0, size.Y) or UDim2.fromOffset(size.X, size.Y),
		Position = UDim2.fromOffset(pos.X, pos.Y),
		BackgroundColor3 = color,
		AutoButtonColor = false,
		Text = "",
		BorderSizePixel = 0,
		LayoutOrder = opts.LayoutOrder or 0,
	}, {
		New("UICorner", { CornerRadius = UDim.new(0, opts.CornerRadius or 8) }),
	})
	btn.Parent = self.Content or self.Instance
	PopulateButtonVisual(btn, opts, size)
	AttachTooltip(btn, opts.Tooltip)
	btn.MouseEnter:Connect(function()
		Tween(btn, TweenInfo.new(0.12), { BackgroundColor3 = color:Lerp(Color3.new(1, 1, 1), 0.14) })
	end)
	btn.MouseLeave:Connect(function()
		Tween(btn, TweenInfo.new(0.12), { BackgroundColor3 = color })
	end)
	if opts.Callback then
		btn.MouseButton1Click:Connect(opts.Callback)
	end
	local obj = setmetatable({ Instance = btn }, Element)
	function obj:SetText(t) btn.Text = t end
	function obj:SetColor(c) color = c; btn.BackgroundColor3 = c end
	return obj
end

function Container:AddTextBox(opts)
	opts = opts or {}
	local size = opts.Size or Vector2.new(200, 38)
	local pos = opts.Position or Vector2.new(0, 0)
	local box = New("TextBox", {
		Name = opts.Name or "TextBox",
		Size = opts.FillWidth and UDim2.new(1, 0, 0, size.Y) or UDim2.fromOffset(size.X, size.Y),
		Position = UDim2.fromOffset(pos.X, pos.Y),
		BackgroundColor3 = Picon.Theme.Secondary,
		TextColor3 = Picon.Theme.Text,
		PlaceholderText = opts.Placeholder or "",
		PlaceholderColor3 = Picon.Theme.SubText,
		Text = opts.Default or (opts.Flag and Picon.GetFlag(opts.Flag, "") or ""),
		Font = Picon.Theme.Font,
		TextSize = opts.TextSize or 16,
		ClearTextOnFocus = false,
		BorderSizePixel = 0,
		LayoutOrder = opts.LayoutOrder or 0,
	}, {
		New("UICorner", { CornerRadius = UDim.new(0, 8) }),
		New("UIPadding", { PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12) }),
	})
	box.Parent = self.Content or self.Instance
	AttachTooltip(box, opts.Tooltip)
	if opts.Flag then Picon.SetFlag(opts.Flag, box.Text) end
	box.FocusLost:Connect(function(enter)
		if opts.Flag then Picon.SetFlag(opts.Flag, box.Text) end
		if opts.Callback then opts.Callback(box.Text, enter) end
	end)
	local obj = setmetatable({ Instance = box }, Element)
	function obj:GetText() return box.Text end
	function obj:SetText(t)
		box.Text = t
		if opts.Flag then Picon.SetFlag(opts.Flag, t) end
	end
	return obj
end

function Container:AddToggle(opts)
	opts = opts or {}
	local size = opts.Size or Vector2.new(220, 32)
	local pos = opts.Position or Vector2.new(0, 0)
	local state = opts.Default
	if opts.Flag and Picon.GetFlag(opts.Flag) ~= nil then
		state = Picon.GetFlag(opts.Flag)
	end
	state = state == true

	local holder = New("Frame", {
		Name = opts.Name or "Toggle",
		Size = opts.FillWidth and UDim2.new(1, 0, 0, 32) or UDim2.fromOffset(size.X, 32),
		Position = UDim2.fromOffset(pos.X, pos.Y),
		BackgroundTransparency = 1,
		LayoutOrder = opts.LayoutOrder or 0,
	})
	holder.Parent = self.Content or self.Instance
	New("TextLabel", {
		Size = UDim2.new(1, -56, 1, 0),
		BackgroundTransparency = 1,
		Text = opts.Text or "Toggle",
		TextColor3 = Picon.Theme.Text,
		Font = Picon.Theme.Font,
		TextSize = opts.TextSize or 16,
		TextXAlignment = Enum.TextXAlignment.Left,
	}).Parent = holder
	local track = New("Frame", {
		Size = UDim2.fromOffset(48, 26),
		Position = UDim2.new(1, -48, 0.5, -13),
		BackgroundColor3 = state and Picon.Theme.Accent or Picon.Theme.Tertiary,
		BorderSizePixel = 0,
	}, { New("UICorner", { CornerRadius = UDim.new(1, 0) }) })
	track.Parent = holder
	local knob = New("Frame", {
		Size = UDim2.fromOffset(20, 20),
		Position = state and UDim2.new(1, -23, 0.5, -10) or UDim2.new(0, 3, 0.5, -10),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
	}, { New("UICorner", { CornerRadius = UDim.new(1, 0) }) })
	knob.Parent = track
	local click = New("TextButton", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Text = "",
	})
	click.Parent = track
	AttachTooltip(holder, opts.Tooltip)

	local obj = setmetatable({ Instance = holder }, Element)
	function obj:Set(v)
		state = not not v
		Tween(track, TweenInfo.new(0.15), {
			BackgroundColor3 = state and Picon.Theme.Accent or Picon.Theme.Tertiary,
		})
		Tween(knob, TweenInfo.new(0.15), {
			Position = state and UDim2.new(1, -23, 0.5, -10) or UDim2.new(0, 3, 0.5, -10),
		})
		if opts.Flag then Picon.SetFlag(opts.Flag, state) end
		if opts.Callback then opts.Callback(state) end
	end
	function obj:Get() return state end
	click.MouseButton1Click:Connect(function() obj:Set(not state) end)
	if opts.Flag then Picon.SetFlag(opts.Flag, state) end
	return obj
end

function Container:AddImage(opts)
	opts = opts or {}
	local size = opts.Size or Vector2.new(110, 110)
	local pos = opts.Position or Vector2.new(0, 0)
	local img = New("ImageLabel", {
		Name = opts.Name or "Image",
		Size = opts.FillWidth and UDim2.new(1, 0, 0, size.Y) or UDim2.fromOffset(size.X, size.Y),
		Position = UDim2.fromOffset(pos.X, pos.Y),
		BackgroundTransparency = 1,
		Image = opts.Image or opts.Icon or "",
		ScaleType = opts.ScaleType or Enum.ScaleType.Fit,
		LayoutOrder = opts.LayoutOrder or 0,
	})
	img.Parent = self.Content or self.Instance
	return setmetatable({ Instance = img }, Element)
end

function Container:AddDivider(opts)
	opts = opts or {}
	local line = New("Frame", {
		Name = "Divider",
		Size = UDim2.new(1, 0, 0, opts.Height or 1),
		BackgroundColor3 = opts.Color or Picon.Theme.Stroke,
		BorderSizePixel = 0,
		LayoutOrder = opts.LayoutOrder or 0,
	})
	line.Parent = self.Content or self.Instance
	return setmetatable({ Instance = line }, Element)
end

function Container:AddSection(opts)
	opts = opts or {}
	local collapsed = opts.Collapsed == true
	local collapsible = opts.Collapsible == true

	local holder = New("Frame", {
		Name = "Section",
		Size = UDim2.new(1, 0, 0, 34),
		BackgroundTransparency = 1,
		LayoutOrder = opts.LayoutOrder or 0,
		ClipsDescendants = false,
	})
	holder.Parent = self.Content or self.Instance

	local header = New("TextButton", {
		Size = UDim2.new(1, 0, 0, 34),
		BackgroundTransparency = 1,
		Text = "",
		AutoButtonColor = false,
	})
	header.Parent = holder

	local arrow = New("TextLabel", {
		Size = UDim2.fromOffset(20, 34),
		BackgroundTransparency = 1,
		Text = collapsible and (collapsed and "▶" or "▼") or "",
		TextColor3 = Picon.Theme.SubText,
		Font = Picon.Theme.Font,
		TextSize = 12,
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	arrow.Parent = header

	local title = New("TextLabel", {
		Size = UDim2.new(1, collapsible and -24 or 0, 1, 0),
		Position = UDim2.fromOffset(collapsible and 20 or 0, 0),
		BackgroundTransparency = 1,
		Text = opts.Text or "Section",
		TextColor3 = opts.Color or Picon.Theme.SubText,
		Font = Picon.Theme.FontBold,
		TextSize = opts.TextSize or 15,
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	title.Parent = header

	if opts.Divider ~= false then
		New("Frame", {
			Size = UDim2.new(1, 0, 0, 1),
			Position = UDim2.new(0, 0, 1, -1),
			BackgroundColor3 = Picon.Theme.Stroke,
			BorderSizePixel = 0,
		}).Parent = header
	end

	-- Контент секции (для collapsible)
	local body
	local sectionContainer
	if collapsible then
		body = New("Frame", {
			Name = "Body",
			Size = UDim2.new(1, 0, 0, 0),
			Position = UDim2.fromOffset(0, 34),
			BackgroundTransparency = 1,
			AutomaticSize = Enum.AutomaticSize.Y,
			Visible = not collapsed,
		})
		body.Parent = holder
		ApplyAutoLayout(body, { Padding = 4, Spacing = 8 })
		sectionContainer = setmetatable({ Instance = body, Content = body }, Container)

		header.MouseButton1Click:Connect(function()
			collapsed = not collapsed
			body.Visible = not collapsed
			arrow.Text = collapsed and "▶" or "▼"
			-- holder height auto via children
		end)
	end

	local obj = setmetatable({
		Instance = holder,
		Content = body or (self.Content or self.Instance),
		_body = body,
	}, collapsible and Container or Element)

	function obj:SetText(t)
		title.Text = t
	end
	function obj:SetCollapsed(v)
		if not collapsible then return end
		collapsed = not not v
		body.Visible = not collapsed
		arrow.Text = collapsed and "▶" or "▼"
	end

	-- Если collapsible — возвращаем контейнер, в который кладут элементы
	if collapsible then
		return sectionContainer
	end
	return obj
end

function Container:AddSlider(opts)
	opts = opts or {}
	local minV, maxV = opts.Min or 0, opts.Max or 100
	local value = opts.Default
	if opts.Flag and Picon.GetFlag(opts.Flag) ~= nil then
		value = Picon.GetFlag(opts.Flag)
	end
	value = math.clamp(value or minV, minV, maxV)
	local decimals = opts.Decimals or 0
	local size = opts.Size or Vector2.new(220, 48)
	local pos = opts.Position or Vector2.new(0, 0)

	local holder = New("Frame", {
		Name = opts.Name or "Slider",
		Size = opts.FillWidth and UDim2.new(1, 0, 0, size.Y) or UDim2.fromOffset(size.X, size.Y),
		Position = UDim2.fromOffset(pos.X, pos.Y),
		BackgroundTransparency = 1,
		LayoutOrder = opts.LayoutOrder or 0,
	})
	holder.Parent = self.Content or self.Instance
	New("TextLabel", {
		Size = UDim2.new(1, -60, 0, 22),
		BackgroundTransparency = 1,
		Text = opts.Text or "Slider",
		TextColor3 = Picon.Theme.Text,
		Font = Picon.Theme.Font,
		TextSize = 16,
		TextXAlignment = Enum.TextXAlignment.Left,
	}).Parent = holder
	local valueLabel = New("TextLabel", {
		Size = UDim2.new(0, 56, 0, 22),
		Position = UDim2.new(1, -56, 0, 0),
		BackgroundTransparency = 1,
		Text = string.format("%." .. decimals .. "f", value),
		TextColor3 = Picon.Theme.SubText,
		Font = Picon.Theme.FontBold,
		TextSize = 15,
		TextXAlignment = Enum.TextXAlignment.Right,
	})
	valueLabel.Parent = holder
	local track = New("Frame", {
		Size = UDim2.new(1, 0, 0, 10),
		Position = UDim2.new(0, 0, 0, 30),
		BackgroundColor3 = Picon.Theme.Tertiary,
		BorderSizePixel = 0,
	}, { New("UICorner", { CornerRadius = UDim.new(1, 0) }) })
	track.Parent = holder
	local fill = New("Frame", {
		Size = UDim2.new((value - minV) / math.max(maxV - minV, 1e-6), 0, 1, 0),
		BackgroundColor3 = opts.Color or Picon.Theme.Accent,
		BorderSizePixel = 0,
	}, { New("UICorner", { CornerRadius = UDim.new(1, 0) }) })
	fill.Parent = track
	local knob = New("Frame", {
		Size = UDim2.fromOffset(18, 18),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new((value - minV) / math.max(maxV - minV, 1e-6), 0, 0.5, 0),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		ZIndex = 2,
	}, { New("UICorner", { CornerRadius = UDim.new(1, 0) }) })
	knob.Parent = track
	AttachTooltip(holder, opts.Tooltip)

	local dragging = false
	local function apply(v, fire)
		value = math.clamp(v, minV, maxV)
		if decimals == 0 then
			value = math.floor(value + 0.5)
		else
			local m = 10 ^ decimals
			value = math.floor(value * m + 0.5) / m
		end
		local a = (value - minV) / math.max(maxV - minV, 1e-6)
		fill.Size = UDim2.new(a, 0, 1, 0)
		knob.Position = UDim2.new(a, 0, 0.5, 0)
		valueLabel.Text = string.format("%." .. decimals .. "f", value)
		if opts.Flag then Picon.SetFlag(opts.Flag, value) end
		if fire and opts.Callback then opts.Callback(value) end
	end

	local function setFromX(x)
		local absX = track.AbsolutePosition.X
		local w = track.AbsoluteSize.X
		if w <= 0 then return end
		local alpha = math.clamp((x - absX) / w, 0, 1)
		apply(minV + alpha * (maxV - minV), true)
	end

	track.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			setFromX(input.Position.X)
		end
	end)
	UserInputService.InputChanged:Connect(function(input)
		if not dragging then return end
		if input.UserInputType == Enum.UserInputType.MouseMovement
			or input.UserInputType == Enum.UserInputType.Touch then
			setFromX(input.Position.X)
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch then
			dragging = false
		end
	end)

	local obj = setmetatable({ Instance = holder }, Element)
	function obj:Set(v) apply(v, true) end
	function obj:Get() return value end
	if opts.Flag then Picon.SetFlag(opts.Flag, value) end
	return obj
end

function Container:AddDropdown(opts)
	opts = opts or {}
	local options = opts.Options or { "Option 1", "Option 2" }
	local current = opts.Default
	if opts.Flag and Picon.GetFlag(opts.Flag) ~= nil then
		current = Picon.GetFlag(opts.Flag)
	end
	current = current or options[1]
	local size = opts.Size or Vector2.new(220, 38)
	local pos = opts.Position or Vector2.new(0, 0)
	local open = false
	local outsideConn

	local holder = New("Frame", {
		Name = opts.Name or "Dropdown",
		Size = opts.FillWidth and UDim2.new(1, 0, 0, size.Y) or UDim2.fromOffset(size.X, size.Y),
		Position = UDim2.fromOffset(pos.X, pos.Y),
		BackgroundTransparency = 1,
		LayoutOrder = opts.LayoutOrder or 0,
		ZIndex = 5,
	})
	holder.Parent = self.Content or self.Instance
	local btnY = 0
	if opts.Text then
		New("TextLabel", {
			Size = UDim2.new(1, 0, 0, 22),
			BackgroundTransparency = 1,
			Text = opts.Text,
			TextColor3 = Picon.Theme.Text,
			Font = Picon.Theme.Font,
			TextSize = 16,
			TextXAlignment = Enum.TextXAlignment.Left,
		}).Parent = holder
		holder.Size = UDim2.new(holder.Size.X.Scale, holder.Size.X.Offset, 0, size.Y + 24)
		btnY = 24
	end
	local btn = New("TextButton", {
		Size = UDim2.new(1, 0, 0, size.Y),
		Position = UDim2.fromOffset(0, btnY),
		BackgroundColor3 = Picon.Theme.Secondary,
		Text = "",
		AutoButtonColor = false,
		BorderSizePixel = 0,
		ZIndex = 6,
	}, { New("UICorner", { CornerRadius = UDim.new(0, 8) }) })
	btn.Parent = holder
	local selectedLabel = New("TextLabel", {
		Size = UDim2.new(1, -32, 1, 0),
		Position = UDim2.fromOffset(14, 0),
		BackgroundTransparency = 1,
		Text = tostring(current),
		TextColor3 = Picon.Theme.Text,
		Font = Picon.Theme.Font,
		TextSize = 16,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 7,
	})
	selectedLabel.Parent = btn
	local arrow = New("TextLabel", {
		Size = UDim2.fromOffset(24, 24),
		Position = UDim2.new(1, -28, 0.5, -12),
		BackgroundTransparency = 1,
		Text = "▼",
		TextColor3 = Picon.Theme.SubText,
		Font = Picon.Theme.Font,
		TextSize = 12,
		ZIndex = 7,
	})
	arrow.Parent = btn
	AttachTooltip(holder, opts.Tooltip)

	-- Список на ScaleRoot (портал) — строго под кнопкой, со своим скроллом
	local ITEM_H = 32
	local ITEM_PAD = 3
	local LIST_PAD = 10 -- UIPadding top+bottom
	local MAX_VISIBLE = 6 -- сколько пунктов видно без скролла
	local MAX_LIST_H = MAX_VISIBLE * (ITEM_H + ITEM_PAD) + LIST_PAD

	local listFrame = New("ScrollingFrame", {
		Name = "PiconDropdownList",
		Size = UDim2.fromOffset(200, 0),
		BackgroundColor3 = Picon.Theme.Secondary,
		BorderSizePixel = 0,
		Visible = false,
		ClipsDescendants = true,
		ZIndex = 400,
		ScrollBarThickness = 4,
		ScrollBarImageColor3 = Picon.Theme.Stroke,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		CanvasSize = UDim2.new(0, 0, 0, 0),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		Selectable = false,
	}, {
		New("UICorner", { CornerRadius = UDim.new(0, 8) }),
		New("UIStroke", { Color = Picon.Theme.Stroke, Thickness = 1 }),
		New("UIListLayout", {
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, ITEM_PAD),
		}),
		New("UIPadding", {
			PaddingTop = UDim.new(0, 5),
			PaddingBottom = UDim.new(0, 5),
			PaddingLeft = UDim.new(0, 5),
			PaddingRight = UDim.new(0, 5),
		}),
	})

	local function absToRoot(absPos)
		EnsureRootExists()
		local rootAbs = ScaleRootGlobal.AbsolutePosition
		local scale = math.max(CurrentUIScale, 0.01)
		return Vector2.new(
			(absPos.X - rootAbs.X) / scale,
			(absPos.Y - rootAbs.Y) / scale
		)
	end

	-- Высота контента и видимой области списка
	local function listHeights()
		local contentH = #options * (ITEM_H + ITEM_PAD) - ITEM_PAD + LIST_PAD
		contentH = math.max(contentH, ITEM_H + LIST_PAD)
		local visibleH = math.min(contentH, MAX_LIST_H)
		return contentH, visibleH
	end

	local function closeList()
		if not open then return end
		open = false
		arrow.Text = "▼"
		local w = listFrame.Size.X.Offset
		Tween(listFrame, TweenInfo.new(0.12), { Size = UDim2.fromOffset(w, 0) })
		task.delay(0.13, function()
			if not open then
				listFrame.Visible = false
			end
		end)
		if outsideConn then
			outsideConn:Disconnect()
			outsideConn = nil
		end
	end

	local function pick(opt)
		current = opt
		selectedLabel.Text = tostring(opt)
		closeList()
		if opts.Flag then Picon.SetFlag(opts.Flag, opt) end
		if opts.Callback then opts.Callback(opt) end
	end

	local function rebuild()
		for _, c in ipairs(listFrame:GetChildren()) do
			if c:IsA("TextButton") then c:Destroy() end
		end
		for i, opt in ipairs(options) do
			local item = New("TextButton", {
				Size = UDim2.new(1, -4, 0, ITEM_H),
				BackgroundColor3 = Picon.Theme.Tertiary,
				Text = tostring(opt),
				TextColor3 = Picon.Theme.Text,
				Font = Picon.Theme.Font,
				TextSize = 15,
				AutoButtonColor = false,
				BorderSizePixel = 0,
				LayoutOrder = i,
				ZIndex = 401,
			}, { New("UICorner", { CornerRadius = UDim.new(0, 6) }) })
			item.Parent = listFrame
			item.MouseEnter:Connect(function()
				Tween(item, TweenInfo.new(0.1), { BackgroundColor3 = Picon.Theme.Accent })
			end)
			item.MouseLeave:Connect(function()
				Tween(item, TweenInfo.new(0.1), { BackgroundColor3 = Picon.Theme.Tertiary })
			end)
			item.MouseButton1Click:Connect(function() pick(opt) end)
		end
	end
	rebuild()

	local function openList()
		EnsureRootExists()
		if listFrame.Parent ~= ScaleRootGlobal then
			listFrame.Parent = ScaleRootGlobal
		end

		local _, visibleH = listHeights()
		local scale = math.max(CurrentUIScale, 0.01)

		local btnAbs = btn.AbsolutePosition
		local btnSz = btn.AbsoluteSize
		local rootPos = absToRoot(btnAbs)
		local width = btnSz.X / scale
		local listX = math.clamp(rootPos.X, 4, math.max(4, Picon.BaseResolution.X - width - 4))

		-- Нижняя точка кнопки в координатах ScaleRoot
		local belowY = rootPos.Y + btnSz.Y / scale + 4
		local spaceBelow = Picon.BaseResolution.Y - belowY - 4
		-- Открываем вниз, если места хватает; иначе — вверх от верха кнопки
		local openDown = spaceBelow >= visibleH or rootPos.Y < visibleH + 8

		if openDown then
			-- Якорь сверху: Size растёт вниз от низа кнопки
			listFrame.AnchorPoint = Vector2.new(0, 0)
			listFrame.Position = UDim2.fromOffset(listX, belowY)
			arrow.Text = "▲"
		else
			-- Якорь снизу: Size растёт вверх от верха кнопки
			listFrame.AnchorPoint = Vector2.new(0, 1)
			listFrame.Position = UDim2.fromOffset(listX, rootPos.Y - 4)
			arrow.Text = "▼"
		end

		listFrame.CanvasPosition = Vector2.new(0, 0)
		listFrame.Size = UDim2.fromOffset(width, 0)
		listFrame.Visible = true
		listFrame.ZIndex = 400
		open = true
		Tween(listFrame, TweenInfo.new(0.15), { Size = UDim2.fromOffset(width, visibleH) })

		if outsideConn then outsideConn:Disconnect() end
		outsideConn = UserInputService.InputBegan:Connect(function(input)
			if not open then return end
			if input.UserInputType ~= Enum.UserInputType.MouseButton1
				and input.UserInputType ~= Enum.UserInputType.Touch then
				return
			end
			local p = input.Position
			local lp = listFrame.AbsolutePosition
			local ls = listFrame.AbsoluteSize
			local bp = btn.AbsolutePosition
			local bs = btn.AbsoluteSize
			local inList = p.X >= lp.X and p.X <= lp.X + ls.X and p.Y >= lp.Y and p.Y <= lp.Y + ls.Y
			local inBtn = p.X >= bp.X and p.X <= bp.X + bs.X and p.Y >= bp.Y and p.Y <= bp.Y + bs.Y
			if not inList and not inBtn then
				closeList()
			end
		end)
	end

	btn.MouseButton1Click:Connect(function()
		if open then
			closeList()
		else
			openList()
		end
	end)

	holder.Destroying:Connect(function()
		if outsideConn then outsideConn:Disconnect() end
		if listFrame then listFrame:Destroy() end
	end)

	local obj = setmetatable({ Instance = holder }, Element)
	function obj:Set(v) pick(v) end
	function obj:Get() return current end
	function obj:SetOptions(list)
		options = list or {}
		rebuild()
	end
	function obj:Close()
		closeList()
	end
	if opts.Flag then Picon.SetFlag(opts.Flag, current) end
	return obj
end

function Container:AddKeybind(opts)
	opts = opts or {}
	local current = opts.Default or Enum.KeyCode.Unknown
	if opts.Flag and typeof(Picon.GetFlag(opts.Flag)) == "EnumItem" then
		current = Picon.GetFlag(opts.Flag)
	end
	local listening = false
	local size = opts.Size or Vector2.new(220, 34)
	local pos = opts.Position or Vector2.new(0, 0)

	local holder = New("Frame", {
		Name = opts.Name or "Keybind",
		Size = opts.FillWidth and UDim2.new(1, 0, 0, size.Y) or UDim2.fromOffset(size.X, size.Y),
		Position = UDim2.fromOffset(pos.X, pos.Y),
		BackgroundTransparency = 1,
		LayoutOrder = opts.LayoutOrder or 0,
	})
	holder.Parent = self.Content or self.Instance
	New("TextLabel", {
		Size = UDim2.new(1, -100, 1, 0),
		BackgroundTransparency = 1,
		Text = opts.Text or "Keybind",
		TextColor3 = Picon.Theme.Text,
		Font = Picon.Theme.Font,
		TextSize = 16,
		TextXAlignment = Enum.TextXAlignment.Left,
	}).Parent = holder
	local btn = New("TextButton", {
		Size = UDim2.fromOffset(92, 30),
		Position = UDim2.new(1, -92, 0.5, -15),
		BackgroundColor3 = Picon.Theme.Secondary,
		Text = (current.Name ~= "Unknown") and current.Name or "...",
		TextColor3 = Picon.Theme.Text,
		Font = Picon.Theme.FontBold,
		TextSize = 14,
		AutoButtonColor = false,
		BorderSizePixel = 0,
	}, { New("UICorner", { CornerRadius = UDim.new(0, 6) }) })
	btn.Parent = holder
	AttachTooltip(holder, opts.Tooltip)

	local conn
	btn.MouseButton1Click:Connect(function()
		if listening then return end
		listening = true
		Picon._CapturingKeybind = true
		btn.Text = "..."
		btn.BackgroundColor3 = Picon.Theme.Accent
		conn = UserInputService.InputBegan:Connect(function(input, gp)
			if gp then return end
			if input.UserInputType == Enum.UserInputType.Keyboard then
				-- Escape = сброс
				if input.KeyCode == Enum.KeyCode.Escape then
					listening = false
					btn.Text = (current.Name ~= "Unknown") and current.Name or "..."
					btn.BackgroundColor3 = Picon.Theme.Secondary
					task.defer(function() Picon._CapturingKeybind = false end)
					if conn then conn:Disconnect(); conn = nil end
					return
				end
				current = input.KeyCode
				btn.Text = current.Name
				btn.BackgroundColor3 = Picon.Theme.Secondary
				listening = false
				task.defer(function() Picon._CapturingKeybind = false end)
				if conn then conn:Disconnect(); conn = nil end
				if opts.Flag then Picon.SetFlag(opts.Flag, current) end
				if opts.Callback then opts.Callback(current) end
			end
		end)
	end)

	local obj = setmetatable({ Instance = holder }, Element)
	function obj:Get() return current end
	function obj:Set(key)
		current = key
		btn.Text = (key.Name ~= "Unknown") and key.Name or "..."
		if opts.Flag then Picon.SetFlag(opts.Flag, key) end
	end
	if opts.Flag then Picon.SetFlag(opts.Flag, current) end
	return obj
end

function Container:AddProgressBar(opts)
	opts = opts or {}
	local value = math.clamp(opts.Default or 0, 0, 1)
	local size = opts.Size or Vector2.new(220, 36)
	local pos = opts.Position or Vector2.new(0, 0)

	local holder = New("Frame", {
		Name = opts.Name or "Progress",
		Size = opts.FillWidth and UDim2.new(1, 0, 0, size.Y) or UDim2.fromOffset(size.X, size.Y),
		Position = UDim2.fromOffset(pos.X, pos.Y),
		BackgroundTransparency = 1,
		LayoutOrder = opts.LayoutOrder or 0,
	})
	holder.Parent = self.Content or self.Instance

	if opts.Text then
		New("TextLabel", {
			Size = UDim2.new(1, -50, 0, 20),
			BackgroundTransparency = 1,
			Text = opts.Text,
			TextColor3 = Picon.Theme.Text,
			Font = Picon.Theme.Font,
			TextSize = 15,
			TextXAlignment = Enum.TextXAlignment.Left,
		}).Parent = holder
	end

	local pctLabel = New("TextLabel", {
		Size = UDim2.new(0, 48, 0, 20),
		Position = UDim2.new(1, -48, 0, 0),
		BackgroundTransparency = 1,
		Text = math.floor(value * 100 + 0.5) .. "%",
		TextColor3 = Picon.Theme.SubText,
		Font = Picon.Theme.FontBold,
		TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Right,
	})
	pctLabel.Parent = holder

	local track = New("Frame", {
		Size = UDim2.new(1, 0, 0, 10),
		Position = UDim2.new(0, 0, 0, opts.Text and 24 or 12),
		BackgroundColor3 = Picon.Theme.Tertiary,
		BorderSizePixel = 0,
	}, { New("UICorner", { CornerRadius = UDim.new(1, 0) }) })
	track.Parent = holder

	local fill = New("Frame", {
		Size = UDim2.new(value, 0, 1, 0),
		BackgroundColor3 = opts.Color or Picon.Theme.Accent,
		BorderSizePixel = 0,
	}, { New("UICorner", { CornerRadius = UDim.new(1, 0) }) })
	fill.Parent = track

	local obj = setmetatable({ Instance = holder }, Element)
	function obj:Set(v)
		value = math.clamp(v, 0, 1)
		Tween(fill, TweenInfo.new(0.2), { Size = UDim2.new(value, 0, 1, 0) })
		pctLabel.Text = math.floor(value * 100 + 0.5) .. "%"
	end
	function obj:Get() return value end
	return obj
end

function Container:AddColorPicker(opts)
	opts = opts or {}
	local color = opts.Default or Picon.Theme.Accent
	if opts.Flag and typeof(Picon.GetFlag(opts.Flag)) == "Color3" then
		color = Picon.GetFlag(opts.Flag)
	end
	local size = opts.Size or Vector2.new(220, 34)
	local pos = opts.Position or Vector2.new(0, 0)

	local holder = New("Frame", {
		Name = opts.Name or "ColorPicker",
		Size = opts.FillWidth and UDim2.new(1, 0, 0, size.Y) or UDim2.fromOffset(size.X, size.Y),
		Position = UDim2.fromOffset(pos.X, pos.Y),
		BackgroundTransparency = 1,
		LayoutOrder = opts.LayoutOrder or 0,
	})
	holder.Parent = self.Content or self.Instance

	New("TextLabel", {
		Size = UDim2.new(1, -44, 1, 0),
		BackgroundTransparency = 1,
		Text = opts.Text or "Color",
		TextColor3 = Picon.Theme.Text,
		Font = Picon.Theme.Font,
		TextSize = 16,
		TextXAlignment = Enum.TextXAlignment.Left,
	}).Parent = holder

	local swatch = New("TextButton", {
		Size = UDim2.fromOffset(32, 32),
		Position = UDim2.new(1, -36, 0.5, -16),
		BackgroundColor3 = color,
		Text = "",
		AutoButtonColor = false,
		BorderSizePixel = 0,
	}, {
		New("UICorner", { CornerRadius = UDim.new(0, 8) }),
		New("UIStroke", { Color = Picon.Theme.Stroke, Thickness = 1 }),
	})
	swatch.Parent = holder
	AttachTooltip(holder, opts.Tooltip)

	-- Простая палитра при клике
	local paletteOpen = false
	local palette
	local presets = {
		Color3.fromRGB(88, 101, 242),
		Color3.fromRGB(67, 181, 129),
		Color3.fromRGB(250, 166, 26),
		Color3.fromRGB(237, 66, 69),
		Color3.fromRGB(236, 72, 153),
		Color3.fromRGB(14, 165, 233),
		Color3.fromRGB(168, 85, 247),
		Color3.fromRGB(255, 255, 255),
		Color3.fromRGB(30, 30, 35),
		Color3.fromRGB(234, 179, 8),
	}

	local function setColor(c)
		color = c
		swatch.BackgroundColor3 = c
		if opts.Flag then Picon.SetFlag(opts.Flag, c) end
		if opts.Callback then opts.Callback(c) end
	end

	swatch.MouseButton1Click:Connect(function()
		if paletteOpen and palette then
			palette:Destroy()
			palette = nil
			paletteOpen = false
			return
		end
		EnsureRootExists()
		paletteOpen = true
		local scale = math.max(CurrentUIScale, 0.01)
		local swAbs = swatch.AbsolutePosition
		local swSz = swatch.AbsoluteSize
		local rootAbs = ScaleRootGlobal.AbsolutePosition
		local x = (swAbs.X - rootAbs.X) / scale - 128
		local y = (swAbs.Y - rootAbs.Y) / scale + swSz.Y / scale + 6
		x = math.clamp(x, 4, Picon.BaseResolution.X - 168)
		y = math.clamp(y, 4, Picon.BaseResolution.Y - 80)

		palette = New("Frame", {
			Size = UDim2.fromOffset(160, 72),
			Position = UDim2.fromOffset(x, y),
			BackgroundColor3 = Picon.Theme.Secondary,
			BorderSizePixel = 0,
			ZIndex = 400,
		}, {
			New("UICorner", { CornerRadius = UDim.new(0, 8) }),
			New("UIStroke", { Color = Picon.Theme.Stroke, Thickness = 1 }),
			New("UIPadding", {
				PaddingTop = UDim.new(0, 8), PaddingBottom = UDim.new(0, 8),
				PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8),
			}),
			New("UIGridLayout", {
				CellSize = UDim2.fromOffset(24, 24),
				CellPadding = UDim2.fromOffset(6, 6),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
		})
		palette.Parent = ScaleRootGlobal
		for i, c in ipairs(presets) do
			local cell = New("TextButton", {
				BackgroundColor3 = c,
				Text = "",
				AutoButtonColor = false,
				BorderSizePixel = 0,
				LayoutOrder = i,
				ZIndex = 401,
			}, { New("UICorner", { CornerRadius = UDim.new(0, 5) }) })
			cell.Parent = palette
			cell.MouseButton1Click:Connect(function()
				setColor(c)
				palette:Destroy()
				palette = nil
				paletteOpen = false
			end)
		end
	end)

	holder.Destroying:Connect(function()
		if palette then palette:Destroy() end
	end)

	local obj = setmetatable({ Instance = holder }, Element)
	function obj:Get() return color end
	function obj:Set(c) setColor(c) end
	if opts.Flag then Picon.SetFlag(opts.Flag, color) end
	return obj
end

------------------------------------------------------------
-- ROOT
------------------------------------------------------------
local ScreenGuiCache, ScaleRoot, NotifyContainer, UIScaleInst
ScaleRootGlobal = nil -- for tooltip

local function EnsureRoot()
	if ScreenGuiCache and ScreenGuiCache.Parent then
		return ScreenGuiCache, ScaleRoot
	end
	local screenGui = New("ScreenGui", {
		Name = "PiconUI",
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = Picon.RootDisplayOrder,
		IgnoreGuiInset = true,
	})
	screenGui.Parent = PlayerGui
	local root = New("Frame", {
		Name = "ScaleRoot",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(Picon.BaseResolution.X, Picon.BaseResolution.Y),
		BackgroundTransparency = 1,
	})
	root.Parent = screenGui
	ScaleRootGlobal = root
	UIScaleInst = New("UIScale", { Scale = 1 })
	UIScaleInst.Parent = root

	local function UpdateScale()
		local cam = workspace.CurrentCamera
		if not cam then return end
		local vp = cam.ViewportSize
		if vp.X <= 0 or vp.Y <= 0 then return end
		local s = math.min(vp.X / Picon.BaseResolution.X, vp.Y / Picon.BaseResolution.Y)
		s = math.max(s, Picon.MinScale)
		UIScaleInst.Scale = s
		CurrentUIScale = s
	end
	UpdateScale()
	Camera = workspace.CurrentCamera
	if Camera then
		Camera:GetPropertyChangedSignal("ViewportSize"):Connect(UpdateScale)
	end
	workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
		Camera = workspace.CurrentCamera
		if Camera then
			Camera:GetPropertyChangedSignal("ViewportSize"):Connect(UpdateScale)
			UpdateScale()
		end
	end)

	NotifyContainer = New("Frame", {
		Name = "NotifyContainer",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -20, 0, 20),
		Size = UDim2.fromOffset(320, 520),
		BackgroundTransparency = 1,
		ZIndex = 200,
	}, {
		New("UIListLayout", {
			FillDirection = Enum.FillDirection.Vertical,
			HorizontalAlignment = Enum.HorizontalAlignment.Right,
			VerticalAlignment = Enum.VerticalAlignment.Top,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 10),
		}),
	})
	NotifyContainer.Parent = root
	ScreenGuiCache, ScaleRoot = screenGui, root
	return screenGui, root
end

function EnsureRootExists()
	EnsureRoot()
end

------------------------------------------------------------
-- NOTIFY
------------------------------------------------------------
local MAX_NOTIFIES = 5

function Picon.Notify(opts)
	opts = opts or {}
	EnsureRoot()
	local duration = opts.Duration or 3
	local title = opts.Title or "Уведомление"
	local text = opts.Text or ""
	local color = opts.Color or Picon.Theme.Accent
	local transparency = opts.Transparency
	if transparency == nil then transparency = Picon.WindowTransparency end
	local strokeTarget = math.clamp(transparency * 0.5, 0, 0.4)

	-- Лимит стека
	while #Picon._NotifyStack >= MAX_NOTIFIES do
		local old = table.remove(Picon._NotifyStack, 1)
		if old and old.Parent then old:Destroy() end
	end

	local card = New("Frame", {
		Size = UDim2.fromOffset(300, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = Picon.Theme.Background,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 201,
		ClipsDescendants = true,
	}, {
		New("UICorner", { CornerRadius = UDim.new(0, 10) }),
		New("UIStroke", { Color = Picon.Theme.Stroke, Thickness = 1, Transparency = 1 }),
	})
	card.Parent = NotifyContainer
	table.insert(Picon._NotifyStack, card)

	local inner = New("Frame", {
		Name = "Inner",
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		ZIndex = 202,
	}, {
		New("UIListLayout", {
			FillDirection = Enum.FillDirection.Vertical,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 4),
			HorizontalAlignment = Enum.HorizontalAlignment.Left,
		}),
		New("UIPadding", {
			PaddingTop = UDim.new(0, 12),
			PaddingBottom = UDim.new(0, 12),
			PaddingLeft = UDim.new(0, 16),
			PaddingRight = UDim.new(0, 16),
		}),
	})
	inner.Parent = card

	local bar = New("Frame", {
		Size = UDim2.new(0, 4, 1, 0),
		BackgroundColor3 = color,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 203,
	})
	bar.Parent = card

	local titleLbl = New("TextLabel", {
		Size = UDim2.new(1, 0, 0, 20),
		BackgroundTransparency = 1,
		Text = title,
		TextColor3 = Picon.Theme.Text,
		Font = Picon.Theme.FontBold,
		TextSize = 16,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTransparency = 1,
		LayoutOrder = 1,
		ZIndex = 203,
	})
	titleLbl.Parent = inner

	local textLbl
	if text ~= "" then
		textLbl = New("TextLabel", {
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			Text = text,
			TextColor3 = Picon.Theme.SubText,
			Font = Picon.Theme.Font,
			TextSize = 14,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextWrapped = true,
			TextTransparency = 1,
			LayoutOrder = 2,
			ZIndex = 203,
		})
		textLbl.Parent = inner
	end

	-- Клик = закрыть
	local clickClose = New("TextButton", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Text = "",
		ZIndex = 204,
	})
	clickClose.Parent = card

	local closed = false
	local function closeNotify()
		if closed then return end
		closed = true
		local stroke = card:FindFirstChildOfClass("UIStroke")
		local infoOut = TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		Tween(card, infoOut, { BackgroundTransparency = 1 })
		if stroke then Tween(stroke, infoOut, { Transparency = 1 }) end
		Tween(bar, infoOut, { BackgroundTransparency = 1 })
		Tween(titleLbl, infoOut, { TextTransparency = 1 })
		if textLbl then Tween(textLbl, infoOut, { TextTransparency = 1 }) end
		task.delay(0.25, function()
			for i, n in ipairs(Picon._NotifyStack) do
				if n == card then table.remove(Picon._NotifyStack, i) break end
			end
			card:Destroy()
		end)
	end
	clickClose.MouseButton1Click:Connect(closeNotify)

	local stroke = card:FindFirstChildOfClass("UIStroke")
	local infoIn = TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	Tween(card, infoIn, { BackgroundTransparency = transparency })
	if stroke then Tween(stroke, infoIn, { Transparency = strokeTarget }) end
	Tween(bar, infoIn, { BackgroundTransparency = 0 })
	Tween(titleLbl, infoIn, { TextTransparency = 0 })
	if textLbl then Tween(textLbl, infoIn, { TextTransparency = 0 }) end

	task.delay(duration, closeNotify)
end

------------------------------------------------------------
-- CONFIRM DIALOG
------------------------------------------------------------
function Picon.Confirm(opts)
	opts = opts or {}
	EnsureRoot()
	local title = opts.Title or "Подтверждение"
	local text = opts.Text or "Вы уверены?"
	local yesText = opts.YesText or "Да"
	local noText = opts.NoText or "Нет"

	local overlay = New("Frame", {
		Name = "ConfirmOverlay",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.45,
		ZIndex = 300,
	})
	overlay.Parent = ScaleRoot

	local box = New("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(340, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = Picon.Theme.Background,
		BackgroundTransparency = Picon.WindowTransparency,
		BorderSizePixel = 0,
		ZIndex = 301,
	}, {
		New("UICorner", { CornerRadius = UDim.new(0, 12) }),
		New("UIStroke", { Color = Picon.Theme.Stroke, Thickness = 1 }),
		New("UIPadding", {
			PaddingTop = UDim.new(0, 18),
			PaddingBottom = UDim.new(0, 18),
			PaddingLeft = UDim.new(0, 18),
			PaddingRight = UDim.new(0, 18),
		}),
		New("UIListLayout", {
			FillDirection = Enum.FillDirection.Vertical,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 12),
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
		}),
	})
	box.Parent = overlay

	New("TextLabel", {
		Size = UDim2.new(1, 0, 0, 24),
		BackgroundTransparency = 1,
		Text = title,
		TextColor3 = Picon.Theme.Text,
		Font = Picon.Theme.FontBold,
		TextSize = 18,
		LayoutOrder = 1,
		ZIndex = 302,
	}).Parent = box

	New("TextLabel", {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Text = text,
		TextColor3 = Picon.Theme.SubText,
		Font = Picon.Theme.Font,
		TextSize = 15,
		TextWrapped = true,
		LayoutOrder = 2,
		ZIndex = 302,
	}).Parent = box

	local row = New("Frame", {
		Size = UDim2.new(1, 0, 0, 40),
		BackgroundTransparency = 1,
		LayoutOrder = 3,
		ZIndex = 302,
	}, {
		New("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			Padding = UDim.new(0, 12),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	row.Parent = box

	local function finish(result)
		overlay:Destroy()
		if opts.Callback then opts.Callback(result) end
	end

	local yesBtn = New("TextButton", {
		Size = UDim2.fromOffset(120, 38),
		BackgroundColor3 = Picon.Theme.Accent,
		Text = yesText,
		TextColor3 = Color3.new(1, 1, 1),
		Font = Picon.Theme.FontBold,
		TextSize = 15,
		AutoButtonColor = false,
		BorderSizePixel = 0,
		LayoutOrder = 1,
		ZIndex = 303,
	}, { New("UICorner", { CornerRadius = UDim.new(0, 8) }) })
	yesBtn.Parent = row
	yesBtn.MouseButton1Click:Connect(function() finish(true) end)

	local noBtn = New("TextButton", {
		Size = UDim2.fromOffset(120, 38),
		BackgroundColor3 = Picon.Theme.Tertiary,
		Text = noText,
		TextColor3 = Picon.Theme.Text,
		Font = Picon.Theme.FontBold,
		TextSize = 15,
		AutoButtonColor = false,
		BorderSizePixel = 0,
		LayoutOrder = 2,
		ZIndex = 303,
	}, { New("UICorner", { CornerRadius = UDim.new(0, 8) }) })
	noBtn.Parent = row
	noBtn.MouseButton1Click:Connect(function() finish(false) end)
end

------------------------------------------------------------
-- WINDOW
------------------------------------------------------------
local Window = setmetatable({}, Container)
Window.__index = Window

function Picon.new(opts)
	opts = opts or {}
	local screenGui, root = EnsureRoot()

	local size = opts.Size or Vector2.new(500, 420)
	local position = opts.Position or Vector2.new(
		Picon.BaseResolution.X / 2,
		Picon.BaseResolution.Y / 2
	)
	local winTransparency = opts.Transparency
	if winTransparency == nil then winTransparency = Picon.WindowTransparency end

	local main = New("Frame", {
		Name = opts.Name or "PiconWindow",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(size.X, size.Y),
		Position = UDim2.fromOffset(position.X, position.Y),
		BackgroundColor3 = Picon.Theme.Background,
		BackgroundTransparency = winTransparency,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		Visible = false,
	}, {
		New("UICorner", { CornerRadius = UDim.new(0, 12) }),
		New("UIStroke", { Color = Picon.Theme.Stroke, Thickness = 1 }),
	})
	main.Parent = root

	local winScale = New("UIScale", { Scale = 0.92 })
	winScale.Parent = main

	local titleBar = New("Frame", {
		Name = "TitleBar",
		Size = UDim2.new(1, 0, 0, 42),
		BackgroundColor3 = Picon.Theme.Secondary,
		BackgroundTransparency = winTransparency,
		BorderSizePixel = 0,
	}, { New("UICorner", { CornerRadius = UDim.new(0, 12) }) })
	titleBar.Parent = main
	New("Frame", {
		Size = UDim2.new(1, 0, 0, 14),
		Position = UDim2.new(0, 0, 1, -14),
		BackgroundColor3 = Picon.Theme.Secondary,
		BackgroundTransparency = winTransparency,
		BorderSizePixel = 0,
	}).Parent = titleBar

	local titleLabel = New("TextLabel", {
		Size = UDim2.new(1, -52, 1, 0),
		Position = UDim2.fromOffset(16, 0),
		BackgroundTransparency = 1,
		Text = opts.Title or "Picon Window",
		TextColor3 = Picon.Theme.Text,
		Font = Picon.Theme.FontBold,
		TextSize = 17,
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	titleLabel.Parent = titleBar

	local closeBtn
	if opts.CanClose ~= false then
		closeBtn = New("TextButton", {
			Size = UDim2.fromOffset(30, 30),
			Position = UDim2.new(1, -38, 0.5, -15),
			BackgroundColor3 = Picon.Theme.Background,
			BackgroundTransparency = winTransparency,
			Text = "×",
			TextColor3 = Picon.Theme.SubText,
			Font = Picon.Theme.FontBold,
			TextSize = 22,
			BorderSizePixel = 0,
			AutoButtonColor = false,
		}, { New("UICorner", { CornerRadius = UDim.new(0, 8) }) })
		closeBtn.Parent = titleBar
		closeBtn.MouseEnter:Connect(function()
			Tween(closeBtn, TweenInfo.new(0.12), {
				BackgroundColor3 = Picon.Theme.Error,
				TextColor3 = Color3.new(1, 1, 1),
			})
		end)
		closeBtn.MouseLeave:Connect(function()
			Tween(closeBtn, TweenInfo.new(0.12), {
				BackgroundColor3 = Picon.Theme.Background,
				TextColor3 = Picon.Theme.SubText,
			})
		end)
	end

	-- Search bar (опционально)
	local contentTop = 42
	local searchBox
	if opts.Search then
		searchBox = New("TextBox", {
			Name = "Search",
			Size = UDim2.new(1, -28, 0, 34),
			Position = UDim2.fromOffset(14, 48),
			BackgroundColor3 = Picon.Theme.Tertiary,
			TextColor3 = Picon.Theme.Text,
			PlaceholderText = "Поиск...",
			PlaceholderColor3 = Picon.Theme.SubText,
			Text = "",
			Font = Picon.Theme.Font,
			TextSize = 15,
			ClearTextOnFocus = false,
			BorderSizePixel = 0,
		}, {
			New("UICorner", { CornerRadius = UDim.new(0, 8) }),
			New("UIPadding", { PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12) }),
		})
		searchBox.Parent = main
		contentTop = 90
	end

	-- Tab bar placeholder
	local tabBar
	local tabContents = {}
	local activeTab = nil

	local content = New("ScrollingFrame", {
		Name = "Content",
		Size = UDim2.new(1, 0, 1, -contentTop),
		Position = UDim2.fromOffset(0, contentTop),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 5,
		ScrollBarImageColor3 = Picon.Theme.Stroke,
		CanvasSize = UDim2.new(0, 0, 0, 0),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y,
	})
	content.Parent = main
	if opts.AutoLayout ~= false then
		ApplyAutoLayout(content, opts)
	end

	local dragCleanup
	if opts.Draggable ~= false then
		dragCleanup = MakeDraggable(titleBar, main)
	end

	-- MiniButton
	local miniOpts = opts.MiniButton or {}
	local miniSize = miniOpts.Size or Vector2.new(56, 56)
	local miniPos
	if typeof(miniOpts.Position) == "Vector2" then
		miniPos = miniOpts.Position
	else
		miniPos = MiniPositionFromSide(miniOpts.Position or "Left", miniSize)
	end
	local miniColor = miniOpts.Color or Picon.Theme.Secondary
	local miniBtn = New("TextButton", {
		Name = "PiconMiniButton",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(miniSize.X, miniSize.Y),
		Position = UDim2.fromOffset(miniPos.X, miniPos.Y),
		BackgroundColor3 = miniColor,
		BackgroundTransparency = winTransparency,
		AutoButtonColor = false,
		Text = "",
		BorderSizePixel = 0,
		Visible = false,
	}, {
		New("UICorner", { CornerRadius = miniOpts.CornerRadius or UDim.new(0, 8) }),
	})
	miniBtn.Parent = root
	-- TextSize / IconSize подстраиваются под размер mini-кнопки
	local autoTextSize = math.clamp(math.floor(math.min(miniSize.X, miniSize.Y) * 0.42), 10, 22)
	local autoIcon = math.max(math.floor(math.min(miniSize.X, miniSize.Y) - 12), 12)
	PopulateButtonVisual(miniBtn, {
		Text = miniOpts.Text or ((miniOpts.Icon == nil) and "☰" or nil),
		Icon = miniOpts.Icon,
		IconSize = miniOpts.IconSize or Vector2.new(autoIcon, autoIcon),
		TextSize = miniOpts.TextSize or autoTextSize,
		TextColor = miniOpts.TextColor or Picon.Theme.Text,
		Spacing = miniOpts.Spacing or 4,
	}, miniSize)
	miniBtn.MouseEnter:Connect(function()
		Tween(miniBtn, TweenInfo.new(0.15), {
			BackgroundColor3 = miniColor:Lerp(Picon.Theme.Accent, 0.35),
		})
	end)
	miniBtn.MouseLeave:Connect(function()
		Tween(miniBtn, TweenInfo.new(0.15), { BackgroundColor3 = miniColor })
	end)
	local miniDragCleanup
	if miniOpts.Draggable ~= false then
		miniDragCleanup = MakeDraggable(miniBtn, miniBtn)
	end

	local self = setmetatable({
		Instance = main,
		Content = content,
		TitleBar = titleBar,
		TitleLabel = titleLabel,
		ScreenGui = screenGui,
		MiniButtonInstance = miniBtn,
		IsOpen = false,
		_toggleKey = opts.ToggleKey or Enum.KeyCode.RightShift,
		_connections = {},
		_cleanups = {},
		_winScale = winScale,
		_transparency = winTransparency,
		_tabs = tabContents,
		_searchBox = searchBox,
		_contentTop = contentTop,
	}, Window)

	if dragCleanup then table.insert(self._cleanups, dragCleanup) end
	if miniDragCleanup then table.insert(self._cleanups, miniDragCleanup) end

	-- Поиск: фильтрует детей Content по тексту
	if searchBox then
		searchBox:GetPropertyChangedSignal("Text"):Connect(function()
			local q = string.lower(searchBox.Text)
			for _, child in ipairs(content:GetChildren()) do
				if child:IsA("GuiObject") and not child:IsA("UIListLayout") and not child:IsA("UIPadding") then
					if q == "" then
						child.Visible = true
					else
						local hay = ""
						for _, d in ipairs(child:GetDescendants()) do
							if d:IsA("TextLabel") or d:IsA("TextButton") or d:IsA("TextBox") then
								hay = hay .. " " .. string.lower(d.Text or "")
							end
						end
						if child:IsA("TextLabel") or child:IsA("TextButton") then
							hay = hay .. " " .. string.lower(child.Text or "")
						end
						child.Visible = string.find(hay, q, 1, true) ~= nil
					end
				end
			end
		end)
	end

	function self:Open()
		if self.IsOpen then return end
		self.IsOpen = true
		self.MiniButtonInstance.Visible = false
		self.Instance.Visible = true
		self._winScale.Scale = 0.88
		self.Instance.BackgroundTransparency = 1
		local info = TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
		Tween(self._winScale, info, { Scale = 1 })
		Tween(self.Instance, TweenInfo.new(0.15), {
			BackgroundTransparency = self._transparency,
		})
	end

	function self:Close()
		if not self.IsOpen then return end
		self.IsOpen = false
		self.Instance.Visible = false
		self.MiniButtonInstance.Visible = true
	end

	function self:ToggleState()
		if self.IsOpen then self:Close() else self:Open() end
	end

	function self:SetToggleKey(key)
		if typeof(key) == "EnumItem" then self._toggleKey = key end
	end
	function self:GetToggleKey() return self._toggleKey end

	function self:SetTransparency(t)
		self._transparency = math.clamp(t, 0, 1)
		if self.IsOpen then
			self.Instance.BackgroundTransparency = self._transparency
			self.TitleBar.BackgroundTransparency = self._transparency
		end
		self.MiniButtonInstance.BackgroundTransparency = self._transparency
	end

	function self:SetMiniPosition(side)
		local pos = MiniPositionFromSide(side, miniSize)
		self.MiniButtonInstance.Position = UDim2.fromOffset(pos.X, pos.Y)
	end

	function self:SetSize(w, h)
		self.Instance.Size = UDim2.fromOffset(w, h)
	end

	function self:Center()
		self.Instance.Position = UDim2.fromOffset(
			Picon.BaseResolution.X / 2,
			Picon.BaseResolution.Y / 2
		)
	end

	-- Вкладки
	function self:AddTab(opts)
		opts = opts or {}
		local name = opts.Name or opts.Text or ("Tab" .. tostring(#self._tabs + 1))

		if not tabBar then
			tabBar = New("Frame", {
				Name = "TabBar",
				Size = UDim2.new(1, -28, 0, 36),
				Position = UDim2.fromOffset(14, contentTop),
				BackgroundTransparency = 1,
				ZIndex = 5,
			}, {
				New("UIListLayout", {
					FillDirection = Enum.FillDirection.Horizontal,
					Padding = UDim.new(0, 6),
					SortOrder = Enum.SortOrder.LayoutOrder,
				}),
			})
			tabBar.Parent = main
			contentTop = contentTop + 42
			content.Position = UDim2.fromOffset(0, contentTop)
			content.Size = UDim2.new(1, 0, 1, -contentTop)
			self._contentTop = contentTop
		end

		local page = New("ScrollingFrame", {
			Name = "Tab_" .. name,
			Size = UDim2.new(1, 0, 1, -contentTop),
			Position = UDim2.fromOffset(0, contentTop),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ScrollBarThickness = 5,
			ScrollBarImageColor3 = Picon.Theme.Stroke,
			CanvasSize = UDim2.new(0, 0, 0, 0),
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			ScrollingDirection = Enum.ScrollingDirection.Y,
			Visible = false,
		})
		page.Parent = main
		ApplyAutoLayout(page, opts)

		local tabBtn = New("TextButton", {
			Size = UDim2.fromOffset(0, 34),
			AutomaticSize = Enum.AutomaticSize.X,
			BackgroundColor3 = Picon.Theme.Tertiary,
			Text = "  " .. name .. "  ",
			TextColor3 = Picon.Theme.SubText,
			Font = Picon.Theme.FontBold,
			TextSize = 14,
			AutoButtonColor = false,
			BorderSizePixel = 0,
			LayoutOrder = #self._tabs + 1,
		}, { New("UICorner", { CornerRadius = UDim.new(0, 8) }) })
		tabBtn.Parent = tabBar

		local tabObj = setmetatable({ Instance = page, Content = page, _btn = tabBtn }, Container)
		table.insert(self._tabs, { name = name, page = page, btn = tabBtn, obj = tabObj })

		local function activate()
			for _, t in ipairs(self._tabs) do
				t.page.Visible = false
				t.btn.BackgroundColor3 = Picon.Theme.Tertiary
				t.btn.TextColor3 = Picon.Theme.SubText
			end
			page.Visible = true
			tabBtn.BackgroundColor3 = Picon.Theme.Accent
			tabBtn.TextColor3 = Color3.new(1, 1, 1)
			content.Visible = false -- скрываем основной content
			activeTab = tabObj
		end

		tabBtn.MouseButton1Click:Connect(activate)

		-- Первая вкладка активна
		if #self._tabs == 1 then
			activate()
		end

		return tabObj
	end

	miniBtn.MouseButton1Click:Connect(function() self:Open() end)
	if closeBtn then
		closeBtn.MouseButton1Click:Connect(function() self:Close() end)
	end

	if opts.Keybind ~= false then
		local conn = UserInputService.InputBegan:Connect(function(input, gp)
			if gp then return end
			if Picon._CapturingKeybind then return end
			if UserInputService:GetFocusedTextBox() then return end
			if input.KeyCode == self._toggleKey then
				self:ToggleState()
			end
		end)
		table.insert(self._connections, conn)
	end

	if opts.StartOpen == false then
		self.IsOpen = false
		self.Instance.Visible = false
		self.MiniButtonInstance.Visible = true
	else
		self:Open()
	end

	return self
end

function Window:SetTitle(text)
	self.TitleLabel.Text = text
end

function Window:Destroy()
	for _, c in ipairs(self._connections) do c:Disconnect() end
	for _, f in ipairs(self._cleanups) do f() end
	self.MiniButtonInstance:Destroy()
	self.Instance:Destroy()
end

return Picon
