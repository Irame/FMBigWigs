--------------------------------------------------------------------------------
-- Module Declaration
--

local plugin = BigWigs:NewPlugin("Alt Power")
if not plugin then return end

plugin.defaultDB = {
	posx = nil,
	posy = nil,
	expanded = false,
	disabled = false,
	lock = true,
	width = 230,
	heightExpanded = 210,
	heightContracted = 80,
	font = nil,
	fontSizeExpanded = nil,
	fontSizeContracted = nil,
}

--------------------------------------------------------------------------------
-- Locals
--

local powerList, sortedUnitList, roleColoredList = nil, nil, nil
local unitList = nil
local maxPlayers = 0
local display, updater = nil, nil
local opener = nil
local inTestMode = nil
local inConfigMode = nil
local UpdateDisplay
local tsort = table.sort
local UnitPower = UnitPower
local db = nil
local L = LibStub("AceLocale-3.0"):GetLocale("Big Wigs: Plugins")
plugin.displayName = L.altpower_name
local media = LibStub("LibSharedMedia-3.0")

local roleIcons = {
	["TANK"] = INLINE_TANK_ICON,
	["HEALER"] = INLINE_HEALER_ICON,
	["DAMAGER"] = INLINE_DAMAGER_ICON,
	["NONE"] = "",
}

-------------------------------------------------------------------------------
-- Initialization
--

local function updateProfile()
	db = plugin.db.profile

	if display then
		display:SetSize(db.width, db.expanded and db.heightExpanded or db.heightContracted)

		local x = db.posx
		local y = db.posy
		if x and y then
			local s = display:GetEffectiveScale()
			display:ClearAllPoints()
			display:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x / s, y / s)
		else
			display:ClearAllPoints()
			display:SetPoint("CENTER", UIParent, "CENTER", 300, -80)
		end

		plugin:RestyleWindow()
	end

	if not db.font then
		db.font = media:GetDefault("font")
	end
	if not db.fontSizeExpanded then
		local _, size = GameFontNormal:GetFont()
		db.fontSizeExpanded = size
	end
	if not db.fontSizeContracted then
		local _, size = GameFontNormal:GetFont()
		db.fontSizeContracted = size
	end
end

function plugin:OnRegister()
	BigWigs:RegisterBossOption("altpower", L.altpower, L.altpower_desc, OnOptionToggled, "Interface\\Icons\\Spell_Arcane_ArcaneTorrent")
	self:RegisterMessage("BigWigs_ProfileUpdate", updateProfile)
	updateProfile()
end

function plugin:OnPluginEnable()
	self:RegisterMessage("BigWigs_ShowAltPower")
	self:RegisterMessage("BigWigs_HideAltPower", "Close")
	self:RegisterMessage("BigWigs_OnBossDisable")

	self:RegisterMessage("BigWigs_StartConfigureMode")
	self:RegisterMessage("BigWigs_StopConfigureMode")
	self:RegisterMessage("BigWigs_SetConfigureTarget")

	db = self.db.profile
end

function plugin:OnPluginDisable()
	self:Close()
end

-------------------------------------------------------------------------------
-- Display Window
--

local function setConfigureTarget(self, button)
	if not inConfigMode or button ~= "LeftButton" then return end
	plugin:SendMessage("BigWigs_SetConfigureTarget", plugin)
end

local function onDragStart(self) self:StartMoving() end
local function onDragStop(self)
	self:StopMovingOrSizing()
	local s = self:GetEffectiveScale()
	db.posx = self:GetLeft() * s
	db.posy = self:GetTop() * s
end
local function OnDragHandleMouseDown(self) self.frame:StartSizing("BOTTOMRIGHT") end
local function OnDragHandleMouseUp(self, button) self.frame:StopMovingOrSizing() end
local function onResize(self, width, height)
	db.width = width
	if db.expanded then
		db.heightExpanded = height
	else 
		db.heightContracted = height
	end
	plugin:RestyleWindow()
end

local locked = nil
local function lockDisplay()
	if locked then return end
	display:SetMovable(false)
	display:SetResizable(false)
	display:RegisterForDrag()
	display:SetScript("OnSizeChanged", nil)
	display:SetScript("OnDragStart", nil)
	display:SetScript("OnDragStop", nil)
	display.drag:Hide()
	locked = true
end
local function unlockDisplay()
	if not locked then return end
	display:SetMovable(true)
	display:SetResizable(true)
	display:RegisterForDrag("LeftButton")
	display:SetScript("OnSizeChanged", onResize)
	display:SetScript("OnDragStart", onDragStart)
	display:SetScript("OnDragStop", onDragStop)
	display.drag:Show()
	locked = nil
end

function plugin:RestyleWindow()
	local font = media:Fetch("font", db.font)
	local fontSize = (db.expanded and db.fontSizeExpanded or db.fontSizeContracted)
	local width = db.width/2
	local height = (db.expanded and db.heightExpanded or db.heightContracted) / (db.expanded and 13 or 5)
	for i = 1, 25 do
		local text = display.text[i]
		text:SetFont(font, fontSize)
		text:SetSize(width, height)
		if i == 1 then
			text:SetPoint("TOPLEFT", display, "TOPLEFT", 5, 0)
		elseif i % 2 == 0 then
			text:SetPoint("LEFT", display.text[i-1], "RIGHT")
		else
			text:SetPoint("TOP", display.text[i-2], "BOTTOM")
		end
	end
	if db.lock then
		locked = nil
		lockDisplay()
	else
		locked = true
		unlockDisplay()
	end
end

-------------------------------------------------------------------------------
-- Event Handlers
--

do
	local function createFrame()
		display = CreateFrame("Frame", "BigWigsAltPower", UIParent)
		display:SetSize(db.width, db.expanded and db.heightExpanded or db.heightContracted)
		display:SetClampedToScreen(true)
		display:EnableMouse(true)
		display:SetScript("OnMouseUp", setConfigureTarget)

		updater = display:CreateAnimationGroup()
		updater:SetLooping("REPEAT")
		updater:SetScript("OnLoop", UpdateDisplay)
		local anim = updater:CreateAnimation()
		anim:SetDuration(2)

		local bg = display:CreateTexture(nil, "PARENT")
		bg:SetAllPoints(display)
		bg:SetBlendMode("BLEND")
		bg:SetTexture(0, 0, 0, 0.3)
		display.background = bg

		local close = CreateFrame("Button", nil, display)
		close:SetPoint("BOTTOMRIGHT", display, "TOPRIGHT", -2, 2)
		close:SetHeight(16)
		close:SetWidth(16)
		close:SetNormalTexture("Interface\\AddOns\\BigWigs\\Textures\\icons\\close")
		close:SetScript("OnClick", function()
			--BigWigs:Print(L.toggleProximityPrint)
			plugin:Close()
		end)

		local expand = CreateFrame("Button", nil, display)
		expand:SetPoint("BOTTOMLEFT", display, "TOPLEFT", 2, 2)
		expand:SetHeight(16)
		expand:SetWidth(16)
		expand:SetNormalTexture(db.expanded and "Interface\\AddOns\\BigWigs\\Textures\\icons\\arrows_up" or "Interface\\AddOns\\BigWigs\\Textures\\icons\\arrows_down")
		expand:SetScript("OnClick", function()
			if db.expanded then
				plugin:Contract()
			else
				plugin:Expand()
			end
		end)
		display.expand = expand

		local header = display:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		header:SetPoint("BOTTOM", display, "TOP", 0, 4)
		display.title = header
		
		local drag = CreateFrame("Frame", nil, display)
		drag.frame = display
		drag:SetFrameLevel(display:GetFrameLevel() + 10) -- place this above everything
		drag:SetWidth(16)
		drag:SetHeight(16)
		drag:SetPoint("BOTTOMRIGHT", display, -1, 1)
		drag:EnableMouse(true)
		drag:SetScript("OnMouseDown", OnDragHandleMouseDown)
		drag:SetScript("OnMouseUp", OnDragHandleMouseUp)
		drag:SetAlpha(0.5)
		display.drag = drag
		
		local tex = drag:CreateTexture(nil, "OVERLAY")
		tex:SetTexture("Interface\\AddOns\\BigWigs\\Textures\\draghandle")
		tex:SetWidth(16)
		tex:SetHeight(16)
		tex:SetBlendMode("ADD")
		tex:SetPoint("CENTER", drag)
		
		display.text = {}
		for i = 1, 25 do
			local text = display:CreateFontString(nil, "OVERLAY", "GameFontNormal")
			text:SetText("")
			text:SetJustifyH("LEFT")
			display.text[i] = text
		end
	
		plugin:RestyleWindow()
	
		local x = db.posx
		local y = db.posy
		if x and y then
			local s = display:GetEffectiveScale()
			display:ClearAllPoints()
			display:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x / s, y / s)
		else
			display:ClearAllPoints()
			display:SetPoint("CENTER", UIParent, "CENTER", 300, -80)
		end
	end

	-- This module is rarely used, and opened once during an encounter where it is.
	-- We will prefer on-demand variables over permanent ones.
	function plugin:BigWigs_ShowAltPower(event, module, title)
		if not self:IsInGroup() or db.disabled then return end -- Solo runs of old content
		if createFrame then createFrame() createFrame = nil end
		self:Close()

		maxPlayers = self:GetNumGroupMembers()
		opener = module
		unitList = IsInRaid() and self:GetRaidList() or self:GetPartyList()
		powerList, sortedUnitList, roleColoredList = {}, {}, {}
		local UnitClass, UnitGroupRolesAssigned = UnitClass, UnitGroupRolesAssigned
		local colorTbl = CUSTOM_CLASS_COLORS or RAID_CLASS_COLORS
		for i = 1, maxPlayers do
			local unit = unitList[i]
			sortedUnitList[i] = unit

			local name = self:UnitName(unit, true) or "???"
			local _, class = UnitClass(unit)
			local tbl = class and colorTbl[class] or GRAY_FONT_COLOR
			roleColoredList[unit] = ("%s|cFF%02x%02x%02x%s|r"):format(roleIcons[UnitGroupRolesAssigned(unit)], tbl.r*255, tbl.g*255, tbl.b*255, name)
		end
		if title then
			display.title:SetFormattedText("Alt Power: %s", title)
		else
			display.title:SetText("Alt Power")
		end
		display:Show()
		updater:Play()
		UpdateDisplay()
	end

	function plugin:Test()
		if createFrame then createFrame() createFrame = nil end
		self:Close()

		unitList = self:GetRaidList()
		for i = 1, db.expanded and 25 or 10 do
			display.text[i]:SetFormattedText("[%d] %s", 100-i, unitList[i])
		end
		display.title:SetText("Alt Power")
		display:Show()
		inTestMode = true
	end
end

-------------------------------------------------------------------------------
-- Options
--

function plugin:BigWigs_StartConfigureMode()
	if display and display:IsShown() then
		print("Cannot enter configure mode whilst AltPower is active.")
		return
	end
	inConfigMode = true
	self:Test()
end

function plugin:BigWigs_StopConfigureMode()
	inConfigMode = nil
	self:Close()
end

function plugin:BigWigs_SetConfigureTarget(event, module)
	if module == self then
		display.background:SetTexture(0.2, 1, 0.2, 0.3)
	else
		display.background:SetTexture(0, 0, 0, 0.3)
	end
end

do
	local pluginOptions = nil
	function plugin:GetPluginConfig()
		if not pluginOptions then
			pluginOptions = {
				type = "group",
				get = function(info)
					local key = info[#info]
					if key == "font" then
						for i, v in next, media:List("font") do
							if v == db.font then return i end
						end
					elseif key == "soundName" then
						for i, v in next, media:List("sound") do
							if v == db.soundName then return i end
						end
					else
						return db[key]
					end
				end,
				set = function(info, value)
					local key = info[#info]
					if key == "font" then
						db.font = media:List("font")[value]
					elseif key == "soundName" then
						db.soundName = media:List("sound")[value]
					else
						db[key] = value
					end
					plugin:RestyleWindow()
				end,
				args = {
					disabled = {
						type = "toggle",
						name = L.disabled,
						desc = L.disabledDesc,
						order = 1,
					},
					lock = {
						type = "toggle",
						name = L.lock,
						desc = L.lockDesc,
						order = 2,
					},
					font = {
						type = "select",
						name = L.font,
						order = 4,
						values = media:List("font"),
						width = "full",
						itemControl = "DDI-Font",
					},
					fontSizeContracted = {
						type = "range",
						name = L.fontSizeContracted,
						order = 5,
						max = 40,
						min = 8,
						step = 1,
						width = "full",
					},
					fontSizeExpanded = {
						type = "range",
						name = L.fontSizeExpanded,
						order = 6,
						max = 40,
						min = 8,
						step = 1,
						width = "full",
					},
				}
			}
		end
		return pluginOptions
	end
end

-------------------------------------------------------------------------------
-- AltPower Updater
--

do
	local function sortTbl(x,y)
		local px, py = powerList[x], powerList[y]
		if px == py then
			return x > y
		else
			return px > py
		end
	end

	function UpdateDisplay()
		for i = 1, maxPlayers do
			local unit = unitList[i]
			powerList[unit] = UnitPower(unit, 10) -- ALTERNATE_POWER_INDEX = 10
		end
		tsort(sortedUnitList, sortTbl)
		for i = 1, db.expanded and 25 or 10 do
			local name = sortedUnitList[i]
			if not name then return end
			display.text[i]:SetFormattedText("[%d] %s", powerList[name], roleColoredList[name])
		end
	end
end

function plugin:Expand()
	db.expanded = true
	display:SetHeight(db.heightExpanded)
	display.expand:SetNormalTexture("Interface\\AddOns\\BigWigs\\Textures\\icons\\arrows_up")
	if inTestMode then
		self:Test()
	end
	plugin:RestyleWindow()
end

function plugin:Contract()
	db.expanded = false
	display:SetHeight(db.heightContracted)
	display.expand:SetNormalTexture("Interface\\AddOns\\BigWigs\\Textures\\icons\\arrows_down")
	for i = 11, 25 do
		display.text[i]:SetText("")
	end
	plugin:RestyleWindow()
end

function plugin:Close()
	if not updater then return end
	updater:Stop()
	display:Hide()
	powerList, sortedUnitList, roleColoredList = nil, nil, nil
	unitList = nil
	opener = nil
	inTestMode = nil
	for i = 1, 25 do
		display.text[i]:SetText("")
	end
end

function plugin:BigWigs_OnBossDisable(_, module)
	if module == opener then
		self:Close()
	end
end

