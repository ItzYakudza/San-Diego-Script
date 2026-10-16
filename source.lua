--[[
	Picon UI Library  v2.7.0  (Neverlose-style)
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
	 • Мини-кнопка: drag не открывает GUI (порог 4px)
	 • Плоский тёмный стиль в духе Neverlose
 • rbxasset / rbxassetid иконки в сайдбаре и кнопках
 • Стили кнопок: primary / secondary / ghost / danger
 • Нотификации справа снизу
 • Анимация смены вкладок
]]

local Picon = {}
Picon.__index = Picon
Picon.Version = "2.7.0"

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

-- Neverlose-inspired flat dark theme
Picon.Theme = {
	Background = Color3.fromRGB(14, 14, 16),
	Secondary  = Color3.fromRGB(20, 20, 24),
	Tertiary   = Color3.fromRGB(28, 28, 34),
	Accent     = Color3.fromRGB(47, 128, 237),   -- Neverlose blue
	Success    = Color3.fromRGB(52, 199, 89),
	Warning    = Color3.fromRGB(255, 159, 10),
	Error      = Color3.fromRGB(255, 69, 58),
	Text       = Color3.fromRGB(240, 240, 245),
	SubText    = Color3.fromRGB(175, 175, 185),
	Stroke     = Color3.fromRGB(42, 42, 50),
	Font       = Enum.Font.GothamMedium,
	FontBold   = Enum.Font.GothamBold,
}

Picon._Windows = {} -- live theme targets

Picon.Themes = {
	Default = {
		Background = Color3.fromRGB(14, 14, 16),
		Secondary  = Color3.fromRGB(20, 20, 24),
		Tertiary   = Color3.fromRGB(28, 28, 34),
		Accent     = Color3.fromRGB(47, 128, 237),
		Success    = Color3.fromRGB(52, 199, 89),
		Warning    = Color3.fromRGB(255, 159, 10),
		Error      = Color3.fromRGB(255, 69, 58),
		Text       = Color3.fromRGB(240, 240, 245),
		SubText    = Color3.fromRGB(175, 175, 185),
		Stroke     = Color3.fromRGB(42, 42, 50),
	},
	Midnight = {
		Background = Color3.fromRGB(10, 10, 14),
		Secondary  = Color3.fromRGB(16, 16, 22),
		Tertiary   = Color3.fromRGB(24, 24, 32),
		Accent     = Color3.fromRGB(47, 128, 237),
		Success    = Color3.fromRGB(52, 199, 89),
		Warning    = Color3.fromRGB(255, 159, 10),
		Error      = Color3.fromRGB(255, 69, 58),
		Text       = Color3.fromRGB(240, 240, 245),
		SubText    = Color3.fromRGB(170, 170, 185),
		Stroke     = Color3.fromRGB(38, 38, 48),
	},
	Ocean = {
		Background = Color3.fromRGB(12, 16, 22),
		Secondary  = Color3.fromRGB(18, 24, 32),
		Tertiary   = Color3.fromRGB(26, 34, 44),
		Accent     = Color3.fromRGB(14, 165, 233),
		Success    = Color3.fromRGB(34, 197, 94),
		Warning    = Color3.fromRGB(234, 179, 8),
		Error      = Color3.fromRGB(239, 68, 68),
		Text       = Color3.fromRGB(230, 236, 242),
		SubText    = Color3.fromRGB(140, 155, 170),
		Stroke     = Color3.fromRGB(36, 46, 58),
	},
	Rose = {
		Background = Color3.fromRGB(18, 12, 16),
		Secondary  = Color3.fromRGB(26, 18, 22),
		Tertiary   = Color3.fromRGB(36, 26, 32),
		Accent     = Color3.fromRGB(244, 63, 94),
		Success    = Color3.fromRGB(74, 222, 128),
		Warning    = Color3.fromRGB(251, 146, 60),
		Error      = Color3.fromRGB(239, 68, 68),
		Text       = Color3.fromRGB(245, 235, 240),
		SubText    = Color3.fromRGB(170, 150, 160),
		Stroke     = Color3.fromRGB(48, 34, 42),
	},
}

local function ApplyThemeToInstance(root)
	if not root then return end
	for _, d in ipairs(root:GetDescendants()) do
		local role = d:GetAttribute("PiconRole")
		if not role then
			-- fallthrough heuristics
		elseif role == "Background" and d:IsA("GuiObject") then
			d.BackgroundColor3 = Picon.Theme.Background
		elseif role == "Secondary" and d:IsA("GuiObject") then
			d.BackgroundColor3 = Picon.Theme.Secondary
		elseif role == "Tertiary" and d:IsA("GuiObject") then
			d.BackgroundColor3 = Picon.Theme.Tertiary
		elseif role == "Accent" and d:IsA("GuiObject") then
			d.BackgroundColor3 = Picon.Theme.Accent
		elseif role == "Stroke" and d:IsA("UIStroke") then
			d.Color = Picon.Theme.Stroke
		elseif role == "Text" and (d:IsA("TextLabel") or d:IsA("TextButton") or d:IsA("TextBox")) then
			d.TextColor3 = Picon.Theme.Text
		elseif role == "SubText" and (d:IsA("TextLabel") or d:IsA("TextButton") or d:IsA("TextBox")) then
			d.TextColor3 = Picon.Theme.SubText
		elseif role == "Icon" and d:IsA("ImageLabel") then
			d.ImageColor3 = Picon.Theme.SubText
		elseif role == "IconActive" and d:IsA("ImageLabel") then
			d.ImageColor3 = Picon.Theme.Accent
		end
	end
end

function Picon.SetTheme(nameOrTable)
	local th = typeof(nameOrTable) == "table" and nameOrTable or Picon.Themes[nameOrTable]
	if not th then return end
	for k, v in pairs(th) do
		Picon.Theme[k] = v
	end
	-- live apply to open windows + notifies
	for i = #Picon._Windows, 1, -1 do
		local w = Picon._Windows[i]
		if w and w.Instance and w.Instance.Parent then
			ApplyThemeToInstance(w.Instance)
			if w.MiniButtonInstance then ApplyThemeToInstance(w.MiniButtonInstance) end
			if w._applyThemeExtra then pcall(w._applyThemeExtra) end
		else
			table.remove(Picon._Windows, i)
		end
	end
	if NotifyContainer then ApplyThemeToInstance(NotifyContainer) end
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

-- returns cleanup, and a function that tells if the last interaction was a real drag
local function MakeDraggable(handle, target)
	local dragging = false
	local didDrag = false
	local dragStart, startPos
	local conns = {}
	local DRAG_THRESHOLD = 4 -- px before we consider it a drag (suppresses click)

	table.insert(conns, handle.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			didDrag = false
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
		if not didDrag and (math.abs(delta.X) > DRAG_THRESHOLD or math.abs(delta.Y) > DRAG_THRESHOLD) then
			didDrag = true
		end
		if didDrag then
			target.Position = UDim2.new(
				startPos.X.Scale, startPos.X.Offset + delta.X,
				startPos.Y.Scale, startPos.Y.Offset + delta.Y
			)
		end
	end))

	local function cleanup()
		for _, c in ipairs(conns) do c:Disconnect() end
	end

	-- true if the most recent press was dragged past the threshold
	local function wasDragged()
		return didDrag
	end

	return cleanup, wasDragged
end

local function ApplyAutoLayout(content, opts)
	opts = opts or {}
	New("UIListLayout", {
		FillDirection = opts.FillDirection or Enum.FillDirection.Vertical,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, opts.Spacing or 6),
		HorizontalAlignment = opts.HorizontalAlignment or Enum.HorizontalAlignment.Left,
		VerticalAlignment = opts.VerticalAlignment or Enum.VerticalAlignment.Top,
	}).Parent = content
	New("UIPadding", {
		PaddingLeft   = UDim.new(0, opts.Padding or 12),
		PaddingRight  = UDim.new(0, opts.Padding or 12),
		PaddingTop    = UDim.new(0, opts.Padding or 10),
		PaddingBottom = UDim.new(0, opts.Padding or 10),
	}).Parent = content
end

local function IsRbxImage(s)
	if typeof(s) ~= "string" or s == "" then return false end
	return string.find(s, "rbxasset", 1, true) ~= nil
		or string.find(s, "http", 1, true) ~= nil
		or string.match(s, "^%d+$") ~= nil
end

local function NormalizeImage(s)
	if typeof(s) ~= "string" then return s end
	if string.match(s, "^%d+$") then
		return "rbxassetid://" .. s
	end
	return s
end

local function PopulateButtonVisual(btn, opts, size)
	local hasIcon = opts.Icon and opts.Icon ~= ""
	local hasText = opts.Text and opts.Text ~= ""
	local spacing = opts.Spacing or 6
	local iconTint = opts.IconColor or opts.TextColor or Color3.new(1, 1, 1)
	local textSize = opts.TextSize or 14

	if hasIcon and hasText and IsRbxImage(opts.Icon) then
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
		local iconSize = opts.IconSize or Vector2.new(math.max(size.Y - 14, 14), math.max(size.Y - 14, 14))
		New("ImageLabel", {
			Name = "Icon",
			Size = UDim2.fromOffset(iconSize.X, iconSize.Y),
			BackgroundTransparency = 1,
			Image = NormalizeImage(opts.Icon),
			ImageColor3 = iconTint,
			LayoutOrder = 1,
		}).Parent = inner
		New("TextLabel", {
			Name = "TextLabel",
			Size = UDim2.fromOffset(math.max(size.X - iconSize.X - spacing * 3, 12), size.Y),
			BackgroundTransparency = 1,
			Text = opts.Text,
			TextColor3 = opts.TextColor or Color3.new(1, 1, 1),
			Font = Picon.Theme.FontBold,
			TextSize = textSize,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Center,
			LayoutOrder = 2,
		}).Parent = inner
	elseif hasIcon and IsRbxImage(opts.Icon) then
		New("ImageLabel", {
			Name = "Icon",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(
				opts.IconSize and opts.IconSize.X or (size.Y - 14),
				opts.IconSize and opts.IconSize.Y or (size.Y - 14)
			),
			BackgroundTransparency = 1,
			Image = NormalizeImage(opts.Icon),
			ImageColor3 = iconTint,
		}).Parent = btn
	elseif hasText then
		btn.Text = opts.Text
		btn.TextColor3 = opts.TextColor or Color3.new(1, 1, 1)
		btn.Font = Picon.Theme.FontBold
		btn.TextSize = textSize
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
		New("UICorner", { CornerRadius = UDim.new(0, opts.CornerRadius or 4) }),
		New("UIStroke", { Color = Picon.Theme.Stroke, Thickness = 1 }),
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
		TextSize = opts.TextSize or 14,
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
		TextSize = opts.TextSize or 13,
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
	local size = opts.Size or Vector2.new(180, 32)
	local pos = opts.Position or Vector2.new(0, 0)
	-- Style: Primary (accent), Secondary (tertiary), Ghost (transparent+stroke), Danger (error muted)
	local style = string.lower(tostring(opts.Style or "primary"))
	local color
	if opts.Color then
		color = opts.Color
	elseif style == "secondary" then
		color = Picon.Theme.Tertiary
	elseif style == "ghost" then
		color = Picon.Theme.Secondary
	elseif style == "danger" then
		color = Picon.Theme.Error:Lerp(Picon.Theme.Background, 0.35)
	else
		color = Picon.Theme.Accent
	end
	local textColor = opts.TextColor
	if not textColor then
		if style == "secondary" or style == "ghost" then
			textColor = Picon.Theme.Text
		else
			textColor = Color3.fromRGB(255, 255, 255)
		end
	end
	local children = {
		New("UICorner", { CornerRadius = UDim.new(0, opts.CornerRadius or 4) }),
	}
	if style == "ghost" or style == "secondary" then
		table.insert(children, New("UIStroke", { Color = Picon.Theme.Stroke, Thickness = 1 }))
	end
	local btn = New("TextButton", {
		Name = opts.Name or "Button",
		Size = opts.FillWidth and UDim2.new(1, 0, 0, size.Y) or UDim2.fromOffset(size.X, size.Y),
		Position = UDim2.fromOffset(pos.X, pos.Y),
		BackgroundColor3 = color,
		BackgroundTransparency = (style == "ghost") and 0.4 or 0,
		AutoButtonColor = false,
		Text = "",
		BorderSizePixel = 0,
		LayoutOrder = opts.LayoutOrder or 0,
	}, children)
	btn.Parent = self.Content or self.Instance
	local visOpts = {}
	for k, v in pairs(opts) do visOpts[k] = v end
	visOpts.TextColor = textColor
	PopulateButtonVisual(btn, visOpts, size)
	AttachTooltip(btn, opts.Tooltip)
	local baseTrans = btn.BackgroundTransparency
	btn.MouseEnter:Connect(function()
		Tween(btn, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			BackgroundColor3 = color:Lerp(Color3.new(1, 1, 1), 0.1),
			BackgroundTransparency = math.max(0, baseTrans - 0.15),
		})
	end)
	btn.MouseLeave:Connect(function()
		Tween(btn, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			BackgroundColor3 = color,
			BackgroundTransparency = baseTrans,
		})
	end)
	btn.MouseButton1Down:Connect(function()
		Tween(btn, TweenInfo.new(0.06), { BackgroundTransparency = math.min(0.35, baseTrans + 0.1) })
	end)
	btn.MouseButton1Up:Connect(function()
		Tween(btn, TweenInfo.new(0.08), { BackgroundTransparency = baseTrans })
	end)
	if opts.Callback then
		btn.MouseButton1Click:Connect(opts.Callback)
	end
	local obj = setmetatable({ Instance = btn }, Element)
	function obj:SetText(txt)
		if btn:FindFirstChild("TextLabel") then
			btn.TextLabel.Text = txt
		else
			btn.Text = txt
		end
	end
	function obj:SetColor(c)
		color = c
		btn.BackgroundColor3 = c
	end
	return obj
end

function Container:AddTextBox(opts)
	opts = opts or {}
	local size = opts.Size or Vector2.new(200, 32)
	local pos = opts.Position or Vector2.new(0, 0)
	local box = New("TextBox", {
		Name = opts.Name or "TextBox",
		Size = opts.FillWidth and UDim2.new(1, 0, 0, size.Y) or UDim2.fromOffset(size.X, size.Y),
		Position = UDim2.fromOffset(pos.X, pos.Y),
		BackgroundColor3 = Picon.Theme.Tertiary,
		TextColor3 = Picon.Theme.Text,
		PlaceholderText = opts.Placeholder or "",
		PlaceholderColor3 = Picon.Theme.SubText,
		Text = opts.Default or (opts.Flag and Picon.GetFlag(opts.Flag, "") or ""),
		Font = Picon.Theme.Font,
		TextSize = opts.TextSize or 14,
		ClearTextOnFocus = false,
		BorderSizePixel = 0,
		LayoutOrder = opts.LayoutOrder or 0,
	}, {
		New("UICorner", { CornerRadius = UDim.new(0, 4) }),
		New("UIStroke", { Color = Picon.Theme.Stroke, Thickness = 1 }),
		New("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10) }),
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
	local size = opts.Size or Vector2.new(220, 28)
	local pos = opts.Position or Vector2.new(0, 0)
	local state = opts.Default
	if opts.Flag and Picon.GetFlag(opts.Flag) ~= nil then
		state = Picon.GetFlag(opts.Flag)
	end
	state = state == true

	local holder = New("Frame", {
		Name = opts.Name or "Toggle",
		Size = opts.FillWidth and UDim2.new(1, 0, 0, 28) or UDim2.fromOffset(size.X, 28),
		Position = UDim2.fromOffset(pos.X, pos.Y),
		BackgroundTransparency = 1,
		LayoutOrder = opts.LayoutOrder or 0,
	})
	holder.Parent = self.Content or self.Instance
	New("TextLabel", {
		Size = UDim2.new(1, -48, 1, 0),
		BackgroundTransparency = 1,
		Text = opts.Text or "Toggle",
		TextColor3 = Picon.Theme.Text,
		Font = Picon.Theme.FontBold,
		TextSize = opts.TextSize or 13,
		TextXAlignment = Enum.TextXAlignment.Left,
	}).Parent = holder
	-- Neverlose-style compact pill toggle
	local track = New("Frame", {
		Size = UDim2.fromOffset(36, 18),
		Position = UDim2.new(1, -36, 0.5, -9),
		BackgroundColor3 = state and Picon.Theme.Accent or Picon.Theme.Tertiary,
		BorderSizePixel = 0,
	}, { New("UICorner", { CornerRadius = UDim.new(1, 0) }) })
	track.Parent = holder
	local knob = New("Frame", {
		Size = UDim2.fromOffset(14, 14),
		Position = state and UDim2.new(1, -16, 0.5, -7) or UDim2.new(0, 2, 0.5, -7),
		BackgroundColor3 = Color3.fromRGB(245, 245, 250),
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
		Tween(track, TweenInfo.new(0.12), {
			BackgroundColor3 = state and Picon.Theme.Accent or Picon.Theme.Tertiary,
		})
		Tween(knob, TweenInfo.new(0.12), {
			Position = state and UDim2.new(1, -16, 0.5, -7) or UDim2.new(0, 2, 0.5, -7),
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

-- Two-column row helper inside a tab/container
function Container:AddColumns(opts)
	opts = opts or {}
	local gap = opts.Gap or 12
	local row = New("Frame", {
		Name = "Columns",
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		LayoutOrder = opts.LayoutOrder or 0,
	})
	row.Parent = self.Content or self.Instance
	New("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, gap),
		HorizontalAlignment = Enum.HorizontalAlignment.Left,
		VerticalAlignment = Enum.VerticalAlignment.Top,
	}).Parent = row

	local cols = {}
	local n = opts.Count or 2
	for i = 1, n do
		local col = New("Frame", {
			Name = "Col" .. i,
			Size = UDim2.new(1 / n, -math.floor(gap * (n - 1) / n), 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			LayoutOrder = i,
		})
		col.Parent = row
		ApplyAutoLayout(col, { Padding = 0, Spacing = opts.Spacing or 6 })
		cols[i] = setmetatable({ Instance = col, Content = col }, Container)
	end
	return cols
end


function Container:AddSection(opts)
	opts = opts or {}
	local collapsed = opts.Collapsed == true
	local collapsible = opts.Collapsible == true

	local holder = New("Frame", {
		Name = "Section",
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		LayoutOrder = opts.LayoutOrder or 0,
		ClipsDescendants = false,
	})
	holder.Parent = self.Content or self.Instance

	local header = New("TextButton", {
		Size = UDim2.new(1, 0, 0, 30),
		BackgroundColor3 = collapsible and Picon.Theme.Secondary or Color3.new(0, 0, 0),
		BackgroundTransparency = collapsible and 0 or 1,
		Text = "",
		AutoButtonColor = false,
		BorderSizePixel = 0,
	}, {
		New("UICorner", { CornerRadius = UDim.new(0, 4) }),
	})
	header.Parent = holder
	if collapsible then header:SetAttribute("PiconRole", "Secondary") end

	local arrow = New("TextLabel", {
		Size = UDim2.fromOffset(22, 30),
		Position = UDim2.new(1, -26, 0, 0),
		BackgroundTransparency = 1,
		Text = collapsible and (collapsed and "+" or "−") or "",
		TextColor3 = Picon.Theme.SubText,
		Font = Picon.Theme.FontBold,
		TextSize = 16,
		TextXAlignment = Enum.TextXAlignment.Center,
		ZIndex = 2,
	})
	arrow.Parent = header
	arrow:SetAttribute("PiconRole", "SubText")

	local title = New("TextLabel", {
		Size = UDim2.new(1, collapsible and -32 or 0, 1, 0),
		Position = UDim2.fromOffset(10, 0),
		BackgroundTransparency = 1,
		Text = opts.Text or "Section",
		TextColor3 = opts.Color or Picon.Theme.Text,
		Font = Picon.Theme.FontBold,
		TextSize = opts.TextSize or 13,
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	title.Parent = header
	title:SetAttribute("PiconRole", "Text")

	if opts.Divider ~= false and not collapsible then
		New("Frame", {
			Size = UDim2.new(1, -4, 0, 1),
			Position = UDim2.new(0, 2, 1, -1),
			BackgroundColor3 = Picon.Theme.Stroke,
			BorderSizePixel = 0,
			BackgroundTransparency = 0.25,
		}).Parent = header
	end

	local body
	local sectionContainer
	if collapsible then
		body = New("Frame", {
			Name = "Body",
			Size = UDim2.new(1, 0, 0, 0),
			Position = UDim2.fromOffset(0, 34),
			BackgroundColor3 = Picon.Theme.Background,
			BackgroundTransparency = 0.35,
			AutomaticSize = Enum.AutomaticSize.Y,
			Visible = not collapsed,
			BorderSizePixel = 0,
		}, {
			New("UICorner", { CornerRadius = UDim.new(0, 4) }),
			New("UIStroke", { Color = Picon.Theme.Stroke, Thickness = 1 }),
		})
		body.Parent = holder
		body:SetAttribute("PiconRole", "Background")
		ApplyAutoLayout(body, { Padding = 8, Spacing = 6 })
		sectionContainer = setmetatable({ Instance = body, Content = body }, Container)

		header.MouseEnter:Connect(function()
			Tween(header, TweenInfo.new(0.12), { BackgroundColor3 = Picon.Theme.Tertiary })
		end)
		header.MouseLeave:Connect(function()
			Tween(header, TweenInfo.new(0.12), { BackgroundColor3 = Picon.Theme.Secondary })
		end)
		header.MouseButton1Click:Connect(function()
			collapsed = not collapsed
			body.Visible = not collapsed
			arrow.Text = collapsed and "+" or "−"
		end)
	end

	local obj = setmetatable({
		Instance = holder,
		Content = body or (self.Content or self.Instance),
		_body = body,
	}, collapsible and Container or Element)

	function obj:SetText(tx)
		title.Text = tx
	end
	function obj:SetCollapsed(v)
		if not collapsible then return end
		collapsed = not not v
		body.Visible = not collapsed
		arrow.Text = collapsed and "+" or "−"
	end

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
	local size = opts.Size or Vector2.new(220, 40)
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
		Size = UDim2.new(1, -52, 0, 18),
		BackgroundTransparency = 1,
		Text = opts.Text or "Slider",
		TextColor3 = Picon.Theme.Text,
		Font = Picon.Theme.FontBold,
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Left,
	}).Parent = holder
	local valueLabel = New("TextLabel", {
		Size = UDim2.new(0, 48, 0, 18),
		Position = UDim2.new(1, -48, 0, 0),
		BackgroundTransparency = 1,
		Text = string.format("%." .. decimals .. "f", value),
		TextColor3 = Picon.Theme.SubText,
		Font = Picon.Theme.FontBold,
		TextSize = 12,
		TextXAlignment = Enum.TextXAlignment.Right,
	})
	valueLabel.Parent = holder
	-- thin Neverlose-style track
	local track = New("Frame", {
		Size = UDim2.new(1, 0, 0, 4),
		Position = UDim2.new(0, 0, 0, 26),
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
		Size = UDim2.fromOffset(12, 12),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new((value - minV) / math.max(maxV - minV, 1e-6), 0, 0.5, 0),
		BackgroundColor3 = Color3.fromRGB(245, 245, 250),
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
	local size = opts.Size or Vector2.new(220, 36)
	local pos = opts.Position or Vector2.new(0, 0)
	local open = false
	local outsideConn

	local holder = New("Frame", {
		Name = opts.Name or "Dropdown",
		Size = opts.FillWidth and UDim2.new(1, 0, 0, size.Y + 18) or UDim2.fromOffset(size.X, size.Y + 18),
		Position = UDim2.fromOffset(pos.X, pos.Y),
		BackgroundTransparency = 1,
		LayoutOrder = opts.LayoutOrder or 0,
	})
	holder.Parent = self.Content or self.Instance

	New("TextLabel", {
		Size = UDim2.new(1, 0, 0, 16),
		BackgroundTransparency = 1,
		Text = opts.Text or "Dropdown",
		TextColor3 = Picon.Theme.Text,
		Font = Picon.Theme.FontBold,
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Left,
	}).Parent = holder

	local btn = New("TextButton", {
		Size = UDim2.new(1, 0, 0, size.Y - 4),
		Position = UDim2.fromOffset(0, 18),
		BackgroundColor3 = Picon.Theme.Tertiary,
		Text = "",
		AutoButtonColor = false,
		BorderSizePixel = 0,
	}, {
		New("UICorner", { CornerRadius = UDim.new(0, 4) }),
		New("UIStroke", { Color = Picon.Theme.Stroke, Thickness = 1 }),
	})
	btn.Parent = holder
	btn:SetAttribute("PiconRole", "Tertiary")

	local valueLbl = New("TextLabel", {
		Size = UDim2.new(1, -28, 1, 0),
		Position = UDim2.fromOffset(10, 0),
		BackgroundTransparency = 1,
		Text = tostring(current),
		TextColor3 = Picon.Theme.Text,
		Font = Picon.Theme.Font,
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
	})
	valueLbl.Parent = btn
	valueLbl:SetAttribute("PiconRole", "Text")

	local arrow = New("TextLabel", {
		Size = UDim2.fromOffset(20, size.Y - 4),
		Position = UDim2.new(1, -24, 0, 0),
		BackgroundTransparency = 1,
		Text = "▾",
		TextColor3 = Picon.Theme.SubText,
		Font = Picon.Theme.FontBold,
		TextSize = 12,
	})
	arrow.Parent = btn
	arrow:SetAttribute("PiconRole", "SubText")
	AttachTooltip(holder, opts.Tooltip)

	local listFrame
	local function closeList()
		open = false
		arrow.Text = "▾"
		if listFrame then
			Tween(listFrame, TweenInfo.new(0.1), { BackgroundTransparency = 1 })
			task.delay(0.1, function()
				if listFrame then listFrame:Destroy(); listFrame = nil end
			end)
		end
		if outsideConn then outsideConn:Disconnect(); outsideConn = nil end
	end

	local function pick(opt)
		current = opt
		valueLbl.Text = tostring(opt)
		if opts.Flag then Picon.SetFlag(opts.Flag, current) end
		if opts.Callback then opts.Callback(current) end
		closeList()
	end

	local function openList()
		if open then closeList(); return end
		EnsureRootExists()
		local scale = math.max(CurrentUIScale, 0.01)
		local maxH = math.min(180, #options * 30 + 8)
		listFrame = New("ScrollingFrame", {
			Name = "PiconDropdownList",
			Size = UDim2.fromOffset(btn.AbsoluteSize.X / scale, 0),
			BackgroundColor3 = Picon.Theme.Secondary,
			BackgroundTransparency = 0,
			BorderSizePixel = 0,
			ScrollBarThickness = 3,
			ScrollBarImageColor3 = Picon.Theme.Stroke,
			CanvasSize = UDim2.new(0, 0, 0, #options * 30 + 8),
			ZIndex = 400,
			ClipsDescendants = true,
		}, {
			New("UICorner", { CornerRadius = UDim.new(0, 4) }),
			New("UIStroke", { Color = Picon.Theme.Accent, Thickness = 1 }),
			New("UIPadding", { PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 4) }),
			New("UIListLayout", {
				FillDirection = Enum.FillDirection.Vertical,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, 2),
			}),
		})
		listFrame.Parent = ScaleRootGlobal
		listFrame:SetAttribute("PiconRole", "Secondary")

		local abs = btn.AbsolutePosition
		local asz = btn.AbsoluteSize
		local rootPos = ScaleRootGlobal.AbsolutePosition
		local x = (abs.X - rootPos.X) / scale
		local y = (abs.Y + asz.Y - rootPos.Y) / scale + 4
		listFrame.Position = UDim2.fromOffset(x, y)
		Tween(listFrame, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Size = UDim2.fromOffset(asz.X / scale, maxH),
		})
		arrow.Text = "▴"
		open = true

		for i, opt in ipairs(options) do
			local selected = opt == current
			local item = New("TextButton", {
				Size = UDim2.new(1, -8, 0, 28),
				BackgroundColor3 = selected and Picon.Theme.Accent or Picon.Theme.Tertiary,
				BackgroundTransparency = selected and 0.15 or 1,
				Text = "  " .. tostring(opt),
				TextColor3 = selected and Color3.new(1, 1, 1) or Picon.Theme.Text,
				Font = selected and Picon.Theme.FontBold or Picon.Theme.Font,
				TextSize = 13,
				TextXAlignment = Enum.TextXAlignment.Left,
				AutoButtonColor = false,
				BorderSizePixel = 0,
				LayoutOrder = i,
				ZIndex = 401,
			}, { New("UICorner", { CornerRadius = UDim.new(0, 3) }) })
			item.Parent = listFrame
			item.MouseEnter:Connect(function()
				if opt ~= current then
					Tween(item, TweenInfo.new(0.08), { BackgroundTransparency = 0.4, BackgroundColor3 = Picon.Theme.Tertiary })
				end
			end)
			item.MouseLeave:Connect(function()
				if opt ~= current then
					Tween(item, TweenInfo.new(0.08), { BackgroundTransparency = 1 })
				end
			end)
			item.MouseButton1Click:Connect(function() pick(opt) end)
		end

		outsideConn = UserInputService.InputBegan:Connect(function(input)
			if not open then return end
			if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then return end
			local p = input.Position
			local lp, ls = listFrame.AbsolutePosition, listFrame.AbsoluteSize
			local bp, bs = btn.AbsolutePosition, btn.AbsoluteSize
			local inList = p.X >= lp.X and p.X <= lp.X + ls.X and p.Y >= lp.Y and p.Y <= lp.Y + ls.Y
			local inBtn = p.X >= bp.X and p.X <= bp.X + bs.X and p.Y >= bp.Y and p.Y <= bp.Y + bs.Y
			if not inList and not inBtn then closeList() end
		end)
	end

	btn.MouseButton1Click:Connect(openList)
	holder.Destroying:Connect(function()
		if outsideConn then outsideConn:Disconnect() end
		if listFrame then listFrame:Destroy() end
	end)

	local obj = setmetatable({ Instance = holder }, Element)
	function obj:Set(v) pick(v) end
	function obj:Get() return current end
	function obj:SetOptions(list)
		options = list or {}
	end
	function obj:Close() closeList() end
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
	local h, s, v = Color3.toHSV(color)

	local holder = New("Frame", {
		Name = opts.Name or "ColorPicker",
		Size = UDim2.new(1, 0, 0, 28),
		BackgroundTransparency = 1,
		LayoutOrder = opts.LayoutOrder or 0,
	})
	holder.Parent = self.Content or self.Instance

	New("TextLabel", {
		Size = UDim2.new(1, -40, 1, 0),
		BackgroundTransparency = 1,
		Text = opts.Text or "Color",
		TextColor3 = Picon.Theme.Text,
		Font = Picon.Theme.FontBold,
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Left,
	}).Parent = holder

	local swatch = New("TextButton", {
		Size = UDim2.fromOffset(28, 20),
		Position = UDim2.new(1, -28, 0.5, -10),
		BackgroundColor3 = color,
		Text = "",
		AutoButtonColor = false,
		BorderSizePixel = 0,
	}, {
		New("UICorner", { CornerRadius = UDim.new(0, 4) }),
		New("UIStroke", { Color = Picon.Theme.Stroke, Thickness = 1 }),
	})
	swatch.Parent = holder

	local palette, open = nil, false
	local function setColor(c, fire)
		color = c
		h, s, v = Color3.toHSV(c)
		swatch.BackgroundColor3 = c
		if opts.Flag then Picon.SetFlag(opts.Flag, c) end
		if fire and opts.Callback then opts.Callback(c) end
	end

	local function closePalette()
		open = false
		if palette then palette:Destroy(); palette = nil end
	end

	local function openPalette()
		if open then closePalette(); return end
		EnsureRootExists()
		open = true
		local scale = math.max(CurrentUIScale, 0.01)
		palette = New("Frame", {
			Name = "PiconColorPalette",
			Size = UDim2.fromOffset(220, 180),
			BackgroundColor3 = Picon.Theme.Secondary,
			BorderSizePixel = 0,
			ZIndex = 450,
		}, {
			New("UICorner", { CornerRadius = UDim.new(0, 6) }),
			New("UIStroke", { Color = Picon.Theme.Stroke, Thickness = 1 }),
			New("UIPadding", {
				PaddingTop = UDim.new(0, 10), PaddingBottom = UDim.new(0, 10),
				PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10),
			}),
		})
		palette.Parent = ScaleRootGlobal
		local abs = swatch.AbsolutePosition
		local rootPos = ScaleRootGlobal.AbsolutePosition
		palette.Position = UDim2.fromOffset(
			math.clamp((abs.X - rootPos.X) / scale - 180, 8, Picon.BaseResolution.X - 230),
			math.clamp((abs.Y - rootPos.Y) / scale + 28, 8, Picon.BaseResolution.Y - 190)
		)

		-- SV square
		local sv = New("ImageButton", {
			Size = UDim2.fromOffset(140, 120),
			BackgroundColor3 = Color3.fromHSV(h, 1, 1),
			BorderSizePixel = 0,
			AutoButtonColor = false,
			ZIndex = 451,
		}, { New("UICorner", { CornerRadius = UDim.new(0, 4) }) })
		sv.Parent = palette
		-- white/black overlays via frames
		local white = New("Frame", {
			Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1,1,1), BorderSizePixel = 0, ZIndex = 452,
		}, {
			New("UIGradient", {
				Transparency = NumberSequence.new({
					NumberSequenceKeypoint.new(0, 0),
					NumberSequenceKeypoint.new(1, 1),
				}),
			}),
			New("UICorner", { CornerRadius = UDim.new(0, 4) }),
		})
		white.Parent = sv
		local black = New("Frame", {
			Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0,0,0), BorderSizePixel = 0, ZIndex = 453,
		}, {
			New("UIGradient", {
				Rotation = 90,
				Transparency = NumberSequence.new({
					NumberSequenceKeypoint.new(0, 1),
					NumberSequenceKeypoint.new(1, 0),
				}),
			}),
			New("UICorner", { CornerRadius = UDim.new(0, 4) }),
		})
		black.Parent = sv
		local cursor = New("Frame", {
			Size = UDim2.fromOffset(10, 10),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(s, 1 - v),
			BackgroundColor3 = Color3.new(1, 1, 1),
			BorderSizePixel = 0,
			ZIndex = 454,
		}, {
			New("UICorner", { CornerRadius = UDim.new(1, 0) }),
			New("UIStroke", { Color = Color3.new(0, 0, 0), Thickness = 1 }),
		})
		cursor.Parent = sv

		local function applySV(inputPos)
			local ap, asz = sv.AbsolutePosition, sv.AbsoluteSize
			local nx = math.clamp((inputPos.X - ap.X) / math.max(asz.X, 1), 0, 1)
			local ny = math.clamp((inputPos.Y - ap.Y) / math.max(asz.Y, 1), 0, 1)
			s, v = nx, 1 - ny
			cursor.Position = UDim2.fromScale(s, 1 - v)
			setColor(Color3.fromHSV(h, s, v), true)
		end
		sv.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				applySV(input.Position)
				local move, up
				move = UserInputService.InputChanged:Connect(function(inp)
					if inp.UserInputType == Enum.UserInputType.MouseMovement or inp.UserInputType == Enum.UserInputType.Touch then
						applySV(inp.Position)
					end
				end)
				up = UserInputService.InputEnded:Connect(function(inp)
					if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
						if move then move:Disconnect() end
						if up then up:Disconnect() end
					end
				end)
			end
		end)

		-- Hue bar
		local hueBar = New("Frame", {
			Size = UDim2.fromOffset(18, 120),
			Position = UDim2.fromOffset(152, 0),
			BackgroundColor3 = Color3.new(1, 1, 1),
			BorderSizePixel = 0,
			ZIndex = 451,
		}, {
			New("UICorner", { CornerRadius = UDim.new(0, 4) }),
			New("UIGradient", {
				Rotation = 90,
				Color = ColorSequence.new({
					ColorSequenceKeypoint.new(0, Color3.fromHSV(0, 1, 1)),
					ColorSequenceKeypoint.new(0.17, Color3.fromHSV(0.17, 1, 1)),
					ColorSequenceKeypoint.new(0.33, Color3.fromHSV(0.33, 1, 1)),
					ColorSequenceKeypoint.new(0.5, Color3.fromHSV(0.5, 1, 1)),
					ColorSequenceKeypoint.new(0.67, Color3.fromHSV(0.67, 1, 1)),
					ColorSequenceKeypoint.new(0.83, Color3.fromHSV(0.83, 1, 1)),
					ColorSequenceKeypoint.new(1, Color3.fromHSV(1, 1, 1)),
				}),
			}),
		})
		hueBar.Parent = palette
		local hueCursor = New("Frame", {
			Size = UDim2.new(1, 4, 0, 4),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, 0, h, 0),
			BackgroundColor3 = Color3.new(1, 1, 1),
			BorderSizePixel = 0,
			ZIndex = 452,
		}, { New("UICorner", { CornerRadius = UDim.new(1, 0) }) })
		hueCursor.Parent = hueBar

		local function applyHue(inputPos)
			local ap, asz = hueBar.AbsolutePosition, hueBar.AbsoluteSize
			h = math.clamp((inputPos.Y - ap.Y) / math.max(asz.Y, 1), 0, 1)
			hueCursor.Position = UDim2.new(0.5, 0, h, 0)
			sv.BackgroundColor3 = Color3.fromHSV(h, 1, 1)
			setColor(Color3.fromHSV(h, s, v), true)
		end
		hueBar.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				applyHue(input.Position)
				local move, up
				move = UserInputService.InputChanged:Connect(function(inp)
					if inp.UserInputType == Enum.UserInputType.MouseMovement or inp.UserInputType == Enum.UserInputType.Touch then
						applyHue(inp.Position)
					end
				end)
				up = UserInputService.InputEnded:Connect(function(inp)
					if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
						if move then move:Disconnect() end
						if up then up:Disconnect() end
					end
				end)
			end
		end)

		-- preview + close
		local prev = New("Frame", {
			Size = UDim2.fromOffset(40, 40),
			Position = UDim2.fromOffset(180, 0),
			BackgroundColor3 = color,
			BorderSizePixel = 0,
			ZIndex = 451,
		}, { New("UICorner", { CornerRadius = UDim.new(0, 4) }) })
		prev.Parent = palette
		swatch:GetPropertyChangedSignal("BackgroundColor3"):Connect(function()
			if prev.Parent then prev.BackgroundColor3 = swatch.BackgroundColor3 end
		end)

		local closeBtn = New("TextButton", {
			Size = UDim2.fromOffset(40, 24),
			Position = UDim2.fromOffset(180, 96),
			BackgroundColor3 = Picon.Theme.Tertiary,
			Text = "OK",
			TextColor3 = Picon.Theme.Text,
			Font = Picon.Theme.FontBold,
			TextSize = 12,
			AutoButtonColor = false,
			BorderSizePixel = 0,
			ZIndex = 451,
		}, { New("UICorner", { CornerRadius = UDim.new(0, 4) }) })
		closeBtn.Parent = palette
		closeBtn.MouseButton1Click:Connect(closePalette)
	end

	swatch.MouseButton1Click:Connect(openPalette)
	holder.Destroying:Connect(closePalette)

	local obj = setmetatable({ Instance = holder }, Element)
	function obj:Get() return color end
	function obj:Set(c) setColor(c, false) end
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
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -8, 1, -8),
		Size = UDim2.fromOffset(300, 520),
		BackgroundTransparency = 1,
		ZIndex = 200,
	}, {
		New("UIListLayout", {
			FillDirection = Enum.FillDirection.Vertical,
			HorizontalAlignment = Enum.HorizontalAlignment.Right,
			VerticalAlignment = Enum.VerticalAlignment.Bottom,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 8),
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
	if transparency == nil then
		transparency = math.clamp(Picon.WindowTransparency or 0, 0, 0.85)
	end
	local strokeTarget = math.clamp(transparency * 0.55, 0, 0.5)

	-- Лимит стека
	while #Picon._NotifyStack >= MAX_NOTIFIES do
		local old = table.remove(Picon._NotifyStack, 1)
		if old and old.Parent then old:Destroy() end
	end

	local card = New("Frame", {
		Size = UDim2.fromOffset(280, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = Picon.Theme.Secondary,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 201,
		ClipsDescendants = true,
	}, {
		New("UICorner", { CornerRadius = UDim.new(0, 6) }),
		New("UIStroke", { Color = Picon.Theme.Stroke, Thickness = 1, Transparency = 1 }),
	})
	card:SetAttribute("PiconRole", "Secondary")
	local cardStroke = card:FindFirstChildOfClass("UIStroke")
	if cardStroke then cardStroke:SetAttribute("PiconRole", "Stroke") end
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
	local screenGui, root = EnsureRoot()
	local title = opts.Title or "Подтверждение"
	local text = opts.Text or "Вы уверены?"
	local yesText = opts.YesText or "Да"
	local noText = opts.NoText or "Нет"

	-- Full-screen overlay on ScreenGui (IgnoreGuiInset already true) so it covers the whole viewport
	local overlay = New("Frame", {
		Name = "ConfirmOverlay",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.45,
		ZIndex = 300,
		BorderSizePixel = 0,
	})
	overlay.Parent = screenGui

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
		New("UICorner", { CornerRadius = UDim.new(0, 6) }),
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
	}, { New("UICorner", { CornerRadius = UDim.new(0, 4) }) })
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
	}, { New("UICorner", { CornerRadius = UDim.new(0, 4) }) })
	noBtn.Parent = row
	noBtn.MouseButton1Click:Connect(function() finish(false) end)
end

------------------------------------------------------------
-- WINDOW  (Neverlose-style: left sidebar + content)
------------------------------------------------------------
local Window = setmetatable({}, Container)
Window.__index = Window

local SIDEBAR_W = 168
local TOPBAR_H = 44

function Picon.new(opts)
	opts = opts or {}
	local screenGui, root = EnsureRoot()

	local size = opts.Size or Vector2.new(780, 480)
	local position = opts.Position or Vector2.new(
		Picon.BaseResolution.X / 2,
		Picon.BaseResolution.Y / 2
	)
	local winTransparency = opts.Transparency
	if winTransparency == nil then winTransparency = Picon.WindowTransparency end
	local sidebarW = opts.SidebarWidth or SIDEBAR_W

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
		New("UICorner", { CornerRadius = UDim.new(0, 6) }),
		New("UIStroke", { Color = Picon.Theme.Stroke, Thickness = 1 }),
	})
	main.Parent = root
	main:SetAttribute("PiconRole", "Background")

	local winScale = New("UIScale", { Scale = 0.96 })
	winScale.Parent = main

	-- ===== LEFT SIDEBAR =====
	local sidebar = New("Frame", {
		Name = "Sidebar",
		Size = UDim2.new(0, sidebarW, 1, 0),
		BackgroundColor3 = Picon.Theme.Secondary,
		BackgroundTransparency = winTransparency,
		BorderSizePixel = 0,
		ZIndex = 2,
	})
	sidebar.Parent = main
	sidebar:SetAttribute("PiconRole", "Secondary")
	New("Frame", {
		Size = UDim2.new(0, 1, 1, 0),
		Position = UDim2.new(1, -1, 0, 0),
		BackgroundColor3 = Picon.Theme.Stroke,
		BorderSizePixel = 0,
		ZIndex = 3,
	}).Parent = sidebar

	-- Brand / title in sidebar
	local brand = New("Frame", {
		Size = UDim2.new(1, 0, 0, 52),
		BackgroundTransparency = 1,
		ZIndex = 3,
	})
	brand.Parent = sidebar
	local titleLabel = New("TextLabel", {
		Name = "TitleLabel",
		Size = UDim2.new(1, -16, 1, 0),
		Position = UDim2.fromOffset(14, 0),
		BackgroundTransparency = 1,
		Text = opts.Title or "Picon",
		TextColor3 = Picon.Theme.Text,
		Font = Picon.Theme.FontBold,
		TextSize = 16,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		ZIndex = 4,
	})
	titleLabel.Parent = brand
	New("Frame", {
		Size = UDim2.new(1, -24, 0, 1),
		Position = UDim2.new(0, 12, 1, -1),
		BackgroundColor3 = Picon.Theme.Stroke,
		BorderSizePixel = 0,
		ZIndex = 4,
	}).Parent = brand

	-- Nav list (scrollable)
	local navScroll = New("ScrollingFrame", {
		Name = "Nav",
		Size = UDim2.new(1, 0, 1, -52 - 78),
		Position = UDim2.fromOffset(0, 52),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 3,
		ScrollBarImageColor3 = Picon.Theme.Stroke,
		CanvasSize = UDim2.new(0, 0, 0, 0),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		ZIndex = 3,
	})
	navScroll.Parent = sidebar
	New("UIListLayout", {
		FillDirection = Enum.FillDirection.Vertical,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 2),
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
	}).Parent = navScroll
	New("UIPadding", {
		PaddingTop = UDim.new(0, 8),
		PaddingBottom = UDim.new(0, 10),
		PaddingLeft = UDim.new(0, 8),
		PaddingRight = UDim.new(0, 8),
	}).Parent = navScroll

	-- User card (bottom of sidebar)
	local userCard = New("Frame", {
		Name = "UserCard",
		Size = UDim2.new(1, -12, 0, 64),
		Position = UDim2.new(0, 6, 1, -72),
		BackgroundColor3 = Picon.Theme.Tertiary,
		BorderSizePixel = 0,
		ZIndex = 4,
	}, {
		New("UICorner", { CornerRadius = UDim.new(0, 6) }),
		New("UIStroke", { Color = Picon.Theme.Stroke, Thickness = 1 }),
	})
	userCard.Parent = sidebar
	userCard:SetAttribute("PiconRole", "Tertiary")

	local avatar = New("ImageLabel", {
		Name = "Avatar",
		Size = UDim2.fromOffset(36, 36),
		Position = UDim2.new(0, 10, 0.5, -18),
		BackgroundColor3 = Picon.Theme.Secondary,
		BorderSizePixel = 0,
		Image = "",
		ZIndex = 5,
	}, { New("UICorner", { CornerRadius = UDim.new(1, 0) }) })
	avatar.Parent = userCard

	-- async headshot
	task.spawn(function()
		local ok, content = pcall(function()
			return Players:GetUserThumbnailAsync(
				LocalPlayer.UserId,
				Enum.ThumbnailType.HeadShot,
				Enum.ThumbnailSize.Size48x48
			)
		end)
		if ok and content then avatar.Image = content end
	end)

	local userNameLbl = New("TextLabel", {
		Name = "UserName",
		Size = UDim2.new(1, -56, 0, 18),
		Position = UDim2.fromOffset(52, 12),
		BackgroundTransparency = 1,
		Text = LocalPlayer.DisplayName or LocalPlayer.Name,
		TextColor3 = Picon.Theme.Text,
		Font = Picon.Theme.FontBold,
		TextSize = 12,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		ZIndex = 5,
	})
	userNameLbl.Parent = userCard
	userNameLbl:SetAttribute("PiconRole", "Text")

	local uptimeLbl = New("TextLabel", {
		Name = "Uptime",
		Size = UDim2.new(1, -56, 0, 16),
		Position = UDim2.fromOffset(52, 32),
		BackgroundTransparency = 1,
		Text = "00:00:00",
		TextColor3 = Picon.Theme.SubText,
		Font = Picon.Theme.Font,
		TextSize = 11,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 5,
	})
	uptimeLbl.Parent = userCard
	uptimeLbl:SetAttribute("PiconRole", "SubText")

	local scriptStart = os.clock()
	task.spawn(function()
		while userCard.Parent do
			local sec = math.floor(os.clock() - scriptStart)
			local h = math.floor(sec / 3600)
			local m = math.floor((sec % 3600) / 60)
			local s = sec % 60
			uptimeLbl.Text = string.format("%02d:%02d:%02d", h, m, s)
			task.wait(1)
		end
	end)

	-- ===== RIGHT: TOP BAR + CONTENT =====
	local right = New("Frame", {
		Name = "Right",
		Size = UDim2.new(1, -sidebarW, 1, 0),
		Position = UDim2.fromOffset(sidebarW, 0),
		BackgroundTransparency = 1,
		ZIndex = 2,
	})
	right.Parent = main

	local titleBar = New("Frame", {
		Name = "TitleBar",
		Size = UDim2.new(1, 0, 0, TOPBAR_H),
		BackgroundColor3 = Picon.Theme.Background,
		BackgroundTransparency = winTransparency,
		BorderSizePixel = 0,
		ZIndex = 5,
	})
	titleBar.Parent = right
	New("Frame", {
		Size = UDim2.new(1, 0, 0, 1),
		Position = UDim2.new(0, 0, 1, -1),
		BackgroundColor3 = Picon.Theme.Stroke,
		BorderSizePixel = 0,
		ZIndex = 6,
	}).Parent = titleBar

	local pageTitle = New("TextLabel", {
		Name = "PageTitle",
		Size = UDim2.new(1, -120, 1, 0),
		Position = UDim2.fromOffset(16, 0),
		BackgroundTransparency = 1,
		Text = "",
		TextColor3 = Picon.Theme.Text,
		Font = Picon.Theme.FontBold,
		TextSize = 15,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 6,
	})
	pageTitle.Parent = titleBar

	-- optional search in top bar (with icon)
	local searchBox
	if opts.Search then
		local searchHolder = New("Frame", {
			Name = "SearchHolder",
			Size = UDim2.fromOffset(180, 28),
			Position = UDim2.new(1, -230, 0.5, -14),
			BackgroundColor3 = Picon.Theme.Tertiary,
			BorderSizePixel = 0,
			ZIndex = 6,
		}, {
			New("UICorner", { CornerRadius = UDim.new(0, 4) }),
			New("UIStroke", { Color = Picon.Theme.Stroke, Thickness = 1 }),
		})
		searchHolder.Parent = titleBar
		-- Roblox search glyph / engine texture fallback
		New("ImageLabel", {
			Name = "SearchIcon",
			Size = UDim2.fromOffset(14, 14),
			Position = UDim2.new(0, 8, 0.5, -7),
			BackgroundTransparency = 1,
			Image = "rbxassetid://140277344408608",
			ImageColor3 = Picon.Theme.SubText,
			ZIndex = 7,
		}).Parent = searchHolder
		searchBox = New("TextBox", {
			Name = "Search",
			Size = UDim2.new(1, -30, 1, 0),
			Position = UDim2.fromOffset(26, 0),
			BackgroundTransparency = 1,
			TextColor3 = Picon.Theme.Text,
			PlaceholderText = "Search...",
			PlaceholderColor3 = Picon.Theme.SubText,
			Text = "",
			Font = Picon.Theme.Font,
			TextSize = 13,
			ClearTextOnFocus = false,
			BorderSizePixel = 0,
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 7,
		})
		searchBox.Parent = searchHolder
		searchBox.Focused:Connect(function()
			local stroke = searchHolder:FindFirstChildOfClass("UIStroke")
			if stroke then Tween(stroke, TweenInfo.new(0.12), { Color = Picon.Theme.Accent }) end
		end)
		searchBox.FocusLost:Connect(function()
			local stroke = searchHolder:FindFirstChildOfClass("UIStroke")
			if stroke then Tween(stroke, TweenInfo.new(0.12), { Color = Picon.Theme.Stroke }) end
		end)
	end

	local closeBtn
	if opts.CanClose ~= false then
		closeBtn = New("TextButton", {
			Size = UDim2.fromOffset(28, 28),
			Position = UDim2.new(1, -36, 0.5, -14),
			BackgroundTransparency = 1,
			Text = "×",
			TextColor3 = Picon.Theme.SubText,
			Font = Picon.Theme.FontBold,
			TextSize = 20,
			BorderSizePixel = 0,
			AutoButtonColor = false,
			ZIndex = 7,
		}, { New("UICorner", { CornerRadius = UDim.new(0, 4) }) })
		closeBtn.Parent = titleBar
		closeBtn.MouseEnter:Connect(function()
			Tween(closeBtn, TweenInfo.new(0.1), {
				BackgroundTransparency = 0,
				BackgroundColor3 = Picon.Theme.Error,
				TextColor3 = Color3.new(1, 1, 1),
			})
		end)
		closeBtn.MouseLeave:Connect(function()
			Tween(closeBtn, TweenInfo.new(0.1), {
				BackgroundTransparency = 1,
				TextColor3 = Picon.Theme.SubText,
			})
		end)
	end

	-- Pages host
	local pagesHost = New("Frame", {
		Name = "Pages",
		Size = UDim2.new(1, 0, 1, -TOPBAR_H),
		Position = UDim2.fromOffset(0, TOPBAR_H),
		BackgroundTransparency = 1,
		ZIndex = 2,
	})
	pagesHost.Parent = right

	-- Default content page (when no tabs yet / fallback)
	local content = New("ScrollingFrame", {
		Name = "Content",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 4,
		ScrollBarImageColor3 = Picon.Theme.Stroke,
		CanvasSize = UDim2.new(0, 0, 0, 0),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		Visible = true,
		ZIndex = 2,
	})
	content.Parent = pagesHost
	if opts.AutoLayout ~= false then
		ApplyAutoLayout(content, opts)
	end

	local dragCleanup
	local brandDragCleanup
	if opts.Draggable ~= false then
		-- drag from sidebar brand + top bar
		dragCleanup = MakeDraggable(titleBar, main)
		brandDragCleanup = MakeDraggable(brand, main)
	end

	-- MiniButton
	local miniOpts = opts.MiniButton or {}
	local miniSize = miniOpts.Size or Vector2.new(48, 48)
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
		New("UICorner", { CornerRadius = miniOpts.CornerRadius or UDim.new(0, 6) }),
		New("UIStroke", { Color = Picon.Theme.Stroke, Thickness = 1 }),
	})
	miniBtn.Parent = root
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
		Tween(miniBtn, TweenInfo.new(0.12), {
			BackgroundColor3 = miniColor:Lerp(Picon.Theme.Accent, 0.25),
		})
	end)
	miniBtn.MouseLeave:Connect(function()
		Tween(miniBtn, TweenInfo.new(0.12), { BackgroundColor3 = miniColor })
	end)
	local miniDragCleanup, miniWasDragged
	if miniOpts.Draggable ~= false then
		miniDragCleanup, miniWasDragged = MakeDraggable(miniBtn, miniBtn)
	end

	local tabContents = {}
	local activeTab = nil

	local self = setmetatable({
		Instance = main,
		Content = content,
		TitleBar = titleBar,
		TitleLabel = titleLabel,
		PageTitle = pageTitle,
		Sidebar = sidebar,
		NavScroll = navScroll,
		PagesHost = pagesHost,
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
		_sidebarW = sidebarW,
	}, Window)

	if dragCleanup then table.insert(self._cleanups, dragCleanup) end
	if brandDragCleanup then table.insert(self._cleanups, brandDragCleanup) end
	if miniDragCleanup then table.insert(self._cleanups, miniDragCleanup) end

	table.insert(Picon._Windows, self)
	self.UserCard = userCard
	self.UserNameLabel = userNameLbl
	self.UptimeLabel = uptimeLbl
	self.UserAvatar = avatar
	self._showUserName = true

	function self:SetUserNameVisible(v)
		self._showUserName = not not v
		userNameLbl.Visible = self._showUserName
	end
	function self:GetUserNameVisible()
		return self._showUserName
	end

	-- Search filters active page children
	if searchBox then
		searchBox:GetPropertyChangedSignal("Text"):Connect(function()
			local q = string.lower(searchBox.Text)
			local page = activeTab and activeTab.Content or content
			for _, child in ipairs(page:GetChildren()) do
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
		self._winScale.Scale = 0.96
		self.Instance.BackgroundTransparency = 1
		local info = TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		Tween(self._winScale, info, { Scale = 1 })
		Tween(self.Instance, TweenInfo.new(0.12), {
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

	function self:SetTransparency(tr)
		self._transparency = math.clamp(tr, 0, 1)
		Picon.WindowTransparency = self._transparency
		if self.IsOpen then
			self.Instance.BackgroundTransparency = self._transparency
			sidebar.BackgroundTransparency = self._transparency
			titleBar.BackgroundTransparency = self._transparency
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

	-- Sidebar group label (non-clickable section header in nav)
	function self:AddNavGroup(opts)
		opts = opts or {}
		local lbl = New("TextLabel", {
			Size = UDim2.new(1, 0, 0, 22),
			BackgroundTransparency = 1,
			Text = string.upper(opts.Text or opts.Name or ""),
			TextColor3 = Picon.Theme.SubText,
			Font = Picon.Theme.FontBold,
			TextSize = 11,
			TextXAlignment = Enum.TextXAlignment.Left,
			LayoutOrder = opts.LayoutOrder or (#self._tabs * 10),
			ZIndex = 4,
		}, {
			New("UIPadding", { PaddingLeft = UDim.new(0, 6) }),
		})
		lbl.Parent = navScroll
		return lbl
	end

	-- Вкладки → пункты сайдбара
	function self:AddTab(opts)
		opts = opts or {}
		local name = opts.Name or opts.Text or ("Tab" .. tostring(#self._tabs + 1))
		local icon = opts.Icon

		local page = New("ScrollingFrame", {
			Name = "Tab_" .. name,
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ScrollBarThickness = 4,
			ScrollBarImageColor3 = Picon.Theme.Stroke,
			CanvasSize = UDim2.new(0, 0, 0, 0),
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			ScrollingDirection = Enum.ScrollingDirection.Y,
			Visible = false,
			ZIndex = 2,
		})
		page.Parent = pagesHost
		ApplyAutoLayout(page, opts)

		local pageScale = New("UIScale", { Scale = 1 })
		pageScale.Parent = page

		-- Sidebar nav button
		local tabBtn = New("TextButton", {
			Name = "Nav_" .. name,
			Size = UDim2.new(1, 0, 0, 34),
			BackgroundColor3 = Picon.Theme.Tertiary,
			BackgroundTransparency = 1,
			Text = "",
			AutoButtonColor = false,
			BorderSizePixel = 0,
			LayoutOrder = opts.LayoutOrder or (#self._tabs + 1) * 10,
			ZIndex = 4,
		}, { New("UICorner", { CornerRadius = UDim.new(0, 5) }) })
		tabBtn.Parent = navScroll

		local accentBar = New("Frame", {
			Name = "Accent",
			Size = UDim2.new(0, 3, 0, 18),
			Position = UDim2.new(0, 0, 0.5, -9),
			BackgroundColor3 = Picon.Theme.Accent,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ZIndex = 5,
		}, { New("UICorner", { CornerRadius = UDim.new(1, 0) }) })
		accentBar.Parent = tabBtn

		local hasRbxIcon = typeof(icon) == "string" and icon ~= "" and IsRbxImage(icon)
		local labelPad = hasRbxIcon and 36 or 12

		local navIcon
		if hasRbxIcon then
			navIcon = New("ImageLabel", {
				Name = "NavIcon",
				Size = UDim2.fromOffset(16, 16),
				Position = UDim2.new(0, 12, 0.5, -8),
				BackgroundTransparency = 1,
				Image = NormalizeImage(icon),
				ImageColor3 = Picon.Theme.SubText,
				ZIndex = 5,
			})
			navIcon.Parent = tabBtn
		end

		local navLabel = New("TextLabel", {
			Name = "NavLabel",
			Size = UDim2.new(1, -(labelPad + 8), 1, 0),
			Position = UDim2.fromOffset(labelPad, 0),
			BackgroundTransparency = 1,
			Text = name,
			TextColor3 = Picon.Theme.SubText,
			Font = Picon.Theme.Font,
			TextSize = 13,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
			ZIndex = 5,
		})
		navLabel.Parent = tabBtn

		local tabObj = setmetatable({ Instance = page, Content = page, _btn = tabBtn, _name = name, _pageScale = pageScale }, Container)
		table.insert(self._tabs, {
			name = name,
			page = page,
			btn = tabBtn,
			obj = tabObj,
			accent = accentBar,
			label = navLabel,
			icon = navIcon,
			pageScale = pageScale,
		})

		local function activate()
			for _, t in ipairs(self._tabs) do
				t.page.Visible = false
				t.btn.BackgroundTransparency = 1
				t.accent.BackgroundTransparency = 1
				t.label.TextColor3 = Picon.Theme.SubText
				t.label.Font = Picon.Theme.Font
				if t.icon then
					t.icon.ImageColor3 = Picon.Theme.SubText
				end
			end
			page.Visible = true
			content.Visible = false
			tabBtn.BackgroundTransparency = 0
			tabBtn.BackgroundColor3 = Picon.Theme.Tertiary
			accentBar.BackgroundTransparency = 0
			navLabel.TextColor3 = Picon.Theme.Text
			navLabel.Font = Picon.Theme.FontBold
			if navIcon then
				navIcon.ImageColor3 = Picon.Theme.Accent
			end
			pageTitle.Text = name
			activeTab = tabObj
			page.CanvasPosition = Vector2.new(0, 0)
			-- re-apply search filter to new page
			if searchBox and searchBox.Text ~= "" then
				local q = string.lower(searchBox.Text)
				for _, child in ipairs(page:GetChildren()) do
					if child:IsA("GuiObject") and not child:IsA("UIListLayout") and not child:IsA("UIPadding") then
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
		end

		tabBtn.MouseEnter:Connect(function()
			if activeTab ~= tabObj then
				Tween(tabBtn, TweenInfo.new(0.12), { BackgroundTransparency = 0.55 })
				tabBtn.BackgroundColor3 = Picon.Theme.Tertiary
			end
		end)
		tabBtn.MouseLeave:Connect(function()
			if activeTab ~= tabObj then
				Tween(tabBtn, TweenInfo.new(0.12), { BackgroundTransparency = 1 })
			end
		end)
		tabBtn.MouseButton1Click:Connect(activate)

		if #self._tabs == 1 then
			activate()
		end

		return tabObj
	end

	miniBtn.MouseButton1Click:Connect(function()
		if miniWasDragged and miniWasDragged() then
			return
		end
		self:Open()
	end)
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
