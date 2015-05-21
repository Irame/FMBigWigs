--------------------------------------------------------------------------------
-- Module Declaration
--

local mod, CL = BigWigs:NewBoss("Warmaster Blackhorn", 824, 332)
if not mod then return end
-- Goriona, Blackhorn, The Skyfire, Ka'anu Reevs, Sky Captain Swayze, 2Cannons, People on Deck
mod:RegisterEnableMob(56781, 56427, 56598, 42288, 55870, 57265, 56681, 57260)

--------------------------------------------------------------------------------
-- Locales
--

local canEnable, warned = true, false
local onslaughtCounter = 1
local sapper = nil --placeholder for Timer Schedule
local drakes = {}
local addcount = 0

--------------------------------------------------------------------------------
-- Localization
--

local L = mod:NewLocale("enUS", true)
if L then
	L.warmup = "Warmup"
	L.warmup_desc = "Time until combat starts."
	L.warmup_icon = "achievment_boss_blackhorn"

	L.sunder = "Sunder Armor"
	L.sunder_desc = "Tank alert only. Count the stacks of sunder armor and show a duration bar."
	L.sunder_icon = 108043
	L.sunder_message = "%2$dx Sunder on %1$s"

	L.sapper_trigger = "A drake swoops down to drop a Twilight Sapper onto the deck!"
	L.sapper = "Sapper"
	L.sapper_desc = "Sapper dealing damage to the ship"
	L.sapper_icon = 73457

	L.stage2_trigger = "Looks like I'm doing this myself. Good!"
	
	L.rider = "Dragonriders"
	L.rider_desc = "The two dragonriders dropping onto the ship"
	L.rider_icon = "inv_misc_monsterhorn_07"
end
L = mod:GetLocale()
L.sunder = L.sunder.." "..INLINE_TANK_ICON

--------------------------------------------------------------------------------
-- Initialization
--

function mod:GetOptions(CL)
	return {
		107588, "sapper", 108038, "rider",
		"sunder", {108046, "SAY", "FLASHSHAKE"}, {108076, "SAY", "FLASHSHAKE", "ICON"}, 108044,
		"warmup", "berserk", "bosskill",
	}, {
		[107588] = "ej:4027",
		sunder = "ej:4033",
		warmup = CL["general"],
	}
end

function mod:VerifyEnable()
	return canEnable
end

function mod:OnBossEnable()
	self:Log("SPELL_SUMMON", "TwilightFlames", 108076) -- did they just remove this?
	self:Log("SPELL_CAST_START", "TwilightOnslaught", 107588)
	self:Log("SPELL_CAST_START", "Shockwave", 108046)
	self:Log("SPELL_AURA_APPLIED", "Sunder", 108043)
	self:Log("SPELL_AURA_APPLIED", "PreStage2", 108040)
	self:Log("SPELL_AURA_APPLIED_DOSE", "Sunder", 108043)
	self:Log("SPELL_CAST_SUCCESS", "Roar", 109228, 108044, 109229, 109230) --LFR/25N, 10N, ??, ??
	self:Emote("Sapper", L["sapper_trigger"])
	self:Yell("Stage2", L["stage2_trigger"])

	self:Log("SPELL_AURA_APPLIED", "Harpoon", 108038)
	self:Log("SPELL_AURA_REMOVED", "HarpoonFade", 108038)
	self:Death("DrakeDeath", 56587, 56855) --LEFT/RIGHT
	
	self:RegisterEvent("INSTANCE_ENCOUNTER_ENGAGE_UNIT", "CheckBossStatus")
	self:Death("Win", 56427)
end

function mod:OnEngage(diff)
	self:Bar(107588, (GetSpellInfo(107588)), 48, 107588) -- Twilight Onslaught
	if not self:LFR() then
		self:Bar("sapper", L["sapper"], 70+10, L["sapper_icon"])
		sapper = self:ScheduleTimer("Sapper", 80)
	end
	onslaughtCounter = 1
	self:Bar("warmup", _G["COMBAT"], 32, L["warmup_icon"])
	self:DelayedMessage("warmup", 32, CL["phase"]:format(1), "Positive", L["warmup_icon"])
	warned = false
	self:Bar(108038, GetSpellInfo(108038), 56, 108038) --Harpoon
	addcount = 0
	drakes = {}
end

function mod:OnWin()
	canEnable = false
end

--------------------------------------------------------------------------------
-- Event Handlers
--

function mod:Sapper() --All 40 sec
	self:Message("sapper", L["sapper"], "Important", L["sapper_icon"], "Info")
	if warned then return end
	self:Bar("sapper", L["sapper"], 40, L["sapper_icon"])
	sapper = self:ScheduleTimer("Sapper", 40)
end

do
	function mod:PreStage2()
		if not warned then
			warned = true
			self:Bar("warmup", self.displayName, 9, L["warmup_icon"])
			self:Message("warmup", CL["custom_sec"]:format(self.displayName, 9), "Positive", L["warmup_icon"])
		end
	end
	function mod:Stage2()
		self:SendMessage("BigWigs_StopBar", self, (GetSpellInfo(107588))) -- Twilight Onslaught
		self:SendMessage("BigWigs_StopBar", self, L["sapper"])
		self:StopBar(L.rider.." ("..(addcount+1)..")") --last AddspawnTimer
		self:StopBar(GetSpellInfo(108038)) --Harpoon
		if sapper ~= nil then
			self:CancelTimer(sapper, true)
		end
		
		self:Bar(108046, "~"..GetSpellInfo(108046), 14, 108046) -- Shockwave
		self:Message("warmup", CL["phase"]:format(2) .. ": " .. self.displayName, "Positive", L["warmup_icon"])
		if not self:LFR() then
			self:Berserk(240, true)
		end
	end
end

do
	local function checkTarget(sGUID)
		local mobId = mod:GetUnitIdByGUID(sGUID)
		if mobId then
			local player = UnitName(mobId.."target")
			if not player then return end
			if UnitIsUnit("player", player) then
				local twilightFlames = GetSpellInfo(108076)
				mod:Say(108076, CL["say"]:format(twilightFlames))
				mod:FlashShake(108076)
				mod:LocalMessage(108076, twilightFlames, "Personal", 108076, "Long")
			end
			mod:PrimaryIcon(108076, player)
		end
	end
	function mod:TwilightFlames(...)
		local sGUID = select(11, ...)
		self:ScheduleTimer(checkTarget, 0.1, sGUID)
	end
end

function mod:TwilightOnslaught(_, spellId, _, _, spellName)
	self:Message(107588, spellName, "Urgent", spellId, "Alarm")
	onslaughtCounter = onslaughtCounter + 1
	if warned then return end
	self:Bar(107588, ("%s (%d)"):format(spellName, onslaughtCounter), 35, spellId)
end

do
	-- local timer, fired = nil, 0
	-- local function shockWarn()
		-- fired = fired + 1
		-- local player = UnitName("boss2target")
		-- if player and (not UnitDetailedThreatSituation("boss2target", "boss2") or fired > 11) then
			-- If we've done 12 (0.6s) checks and still not passing the threat check, it's probably being cast on the tank
			-- local shockwave = GetSpellInfo(108046)
			-- mod:TargetMessage(108046, shockwave, player, "Attention", 108046, "Alarm")
			-- mod:CancelTimer(timer, true)
			-- timer = nil
			-- if UnitIsUnit("boss2target", "player") then
				-- mod:FlashShake(108046)
				-- mod:Say(108046, CL["say"]:format(shockwave))
			-- end
			-- return
		-- end
		-- 19 == 0.95sec
		-- Safety check if the unit doesn't exist
		-- if fired > 18 then
			-- mod:CancelTimer(timer, true)
			-- timer = nil
		-- end
	-- end
	
	function mod:Shockwave(_, spellId, _, _, spellName)
		self:Bar(108046,spellName, 23, spellId)
		self:Message(108046, spellName, "Positive", spellId, "Alarm")
	end
end

function mod:Sunder(player, spellId, _, _, spellName, buffStack)
	if self:Tank() then
		buffStack = buffStack or 1
		self:SendMessage("BigWigs_StopBar", self, L["sunder_message"]:format(player, buffStack - 1))
		self:Bar("sunder", L["sunder_message"]:format(player, buffStack), 30, spellId)
		self:LocalMessage("sunder", L["sunder_message"], "Urgent", spellId, buffStack > 2 and "Info" or nil, player, buffStack)
	end
end

function mod:Roar(_, spellId, _, _, spellName)
	self:Bar(108044, spellName, 18.5, spellId) -- 20-23
	self:Message(108044, spellName, "Positive", spellId, "Alert")
end

do
	local harpoonTxt = GetSpellInfo(108038).." (%s)"

	local lastHarp = 0
	local lastDrakes = 0
	function mod:Harpoon(player, spellId, source, auraType, spellName, buffStack, event, sFlags, dFlags, dGUID, sGUID)
		if dGUID == sGUID then return end --we want the Drakes as dGUID - not the Harpoon (both get the Buff)
		
		--drakes has max. 9 entrys (6drakes, 3waves) thus clearing only here is not that problematic.
		if addcount == 0 then wipe(drakes) end
		
		self:Bar(108038, CL.cast:format(spellName) ,20, spellId)
		
		if not drakes[dGUID] then
			local now = GetTime()
			if now - lastHarp > 5 then
				addcount = addcount + 1 --just now Harpooned wave
				lastHarp = now
				if addcount < 3 then--there are only 3 waves
					self:Bar("rider", L.rider.." ("..(addcount+1)..")", 37, "inv_misc_monsterhorn_07")--next wave
					self:DelayedBar(108038, 37, harpoonTxt:format(addcount+1) , 61-37, spellId) --start HarpoonTimer for Harpoon of next wave.
				end
			end
		
			drakes[dGUID] = addcount
			drakes[addcount] = drakes[addcount] or {}
			table.insert(drakes[addcount], dGUID) 
		end
	end
	
	function mod:DrakeDeath(mobId, dGUID, name, dFlags)
		local drakewave = drakes[dGUID]
		drakes[dGUID] = nil
		if drakewave then
			for i, v in ipairs(drakes[drakewave]) do
				if v == dGUID then
					table.remove(drakes[drakewave], i)
					break
				end
			end
			if #drakes[drakewave] == 0 then
				drakes[drakewave] = nil
				self:StopBar(harpoonTxt:format(drakewave))
			end
		end
	end
	
	function mod:HarpoonFade(player, spellId, source, secSpellId, spellName, buffStack, event, sFlags, dFlags, dGUID, sGUID)
		if dGUID ~= sGUID then --only, those Buffs that hit the Drakes.
			local drakewave = drakes[dGUID] --wave the drake belongs to
			if drakewave then --did the Drake die already?
				--no -> Bar to next Harpoon (13 sec)
				self:Bar(108038, harpoonTxt:format(drakewave), 13, 108038)
			end
		end	
	end
end