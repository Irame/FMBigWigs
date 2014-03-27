--------------------------------------------------------------------------------
-- Module Declaration
--

local mod, CL = BigWigs:NewBoss("Atramedes", 754, 171)
if not mod then return end
mod:RegisterEnableMob(41442)

local searingFlame = GetSpellInfo(77840)
local sonicBreath = "~"..GetSpellInfo(78075)
local obnoxiousFiend = EJ_GetSectionInfo(3082)

--------------------------------------------------------------------------------
-- Localization
--

local L = mod:NewLocale("enUS", true)
if L then
	L.alt_energy_title = "Sound"
	
	L.ground_phase = "Ground Phase"
	L.ground_phase_desc = "Warning for when Atramedes lands."
	L.air_phase = "Air Phase"
	L.air_phase_desc = "Warning for when Atramedes takes off."

	L.air_phase_trigger = "Yes, run! With every step your heart quickens."

	L.obnoxious_soon = "Obnoxious Fiend soon!"

	L.searing_soon = "Searing Flame in 10sec!"
end
L = mod:GetLocale()

--------------------------------------------------------------------------------
-- Initialization
--

function mod:GetOptions()
	return {
		"ground_phase", 78075, 77840,
		"air_phase",
		{92677, "ICON", "SAY"},
		{78092, "FLASHSHAKE", "ICON", "SAY"}, "altpower", "berserk", "bosskill"
	}, {
		ground_phase = L["ground_phase"],
		air_phase = L["air_phase"],
		[92677] = "heroic",
		[78092] = "general"
	}
end

function mod:OnBossEnable()
	self:Log("SPELL_CAST_SUCCESS", "SonicBreath", 78075)
	self:Log("SPELL_AURA_APPLIED", "Tracking", 78092)
	self:Log("SPELL_AURA_APPLIED", "SearingFlame", 77840)
	self:Yell("AirPhase", L["air_phase_trigger"])

	--Cannot track AirPhase by Yell @FM - check a spell he casts!
	self:Log("SPELL_CAST_SUCCESS", "AirPhase", 78221)
	
	self:Log("SPELL_AURA_REMOVED", "ObnoxiousPhaseShift", 92681)
	--this one only gets removed on FM

	self:RegisterEvent("INSTANCE_ENCOUNTER_ENGAGE_UNIT", "CheckBossStatus")

	--INSTANCE_ENCOUNTER_ENGAGE_UNIT does not work on Frostmourne for  this boss
	--I don't know how i should do it ...
	self:RegisterEvent("PLAYER_REGEN_DISABLED", "CheckForEngage")
	self:CheckForEngage()
	
	self:Death("Win", 41442)
end

function mod:OnEngage(diff)
	self:Bar(78075, sonicBreath, 23-2, 78075)
	self:Bar(77840, searingFlame, 63, 77840)
	
	self:DelayedMessage(77840, 55, L["searing_soon"], "Attention", 77840)
	self:Bar("air_phase", L["air_phase"], 115, 5740) -- Rain of Fire Icon --@ 8:05 left to berserk
	self:OpenAltPower(L["alt_energy_title"])
	if diff > 2 then
		self:Bar(92677, obnoxiousFiend.." #1", 15, 92677) --scnd 85sec after this.
		self:DelayedMessage(92677, 10, L["obnoxious_soon"], "Attention", 92677)
		self:ScheduleTimer(function(i) 
			self:Bar(92677, obnoxiousFiend.." #"..i, 85, 92677);
			self:DelayedMessage(92677, 80, L["obnoxious_soon"], "Attention", 92677)
		end, 15, 2)
		
		--why so early?
		--self:RegisterEvent("UNIT_AURA")
		self:Berserk(600)
	end
end

--------------------------------------------------------------------------------
-- Event Handlers
--

do
	local function FiendCheck(dGUID)
		local fiend = mod:GetUnitIdByGUID(dGUID)
		if not fiend then
			mod:ScheduleTimer(FiendCheck, 0.1, dGUID)
		else
			mod:SecondaryIcon(92677, fiend)
		end
	end
	function mod:ObnoxiousPhaseShift(...)
		--now we track the removal of the buff - its too late to say "soon"
		--self:Message(92677, L["obnoxious_soon"], "Attention", 92677) -- do we really need this?
		local dGUID = select(10, ...)
		FiendCheck(dGUID)
		self:RegisterEvent("UNIT_AURA")
	end
end

do
	local pestered = GetSpellInfo(92685)
	local obnoxious = GetSpellInfo(92677)
	function mod:UNIT_AURA(_, unit)
		if UnitDebuff(unit, pestered) then
			if unit == "player" then
				self:Say(92677, CL["say"]:format(obnoxious))
			end
			self:TargetMessage(92677, obnoxious, UnitName(unit), "Attention", 92677, "Long")
			self:UnregisterEvent("UNIT_AURA")
		end
	end
end

function mod:Tracking(player, spellId, _, _, spellName)
	if UnitIsUnit(player, "player") then
		self:Say(78092, CL["say"]:format((GetSpellInfo(78092))))
		self:FlashShake(78092)
	end
	self:TargetMessage(78092, spellName, player, "Personal", spellId, "Alarm")
	self:PrimaryIcon(78092, player)
end

function mod:SonicBreath(_, spellId)
	self:Bar(78075, sonicBreath, 42-16, spellId)
end

function mod:SearingFlame(_, spellId, _, _, spellName)
	self:Message(77840, spellName, "Important", spellId, "Alert")
	mod:Bar(77840, searingFlame, 155, 77840)
	mod:DelayedMessage(77840, 145, L["searing_soon"], "Attention", 77840)
end

do
	local function groundPhase(self)
		mod:Message("ground_phase", L["ground_phase"], "Attention", 61882) -- Earthquake Icon
		mod:Bar("air_phase", L["air_phase"], 110, 5740) -- Rain of Fire Icon -- probably not correct! only know that 90sec was too low
		mod:Bar(78075, sonicBreath, 25-5, 78075)
		-- XXX need a good trigger for ground phase start to make this even more accurate
		
		if self:Difficulty() > 2 then
			self:Bar(92677, obnoxiousFiend.." #1", 10, 92677)
			self:DelayedMessage(92677, 5, L["obnoxious_soon"], "Attention", 92677)
			self:ScheduleTimer(function(i) 
				self:Bar(92677, obnoxiousFiend.." #"..i, 85, 92677); 
				self:DelayedMessage(92677, 80, L["obnoxious_soon"], "Attention", 92677) 
			end, 10, 2)
		end
		-- assume #2 as that one from pull!
	end
	function mod:AirPhase()
		self:SendMessage("BigWigs_StopBar", self, sonicBreath)
		--too late for this message - we are already 5sec in phase.
		--self:Message("air_phase", L["air_phase"], "Attention", 5740) -- Rain of Fire Icon
		self:Bar("ground_phase", L["ground_phase"], 30+5, 61882) -- Earthquake Icon
		self:ScheduleTimer(groundPhase, 30+5,self)
	end
end

