--------------------------------------------------------------------------------
-- Module Declaration
--

local plugin = BigWigs:NewPlugin("Boss Bars")
if not plugin then return end

plugin.defaultDB = {
	posx = nil,
	posy = nil,
	width = 230,
	height = 210,
	spacing = 5,
	texture = "BantoBar",
	lock = false,
	
	heightRatios = {
		healthBar = 3,
		castBar = 1,
		powerBar = 1
	},
	barOptions = {}
	
}

--------------------------------------------------------------------------------
-- Locals
--
local rnd, floor, log10 = math.random, math.floor, math.log10
local createFrame
local display, updater = nil, nil
local inTestMode = nil
local inConfigMode = nil
local UpdateDisplay
local L = LibStub("AceLocale-3.0"):GetLocale("Big Wigs: Plugins")
plugin.displayName = "BossBars"
local media = LibStub("LibSharedMedia-3.0")


local makeReadableNumber
do
	local suffix = {
		[1] = "k",
		[2] = "m",
	}
	
	function makeReadableNumber(num, acc)
		acc = acc and math.max(acc, 3) or 3
		local numLength = floor(log10(num))+1
		local suffixValue = floor((numLength-1)/3)
		local fmt = "%"..(numLength-suffixValue*3).."."..(acc-(numLength-suffixValue*3)).."f%s"
		if numLength > acc then
			num = floor(num/10^(numLength-acc)+0.5)*10^(numLength-acc)
		end
		return string.format(fmt, num/10^(3*suffixValue), suffix[suffixValue] or "")
	end
end

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
	BigWigs:RegisterBossOption("bossbars", L.bossbars, L.bossbars_desc, OnOptionToggled, "Interface\\Icons\\Spell_Arcane_ArcaneTorrent")
	self:RegisterMessage("BigWigs_ProfileUpdate", updateProfile)
	updateProfile()
end

function plugin:OnPluginEnable()
	if createFrame then createFrame(); createFrame = nil end
	if not media:Fetch("statusbar", db.texture, true) then db.texture = "BantoBar" end

	self:RegisterMessage("BigWigs_ShowBossBars")
	self:RegisterMessage("BigWigs_HideBossBars", "Close")
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

local function updateBarHeights()
	local hr = db.heightRatios
	local barOptionsUser = db.barOptions
	local barOptionsModule = moduleBarOptions
	local sum, effectiveHeight, helthBarHeight, castBarHeight, powerBarHeight
	for bossNum, bossTable in pairs(display.boss) do
		local bouBoss = barOptionsUser[bossNum]
		local bomBoss = barOptionsModule[bossNum]
		if bouBoss.bossFrame and bomBoss.bossFrame then
			helthBarHeight = hr.healthBar
			castBarHeight = ((bouBoss.castBar and bomBoss.castBar) and hr.castBar or 0)
			powerBarHeight = ((bouBoss.powerBar and bomBoss.powerBar) and hr.powerBar or 0)
			
			sum = hr.healthBar + castBarHeight + powerBarHeight
			effectiveHeight = (db.height - db.spacing*(#display.boss-1))/(#display.boss*sum)
			
			bossTable.bossFrame:SetHeight((helthBarHeight + castBarHeight + powerBarHeight)*effectiveHeight)
			bossTable.healthBar:SetHeight(helthBarHeight*effectiveHeight)
			bossTable.castBar:SetHeight(castBarHeight*effectiveHeight)
			bossTable.powerBar:SetHeight(powerBarHeight*effectiveHeight)
		else
			bossTable.bossFrame:SetHeight(0)
		end
	end
end

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
	updateBarHeights()
	for bossNum, bossTable in pairs(display.boss) do
		local bossFrame, healthBar, castBar, powerBar = bossTable.bossFrame, bossTable.healthBar, bossTable.castBar, bossTable.powerBar
		
		healthBar:SetStatusBarTexture(media:Fetch("statusbar", db.texture))
		castBar:SetStatusBarTexture(media:Fetch("statusbar", db.texture))
		powerBar:SetStatusBarTexture(media:Fetch("statusbar", db.texture))
		
		if bossFrame:GetHeight() == 0 then bossFrame:Hide() else bossFrame:Show() end
		if healthBar:GetHeight() == 0 then healthBar:Hide() else healthBar:Show() end
		if castBar:GetHeight() == 0 then castBar:Hide() else castBar:Show() end
		if powerBar:GetHeight() == 0 then powerBar:Hide() else powerBar:Show() end
	end
	if db.lock then
		locked = nil
		lockDisplay()
	else
		locked = true
		unlockDisplay()
	end
end

local function createFrame()
	display = CreateFrame("Frame", "BigWigsBossBars", UIParent)
	display:SetSize(db.width, db.height)
	display:SetClampedToScreen(true)
	display:EnableMouse(true)
	display:SetScript("OnMouseUp", setConfigureTarget)
	display:SetMinResize(80, 30)
		
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

	display.boss = {}
	for i = 1, MAX_BOSS_FRAMES do
		local bossFrame = CreateFrame("Frame", "BigWigsBossBarsBoss"..i, display)  
		
		if i == 1 then
			bossFrame:SetPoint("TOPLEFT", display, "TOPLEFT")
			bossFrame:SetPoint("TOPRIGHT", display, "TOPRIGHT")
		else
			bossFrame:SetPoint("TOPLEFT", display.boss[i-1].bossFrame, "BOTTOMLEFT", 0, -(db.spacing))
			bossFrame:SetPoint("TOPRIGHT", display.boss[i-1].bossFrame, "BOTTOMRIGHT", 0, -(db.spacing))
		end
		if i == MAX_BOSS_FRAMES then bossFrame:SetPoint("BOTTOM", display, "BOTTOM") end
		
		local healthBar = CreateFrame("StatusBar", "BigWigsBossBarsBoss"..i.."HealthBar", bossFrame)
		local castBar = CreateFrame("StatusBar", "BigWigsBossBarsBoss"..i.."CastBar", bossFrame)
		local powerBar = CreateFrame("StatusBar", "BigWigsBossBarsBoss"..i.."PowerBar", bossFrame)
		
		healthBar:SetPoint("TOPLEFT", bossFrame, "TOPLEFT")
		healthBar:SetPoint("TOPRIGHT", bossFrame, "TOPRIGHT")
		castBar:SetPoint("TOPLEFT", healthBar, "BOTTOMLEFT")
		castBar:SetPoint("TOPRIGHT", healthBar, "BOTTOMRIGHT")
		powerBar:SetPoint("TOPLEFT", castBar, "BOTTOMLEFT")
		powerBar:SetPoint("TOPRIGHT", castBar, "BOTTOMRIGHT")
		powerBar:SetPoint("BOTTOM", bossFrame, "BOTTOM")
		
		local bossName = healthBar:CreateFontString("BigWigsBossBarsBoss"..i.."Name", "OVERLAY", "GameFontNormal")
		local bossHealth = healthBar:CreateFontString("BigWigsBossBarsBoss"..i.."Health", "OVERLAY", "GameFontNormal")
		local castName = castBar:CreateFontString("BigWigsBossBarsBoss"..i.."CastName", "OVERLAY", "GameFontNormal")
		local castDuration = healthBar:CreateFontString("BigWigsBossBarsBoss"..i.."CastDuration", "OVERLAY", "GameFontNormal")
		local powerBarText = healthBar:CreateFontString("BigWigsBossBarsBoss"..i.."PowerBarText", "OVERLAY", "GameFontNormal")
		local powerBarValue = healthBar:CreateFontString("BigWigsBossBarsBoss"..i.."PowerBarValue", "OVERLAY", "GameFontNormal")
		
		bossHealth:SetPoint("RIGHT", healthBar, "RIGHT", -3, 0)
		bossName:SetPoint("LEFT", healthBar, "LEFT", 3, 0)
		bossName:SetPoint("RIGHT", bossHealth, "LEFT", -3, 0)
		castDuration:SetPoint("RIGHT", castBar, "RIGHT", -3, 0)
		castName:SetPoint("LEFT", castBar, "LEFT", 3, 0)
		castName:SetPoint("RIGHT", castDuration, "LEFT", -3, 0)
		powerBarValue:SetPoint("RIGHT", powerBar, "RIGHT", -3, 0)
		powerBarText:SetPoint("LEFT", powerBar, "LEFT", 3, 0)
		powerBarText:SetPoint("RIGHT", castDuration, "LEFT", -3, 0)
		
		display.boss[i] = {
			bossFrame = bossFrame,
			healthBar = healthBar,
			castBar = castBar,
			powerBar = powerBar,
			bossName = bossName,
			bossHealth = bossHealth,
			castName = castName,
			castDuration = castDuration,
			powerBarText = powerBarText,
			powerBarValue = powerBarValue
		}
	end
	updateBarHeights()
	--plugin:RestyleWindow()

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
	display.background:SetTexture(0, 0, 0, 0.3)
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
	local function GetTestBossTable()
		local maxHealth, castTime, maxPower = rnd(10^5, 10^7), (rnd(20,50)/10), 100
		local curHealth, castDuration, curPower = rnd(maxHealth), (rnd(castTime*10)/10), rnd(100)
		return {
			maxHealth = maxHealth,
			curHealth = curHealth,
			castTime = castTime,
			castDuration = castDuration,
			maxPower = maxPower,
			curPower = curPower
		}
	end
	
	function plugin:Test()
		if createFrame then createFrame() createFrame = nil end
		self:Close()
		
		for bossNum, frameTable in pairs(display.boss) do
			local bossTable = GetTestBossTable()
			
			frameTable.healthBar:SetMinMaxValues(0, bossTable.maxHealth)
			frameTable.healthBar:SetValue(bossTable.curHealth)
			
			frameTable.castBar:SetMinMaxValues(0, bossTable.castTime)
			frameTable.castBar:SetValue(bossTable.castDuration)
			
			frameTable.powerBar:SetMinMaxValues(0, bossTable.maxPower)
			frameTable.powerBar:SetValue(bossTable.curPower)
			
			frameTable.bossName:SetText("boss"..bossNum)
			frameTable.bossHealth:SetText(string.format("%s / %s", makeReadableNumber(bossTable.curHealth), makeReadableNumber(bossTable.maxHealth)))
			frameTable.castName:SetText("boss"..bossNum.."Cast")
			frameTable.castDuration:SetText(tostring(bossTable.castDuration))
			frameTable.powerBarText:SetText("boss"..bossNum.."Power")
			frameTable.powerBarValue:SetText(string.format("%s / %s", makeReadableNumber(bossTable.curPower), makeReadableNumber(bossTable.maxPower)))
			
			frameTable.bossFrame:Show()
		end
		updateBarHeights()
		display.title:SetText("Boss Bars")
		display:Show()
		inTestMode = true
	end
end

function plugin:Close()
	if not updater then return end
	updater:Stop()
	display:Hide()
	inTestMode = nil
end

-------------------------------------------------------------------------------
-- Event Handlers
--

function plugin:BigWigs_ShowBossBars()

end

function plugin:BigWigs_OnBossDisable()

end