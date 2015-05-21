--------------------------------------------------------------------------------
-- Module Declaration
--

local mod, CL = BigWigs:NewBoss("Ultraxion", 824, 331)
if not mod then return end
mod:RegisterEnableMob(55294, 56667) -- Ultraxion, Thrall

--------------------------------------------------------------------------------
-- Locales
--

local hourCounter = 1
local lightTargets = mod:NewTargetList()
local lightCounter = 0
local fadingLight = GetSpellInfo(110080)
local yellFrame = CreateFrame("Frame")

--------------------------------------------------------------------------------
-- Localization
--

local L = mod:NewLocale("enUS", true)
if L then
	L.engage_trigger = "Now is the hour of twilight!"

	L.warmup = "Warmup"
	L.warmup_desc = "Time until combat with the boss starts."
	L.warmup_icon = "achievment_boss_ultraxion"
	L.warmup_trigger = "I am the beginning of the end...the shadow which blots out the sun"

	L.crystal = "Buff Crystals"
	L.crystal_desc = "Timers for thed various buff crystals the NPCs summon."
	L.crystal_icon = "inv_misc_head_dragon_01"
	L.crystal_red = "Red Crystal"
	L.crystal_green = "Green Crystal"
	L.crystal_green_icon = "inv_misc_head_dragon_green"
	L.crystal_blue = "Blue Crystal"
	L.crystal_blue_icon = "inv_misc_head_dragon_blue"
	L.crystal_bronze_icon = "inv_misc_head_dragon_bronze"

	L.twilight = "Twilight"
	L.cast = "Twilight Cast Bar"
	L.cast_desc = "Show a 5 (Normal) or 3 (Heroic) second bar for Twilight being cast."
	L.cast_icon = 106371

	L.lightself = "Fading Light on You"
	L.lightself_desc = "Show a bar displaying the time left until Fading Light causes you to explode."
	L.lightself_bar = "<You Explode>"
	L.lightself_icon = 105925

	L.lighttank = "Fading Light on Tanks"
	L.lighttank_desc = "Tank alert only. If a tank has Fading Light, show an explode bar and Flash/Shake."
	L.lighttank_bar = "<%s Explodes>"
	L.lighttank_message = "Exploding Tank"
	L.lighttank_icon = 105925
	
	L.lightcool = "Fading Light Cooldown"
	L.lighttank_desc = "Shows a Bar for the Cooldown of Fading Light"
	L.lighttank_icon = 105925
	
end
L = mod:GetLocale()
L.lighttank = L.lighttank.." "..INLINE_TANK_ICON

--------------------------------------------------------------------------------
-- Initialization
--

function mod:GetOptions(CL)
	return {
		{106371, "FLASHSHAKE"}, "cast",
		105925, {"lightself", "FLASHSHAKE"}, {"lighttank", "FLASHSHAKE"}, "lightcool",
		--[["warmup",]] "crystal", "berserk", "bosskill",
	}, {
		[106371] = L["twilight"],
		[105925] = GetSpellInfo(105925),
		warmup = CL["general"],
	}
end

function mod:OnBossEnable()
	self:Log("SPELL_CAST_START", "HourofTwilight", 106371, 109415, 109416, 109417)
	self:Log("SPELL_AURA_APPLIED", "FadingLight", 109075, 110078, 110079, 110080)
	self:Log("SPELL_AURA_APPLIED", "FadingLightTank", 105925, 110068, 110069, 110070) --This forwards to mod:FadingLight()
	self:RegisterEvent("INSTANCE_ENCOUNTER_ENGAGE_UNIT", "CheckBossStatus")
	--self:Yell("Warmup", L["warmup_trigger"]) --not needed, cause no instant pull
	--self:Emote("Gift", L["crystal_icon"]) --Does not happen
	--self:Emote("Dreams", L["crystal_green_icon"]) --Does not happen
	self:Emote("Magic", L["crystal_blue_icon"])
	self:Emote("Loop", L["crystal_bronze_icon"])

	self:Death("ScheduleWin", 55294)
end

function mod:Warmup()
	self:Bar("warmup", self.displayName, 30, "achievment_boss_ultraxion")
end

function mod:OnEngage(diff)
	self:Berserk(360)
	self:Bar(106371, GetSpellInfo(106371), 45, 106371) -- Hour of Twilight
	self:Bar("crystal", L["crystal_red"], 80, L["crystal_icon"])
	hourCounter = 1
	lightCounter = 0
	
	if self:Difficulty() > 2  then--Heroic
		self:Bar("lightcool", fadingLight, 45+13, 110080)
	else
		self:Bar("lightcool", fadingLight, 45+20, 110080)
	end
	
	yellFrame:RegisterEvent("CHAT_MSG_MONSTER_YELL")
	self:BuildYell()
end

--------------------------------------------------------------------------------
-- Event Handlers
--

function mod:Gift()
	self:Bar("crystal", L["crystal_green"], 75, L["crystal_green_icon"])
	self:Message("crystal", L["crystal_red"], "Positive", L["crystal_icon"], "Info")
end

function mod:Dreams()
	self:Bar("crystal", L["crystal_blue"], 60, L["crystal_blue_icon"])
	self:Message("crystal", L["crystal_green"], "Positive", L["crystal_green_icon"], "Info")
end

function mod:Magic()
	self:Bar("crystal", EJ_GetSectionInfo(4241), 80, L["crystal_bronze_icon"]) -- Timeloop
	self:Message("crystal", L["crystal_blue"], "Positive", L["crystal_blue_icon"], "Info")
end

function mod:Loop()
	self:Message("crystal", EJ_GetSectionInfo(4241), "Positive", L["crystal_bronze_icon"], "Info") -- Timeloop
end

function mod:HourofTwilight(_, spellId, _, _, spellName)
	self:Message(106371, ("%s (%d)"):format(spellName, hourCounter), "Important", spellId, "Alert")
	hourCounter = hourCounter + 1
	self:Bar(106371, ("%s (%d)"):format(spellName, hourCounter), 45, spellId)
	self:Bar("cast", CL["cast"]:format(L["twilight"]), self:Difficulty() > 2 and 3 or 5, spellId)
	self:FlashShake(106371)
	
	--Cooldowns from DBM
	lightCounter = 0
	if self:Difficulty() > 2  then--Heroic
		self:Bar("lightcool", fadingLight, 13, 110080)
	else
		self:Bar("lightcool", fadingLight, 20, 110080)
	end
end

do
	local scheduled = nil
	local function fadingLight(spellName)
		mod:TargetMessage(105925, spellName, lightTargets, "Attention", 105925, "Alarm")
		scheduled = nil
	end
	function mod:FadingLight(player, spellId, _, _, spellName)
		lightTargets[#lightTargets + 1] = player
		if UnitIsUnit(player, "player") then
			local duration = select(6, UnitDebuff("player", spellName))
			self:Bar("lightself", L["lightself_bar"], duration, spellId)
			self:FlashShake("lightself")
		end
		if not scheduled then
			scheduled = true
			self:ScheduleTimer(fadingLight, 0.2, spellName)
		end
	end
	
	function mod:FadingLightTank(player, spellId, _, _, spellName, ...)
		lightCounter = lightCounter + 1
		mod:FadingLight(player, spellId, _, _, spellName, ...)
		
		if not UnitIsUnit(player, "player") and self:Tank() then -- is on the other Tank
			self:FlashShake("lighttank")
			local duration = select(6, UnitDebuff(player, spellName))
			self:Bar("lighttank", L["lighttank_bar"]:format(player), duration, spellId)
			self:LocalMessage("lighttank", L["lighttank_message"], "Attention", spellId, player)
			self:PlaySound("lighttank", "Alarm")
		end
		
		local isHeroic = self:Difficulty() > 2
		local cd = isHeroic and 10 or 15
		
		if lightCounter < 2 or isHeroic and lightCounter < 3 then
			self:Bar("lightcool", spellName, cd, spellId)
		end
		
	end
end

function mod:OnWipe(...)
	yellFrame:UnregisterEvent("CHAT_MSG_MONSTER_YELL")
end

function mod:ScheduleWin(...)
	yellFrame:UnregisterEvent("CHAT_MSG_MONSTER_YELL")
	self:Win(...)
end

do--Yell workaround for Crystals
	--Yells: (except Ultraxion)
	--#1 Thrall --buffs CD Reduction
	--#2 Alexstrasza --places Red Crystal
	--#3 Ysera --places Green Crystal
	-- more not needed
	
	local yellCount = 0
	local thrall = EJ_GetSectionInfo(4242)
	
	function mod:BuildYell()
		local this = self --dont know if needed, but this way im safe
		yellFrame:SetScript("OnEvent", function(self , event, txt, sourceName, ...)
			if not this.isEngaged then
				self:UnregisterEvent("CHAT_MSG_MONSTER_YELL")
				return
			end
			
			--Ultraxion is not needed for our purpose and would only make the whole thing harder
			if sourceName == this.displayName then return end
			
			--Thrall is the first Yell of our rotation
			if sourceName == thrall then
				yellCount = 1
			else
				yellCount = yellCount + 1
				if yellCount == 2 then --Thrown red crystal
					this:Gift()
				elseif yellCount == 3 then --Thrown green crystal
					this:Dreams()
					--Blue crystal has its needed Emote - we do not need to track further.
					self:UnregisterEvent("CHAT_MSG_MONSTER_YELL") 
				end
			end
		end)
	end
	
end

