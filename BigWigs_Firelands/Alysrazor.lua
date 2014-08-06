--------------------------------------------------------------------------------
-- Module Declaration
--

local mod, CL = BigWigs:NewBoss("Alysrazor", 800, 194)
if not mod then return end
mod:RegisterEnableMob(52530, 53898, 54015, 53089) --Alysrazor, Voracious Hatchling, Majordomo Staghelm, Molten Feather

local firestorm = GetSpellInfo(101659)
local woundTargets = mod:NewTargetList()
local meteorCount, moltCount, burnCount, initiateCount = 0, 0, 0, 0
local initiateTimes = {31, 23, 19, 21, 21} --NM

local initiateTbl, wormTbl = {}, {}

--------------------------------------------------------------------------------
--  Localization
--

local L = mod:NewLocale("enUS", true)
if L then
	L.claw_message = "%2$dx Claw on %1$s"
	L.fullpower_soon_message = "Full power soon!"
	L.halfpower_soon_message = "Stage 4 soon!"
	L.encounter_restart = "Here we go again..."
	L.no_stacks_message = "Dunno if you care, but you have no feathers"
	L.moonkin_message = "Stop pretending and get some real feathers"
	L.molt_bar = "Molt"

	L.meteor = "Meteor"
	L.meteor_desc = "Warn when a Molten Meteor is summoned."
	L.meteor_icon = 100761
	L.meteor_message = "Meteor!"

	L.stage_message = "Stage %d"
	L.kill_message = "It's now or never - Kill her!"
	L.engage_message = "Alysrazor engaged - Stage 2 in ~%d min"

	L.worm_emote = "Fiery Lava Worms erupt from the ground!"
	L.phase2_soon_emote = "Alysrazor begins to fly in a rapid circle!"

	L.flight = "Flight Assist"
	L.flight_desc = "Show a bar with the duration of 'Wings of Flame' on you, ideally used with the Super Emphasize feature."
	L.flight_icon = 98619

	L.initiate = "Initiate Spawn"
	L.initiate_desc = "Show timer bars for initiate spawns."
	L.initiate_icon = 97062
	L.initiate_both = "Both Initiates"
	L.initiate_west = "West Initiate"
	L.initiate_east = "East Initiate"

	L.eggs, L.eggs_desc = EJ_GetSectionInfo(2836)
	L.eggs_icon = "inv_trinket_firelands_02"
	
	L.interrupt = "Interrupt"
	L.interrupt_desc = "Interrupt warning for "..GetSpellInfo(101223).." and "..GetSpellInfo(99919)
end
L = mod:GetLocale()

--------------------------------------------------------------------------------
-- Initialization
--

function mod:GetOptions()
	return {
		99362, 100024, 97128, 99464, "flight", "initiate", "eggs",
		99816,
		99432,
		99844, 99925,
		{100744, "FLASHSHAKE"}, "meteor",
		"bosskill",
		"interrupt"
	}, {
		[99362] = "ej:2820", --Stage 1: Flight
		[99816] = "ej:2821", --Stage 2: Tornadoes
		[99432] = "ej:2822", --Stage 3: Burnout
		[99844] = "ej:2823", --Stage 4: Re-Ignite
		[100744] = "heroic",
		bosskill = "general"
	}
end

function mod:OnBossEnable()
	-- General
	self:Log("SPELL_AURA_APPLIED", "Molting", 99464, 99465, 100698) --9464 10nh
	self:Log("SPELL_AURA_APPLIED_DOSE", "BlazingClaw", 99844, 101729, 101730, 101731)
	self:Log("SPELL_AURA_APPLIED", "StartFlying", 98619)
	self:Log("SPELL_AURA_REMOVED", "StopFlying", 98619)

	-- Stage 1: Flight
	self:Log("SPELL_AURA_APPLIED", "Wound", 100723, 100722, 100721, 100720, 100719, 100718, 100024, 99308)
	self:Log("SPELL_AURA_APPLIED", "Tantrum", 99362)

	self:Log("SPELL_CAST_SUCCESS", "WormCast", 99336)
	--self:Emote("BuffCheck", L["worm_emote"])

	-- Stage 2: Tornadoes
	self:Log("SPELL_CAST_SUCCESS", "FieryTornadoSpell", 99816)
	--self:Emote("FieryTornado", L["phase2_soon_emote"])

	-- Stage 3: Burnout
	self:Log("SPELL_AURA_APPLIED", "Burnout", 99432)

	-- Stage 4: Re-Ignite
	self:Log("SPELL_AURA_REMOVED", "ReIgnite", 99432)

	-- Heroic only
	self:Log("SPELL_CAST_START", "Meteor", 100761, 102111)
	self:Log("SPELL_CAST_START", "Firestorm", 100744)
	self:Log("SPELL_AURA_REMOVED", "FirestormOver", 100744)

	self:RegisterEvent("INSTANCE_ENCOUNTER_ENGAGE_UNIT", "CheckBossStatus")
	self:RegisterEvent("CHAT_MSG_MONSTER_YELL", "Initiates")
	self:Log("SPELL_CAST_START", "InitiateCast", 101223, 98868, 100093)
	self:IterruptWarn("interrupt", "all", 101223, 99919) --Fyroblast, Ignition
	
	self:Death("Win", 52530)
end

function mod:OnEngage(diff)
	initiateTbl, wormTbl = {}, {}
	meteorCount, moltCount, burnCount, initiateCount = 0, 0, 0, 0
	wipe(initiateTimes)
	if diff > 2 then
		initiateTimes = {22, 75, 19, 21, 50}
		self:Bar("initiate", L.initiate_both, 34.5, 97062) 
		self:Message(99816, L["engage_message"]:format(4), "Attention", "inv_misc_pheonixpet_01")
		self:Bar(99816, L["stage_message"]:format(2), 250-9, 99816)
		self:DelayedMessage(99816, 250-9, (L["stage_message"]:format(2))..": "..GetSpellInfo(99816), "Important", 99816, "Alarm")
		self:Bar(100744, firestorm, 93.5, 100744)
		self:Bar("meteor", L["meteor"], 45.5, 100761)
		self:Bar("eggs", "~"..GetSpellInfo(58542), 49, L["eggs_icon"])
		self:DelayedMessage("eggs", 49-11.5, GetSpellInfo(58542), "Positive", L["eggs_icon"])
	else
		initiateTimes = {31, 23, 19, 21, 21}
		self:Bar("initiate", L.initiate_both, 28, 97062) 
		self:Message(99816, L["engage_message"]:format(3), "Attention", "inv_misc_pheonixpet_01")
		self:Bar(99816, L["stage_message"]:format(2), 188.5+12, 99816)
		self:DelayedMessage(99816, 188.5+12, (L["stage_message"]:format(2))..": "..GetSpellInfo(99816), "Important", 99816, "Alarm")
		self:Bar(99464, L["molt_bar"], 10.5, 99464)
		self:Bar("eggs", GetSpellInfo(58542), 42, L["eggs_icon"])
		self:DelayedMessage("eggs", 41.5, GetSpellInfo(58542), "Positive", L["eggs_icon"])
	end	
end

--------------------------------------------------------------------------------
-- Event Handlers
--

do--flying
	local flying = GetSpellInfo(98619)
	local lastCheck = 0
	function mod:UNIT_AURA(_, unit)
		if unit ~= "player" then return end
		local _, _, _, _, _, _, expires = UnitBuff("player", flying)
		if expires ~= lastCheck then
			lastCheck = expires
			self:Bar("flight", flying, expires-GetTime(), 98619)
		end
	end
	function mod:StartFlying(player)
		if UnitIsUnit(player, "player") then
			self:Bar("flight", flying, 30, 98619)
			self:RegisterEvent("UNIT_AURA")
		end
	end
	function mod:StopFlying(player)
		if UnitIsUnit(player, "player") then
			self:StopBar(flying)
			self:UnregisterEvent("UNIT_AURA")
		end
	end
end

do--initiate
	local initiateLocation = {L["initiate_both"], L["initiate_east"], L["initiate_west"], L["initiate_east"], L["initiate_west"]}
	local initiate = EJ_GetSectionInfo(2834)
	
	local last = 0
	function mod:Initiates(_, _, unit)
		if unit == initiate and GetTime()-last > 10 then
			last = GetTime()
			initiateCount = initiateCount + 1
			if initiateCount > 5 then return end
			self:Bar("initiate", initiateLocation[initiateCount], initiateTimes[initiateCount] , 97062) --Night Elf head
		end
	end
	
	function mod:InitiateCast(...)
		local sGUID = select(11,...)
		local unit = select(3,...)
		if not initiateTbl[sGUID] then
			initiateTbl[sGUID] = true
			mod:Initiates(nil, nil, unit)
		end
	end
end

do
	local feather = GetSpellInfo(97128)
	local moonkin = GetSpellInfo(24858)
	function mod:BuffCheck()		
		local name = UnitBuff("player", feather)
		if not name then
			if UnitBuff("player", moonkin) then
				self:Message(97128, L["moonkin_message"], "Personal", 97128, "Info")
			else
				self:Message(97128, L["no_stacks_message"], "Personal", 97128, "Info")
			end
		end
	end
	
	local last = 0
	function mod:WormCast(...)
		local sGUID = select(11,...)
		if not wormTbl[sGUID] then
			wormTbl[sGUID] = true
			if GetTime()-last > 5 then
				self:BuffCheck()
				last = GetTime()
			end
		end
	end
end

do
	local scheduled = nil
	local function woundWarn(spellName)
		mod:TargetMessage(100024, spellName, woundTargets, "Personal", 100024)
		scheduled = nil
	end
	function mod:Wound(player, spellId, _, _, spellName)
		if not UnitIsPlayer(player) then return end --Avoid those shadowfiends
		woundTargets[#woundTargets + 1] = player
		if not scheduled then
			scheduled = true
			self:ScheduleTimer(woundWarn, 0.5, spellName)
		end
	end
end

function mod:Tantrum(_, spellId, _, _, spellName, _, _, _, _, _, sGUID)
	local target = UnitGUID("target")
	if not target or sGUID ~= target then return end
	-- Just warn for the tank
	self:Message(99362, spellName, "Important", spellId)
end

-- don't need molting warning for heroic because molting happens at every firestorm
function mod:Molting(_, spellId, _, _, spellName)
	if self:Difficulty() < 3 then
		moltCount = moltCount + 1
		self:Message(99464, spellName, "Positive", spellId)
		if moltCount < 3 then
			self:Bar(99464, L["molt_bar"], (59.5)-2.5*moltCount, spellId)
		end
	elseif meteorCount > 0 then--ignore initial Molting
		self:Bar("eggs", "~"..GetSpellInfo(58542), 18, L["eggs_icon"])
		self:DelayedMessage("eggs", 18-11.5, GetSpellInfo(58542), "Positive", L["eggs_icon"])
	end
end

function mod:Firestorm(_, spellId, _, _, spellName)
	self:FlashShake(100744)
	self:Message(100744, spellName, "Urgent", spellId, "Alert")
	self:Bar(100744, CL["cast"]:format(spellName), 10, spellId)
	if burnCount > 0 then
		self:Bar("meteor", L["meteor"], meteorCount == 2 and 18 or 21.5*0, 100761)
	else
		self:Bar("meteor", L["meteor"], meteorCount == 2 and 22 or 21.5*0, 100761)
	end
	if meteorCount < 3 then
		self:Bar(100744, GetSpellInfo(100744), 81.5, 100744)
	end
end

function mod:FirestormOver(_, spellId, _, _, spellName) --DOES NOT OCCUR!
	-- Only show a bar for next if we have seen less than 3 meteors
	if meteorCount < 3 then
		self:Bar(100744, "~"..spellName, 72, spellId)
	end
	self:Bar("meteor", L["meteor"], meteorCount == 2 and 11.5 or 21.5, 100761)
	self:Bar("eggs", "~"..GetSpellInfo(58542), 22.5, L["eggs_icon"])
	self:DelayedMessage("eggs", 22, GetSpellInfo(58542), "Positive", L["eggs_icon"])
end

function mod:Meteor(_, spellId)
	self:Message("meteor", L["meteor_message"], "Attention", spellId, "Alarm")
	-- Only show a bar if this is the first or third meteor this phase
	meteorCount = meteorCount + 1
	if meteorCount == 1 then --or meteorCount == 3
		self:Bar("meteor", L["meteor"], 30, spellId)
	end
end

do
	local last = 0
	function mod:FieryTornadoSpell()
		local t = GetTime()
		if t-last > 2 then
			mod:FieryTornado()
		end
		last = t
	end
end

function mod:FieryTornado()
	--self:BuffCheck() --Too late
	self:SendMessage("BigWigs_StopBar", self, firestorm)
	local fieryTornado = GetSpellInfo(99816)
	self:Bar(99816, fieryTornado, 35-8, 99816)
	--self:Message(99816, (L["stage_message"]:format(2))..": "..fieryTornado, "Important", 99816, "Alarm")
end

function mod:BlazingClaw(player, spellId, _, _, _, stack)
	if stack > 5 and stack%3 == 0 then -- 50% + extra fire and physical damage taken on tank
		--only warn each 3rd stack - so annoying
		self:TargetMessage(99844, L["claw_message"], player, "Urgent", spellId, "Info", stack)
	end
end

do
	local halfWarned = false
	local fullWarned = false

	-- Alysrazor crashes to the ground
	function mod:Burnout(_, spellId, _, _, spellName)
		self:Message(99432, (L["stage_message"]:format(3))..": "..spellName, "Positive", spellId, "Alert")
		halfWarned, fullWarned = false, false
		burnCount = burnCount + 1
		if burnCount < 3 then
			self:RegisterEvent("UNIT_POWER")
		end
	end

	function mod:UNIT_POWER(_, unit)
		local power = UnitPower("boss1")
		if power > 40 and not halfWarned then
			self:Message(99925, L["halfpower_soon_message"], "Urgent", 99925)
			halfWarned = true
		elseif power > 80 and not fullWarned then
			self:Message(99925, L["fullpower_soon_message"], "Attention", 99925)
			fullWarned = true
		elseif power == 100 then
			self:Message(99925, (L["stage_message"]:format(1))..": "..(L["encounter_restart"]), "Positive", 99925, "Alert")
			self:UnregisterEvent("UNIT_POWER")
			initiateCount = 0
			self:Bar("initiate", L["initiate_both"], 17.5, 97062)
			if self:Difficulty() > 2 then
				meteorCount = 0
				self:Bar("meteor", L["meteor"], 18, 100761)
				self:Bar(100744, firestorm, 70, 100744)
				self:Bar(99816, L["stage_message"]:format(2), 225, 99816) -- Just adding 60s like OnEngage
				self:DelayedMessage(99816, 225, (L["stage_message"]:format(2))..": "..GetSpellInfo(99816), "Important", 99816, "Alarm")
				self:Bar("eggs", "~"..GetSpellInfo(58542), 30, L["eggs_icon"])
				self:DelayedMessage("eggs", 30-11.5, GetSpellInfo(58542), "Positive", L["eggs_icon"])
			else
				self:Bar(99816, L["stage_message"]:format(2), 170+5, 99816)
				self:DelayedMessage(99816, 170+5, (L["stage_message"]:format(2))..": "..GetSpellInfo(99816), "Important", 99816, "Alarm")
				moltCount = 1
				self:Bar(99464, L["molt_bar"], 51, 99464)
				self:Bar("eggs", "~"..GetSpellInfo(58542), 22.5+16, L["eggs_icon"])
				self:DelayedMessage("eggs", 22+16, GetSpellInfo(58542), "Positive", L["eggs_icon"])
			end
		end
	end

	function mod:ReIgnite()
		if burnCount < 3 then
			self:Message(99925, (L["stage_message"]:format(4))..": "..(GetSpellInfo(99922)), "Positive", 99922, "Alert")
			self:Bar(99925, GetSpellInfo(99925), 25, 99925)
		else
			self:Message(99925, L["kill_message"], "Positive", 99922, "Alert")
		end
		self:SendMessage("BigWigs_StopBar", self, "~"..GetSpellInfo(99432))
	end
end