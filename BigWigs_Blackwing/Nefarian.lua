--------------------------------------------------------------------------------
-- Module Declaration
--

local mod, CL = BigWigs:NewBoss("Nefarian", 754, 174)
if not mod then return end
mod:RegisterEnableMob(41270, 41376)

--------------------------------------------------------------------------------
-- Locals
--

local phase, deadAdds, shadowBlazeTimer = 1, 0, 35
local cinderTargets = mod:NewTargetList()
local powerTargets = mod:NewTargetList()
local shadowblaze = GetSpellInfo(81007)
local phase3warned = false
local shadowblazeHandle, lastBlaze = nil, 0
local dominion = GetSpellInfo(79318)

--------------------------------------------------------------------------------
-- Localization
--

local L = mod:NewLocale("enUS", true)
if L then
	L.phase = "Phases"
	L.phase_desc = "Warnings for the Phase changes."

	L.discharge_bar = "~Discharge"

	L.phase_two_trigger = "Curse you, mortals! Such a callous disregard for one's possessions must be met with extreme force!"

	L.phase_three_trigger = "I have tried to be an accommodating host"

	L.crackle_trigger = "electricity crackling leaves the air!" --The air crackles with electricity!
	L.crackle_message = "Electrocute soon!"

	L.shadowblaze_trigger = "Flesh turns to ash!"
	L.shadowblaze_message = "Fire under YOU!"

	L.onyxia_power_message = "Explosion soon!"

	L.chromatic_prototype = "Chromatic Prototype" -- 3 adds name
	
	L.interrupt = GetSpellInfo(101430)
	L.interrupt_desc = "Interrupt warning for "..GetSpellInfo(101430)
end
L = mod:GetLocale()

--------------------------------------------------------------------------------
-- Initialization
--

function mod:GetOptions()
	return {
		77939, 78999, 81272, {81007, "FLASHSHAKE"},
		{79339, "FLASHSHAKE", "SAY", "PROXIMITY"}, {79318, "FLASHSHAKE"}, "berserk",
		"phase", "bosskill", "interrupt"
	}, {
		[77939] = "ej:3283", -- Onyxia
		[78999] = "normal",
		[79339] = "heroic",
		phase = "general"
	}
end

function mod:OnBossEnable()
	self:Yell("PhaseTwo", L["phase_two_trigger"])
	self:Yell("PhaseThree", L["phase_three_trigger"])
	self:Yell("Shadowblaze", L["shadowblaze_trigger"])

	--Not bad enough that there is no cast trigger, there's also over 9 thousand Id's
	self:Log("SPELL_DAMAGE", "LightningDischarge", "*")
	self:Log("SPELL_MISSED", "LightningDischarge", "*")
	self:Log("SPELL_CAST_SUCCESS", "LightningDischarge", "*")

	self:Log("SPELL_AURA_APPLIED", "ExplosiveCindersApplied", 79339)
	self:Log("SPELL_AURA_REMOVED", "ExplosiveCindersRemoved", 79339)
	self:Log("SPELL_DAMAGE", "PersonalShadowBlaze", 81007, 94085, 94086, 94087)

	self:Log("SPELL_AURA_APPLIED", "Dominion", 79318)--only know 10HM spell - maybe another for 25HM
	
	self:Emote("Electrocute", L["crackle_trigger"])
	
	self:IterruptWarn("interrupt", "melee", 101430, 101431, 101432, 80734) --Blast Nova

	self:RegisterEvent("INSTANCE_ENCOUNTER_ENGAGE_UNIT", "CheckBossStatus")

	self:Death("Deaths", 41376, 41948)
end

function mod:OnEngage(diff)
	self:Berserk(630) -- is it really?
	self:Bar(77939, L["discharge_bar"], 30, 77939)
	phase, deadAdds, shadowBlazeTimer = 1, 0, 20
	phase3warned = false
	self:RegisterEvent("UNIT_POWER")
	shadowblazeHandle, lastBlaze = nil, 0
	if self:Difficulty() > 2 then
		self:Bar(79318, dominion, 35, 79318) --needs to be tested
	end
end

--------------------------------------------------------------------------------
-- Event Handlers
--

do
	local prev = 0
	local discharge = GetSpellInfo(77939)
	function mod:LightningDischarge(_, spellId, _, _, spellName)
		if spellName ~= discharge then return end
		local t = GetTime()
		if (t - prev) > 10 then
			prev = t
			self:Bar(77939, L["discharge_bar"], 30, spellId)
		end
	end
end

do
	local prev = 0
	function mod:PersonalShadowBlaze(player, spellId)
		local t = GetTime()
		if (t - prev) > 1 and UnitIsUnit(player, "player") then
			prev = t
			self:LocalMessage(81007, L["shadowblaze_message"], "Personal", spellId, "Info")
			self:FlashShake(81007)
		end
	end
end

function mod:Electrocute()
	self:Message(81272, L["crackle_message"], "Urgent", 81272, "Alert")
	self:Bar(81272, (GetSpellInfo(81272)), 3, 81272)
end

function mod:Deaths(mobId)
	if mobId == 41948 then
		deadAdds = deadAdds + 1
		if self:Difficulty() > 2 and not phase3warned then
			self:SendMessage("BigWigs_StopBar", self, CL["phase"]:format(phase))
			phase = 3
			self:Message("phase", CL["phase"]:format(phase), "Attention", 81007)
			mod:Bar(79318, dominion, 24.5, 79318)
			phase3warned = true
		end
		if deadAdds == 3 and not phase3warned then
			self:SendMessage("BigWigs_StopBar", self, CL["phase"]:format(phase))
			phase = 3
			self:Message("phase", CL["phase"]:format(phase), "Attention", 81007)
			phase3warned = true
		end
	elseif mobId == 41376 then
		self:Win()
	end
end

function mod:PhaseTwo()
	phase = 2
	self:SendMessage("BigWigs_StopBar", self, dominion)
	self:Message("phase", CL["phase"]:format(phase), "Attention", 78621)
	local d = self:Difficulty()
	if d == 4 then
		-- Heroic 25man (diff 4) probably 4 minutes
		self:Bar("phase", CL["phase"]:format(phase), 240, 78621) -- random guessed number
	else
		-- Normal 10man (diff 1) probably 3 minutes
		-- Normal 25man (diff 2) confirmed 3 minutes
		self:Bar("phase", CL["phase"]:format(phase), 180, 78621)
	end
	-- XXX Heroic 10man (diff 3) - no idea.
end

function mod:Shadowblaze()
	mod:Message(81007, shadowblaze, "Important", 81007, "Alarm")
	mod:Bar(81007, shadowblaze, shadowBlazeTimer, 81007)
	if shadowBlazeTimer > 10 then
		shadowBlazeTimer = shadowBlazeTimer - 5
	end
end

--Why so complicated? (On Frostmourne Nefarian yells every time he casts Shadowblaze)
--[[
local function nextBlaze()
	local diff = mod:Difficulty()
	if shadowBlazeTimer > 10 and diff > 2 then
		shadowBlazeTimer = shadowBlazeTimer - 5
	elseif shadowBlazeTimer > 15 and diff < 3 then
		shadowBlazeTimer = shadowBlazeTimer - 5
	end
	mod:Message(81007, shadowblaze, "Important", 81007, "Alarm")
	mod:Bar(81007, shadowblaze, shadowBlazeTimer, 81007)
	lastBlaze = GetTime()
	shadowblazeHandle = mod:ScheduleTimer(nextBlaze, shadowBlazeTimer)
end

function mod:ShadowblazeCorrection()
	self:CancelTimer(shadowblazeHandle, true)
	if (GetTime() - lastBlaze) <= 3 then
		shadowblazeHandle = mod:ScheduleTimer(nextBlaze, shadowBlazeTimer)
	elseif (GetTime() - lastBlaze) >= 6 then
		nextBlaze()
	end
	lastBlaze = GetTime()
end
]]--

function mod:PhaseThree()
	self:SendMessage("BigWigs_StopBar", self, CL["phase"]:format(phase))
	if not phase3warned then
		phase = 3
		self:Message("phase", CL["phase"]:format(phase), "Attention", 78621)
		phase3warned = true
	end
	self:Bar(81007, shadowblaze, 21, 81007)
	--shadowblazeHandle = self:ScheduleTimer(nextBlaze, 12)
end

do
	local scheduled, playerIsTarget = nil, nil
	local function cinderWarn(spellName)
		if not playerIsTarget then
			mod:OpenProximity(10, 79339, cinderTargets)
		end
		mod:TargetMessage(79339, spellName, cinderTargets, "Urgent", 79339, "Info")
		scheduled = nil
	end
	function mod:ExplosiveCindersApplied(player, spellId, _, _, spellName)
		cinderTargets[#cinderTargets + 1] = player
		if UnitIsUnit(player, "player") then
			playerIsTarget = true
			self:FlashShake(79339)
			self:Say(79339, CL["say"]:format(spellName))
			self:Bar(79339, spellName, 8, spellId)
			self:OpenProximity(10, 79339) -- assumed
		end
		if not scheduled then
			scheduled = true
			self:ScheduleTimer(cinderWarn, 0.3, spellName)
		end
	end
end

do
	local scheduled = nil
	local function powerWarn(spellName)
		mod:TargetMessage(79318, spellName, powerTargets, "Urgent", 79318, "Info")
		mod:Bar(79318, spellName, 15.2--[[+0.3 sheduleTimer]], 79318) -- ~15-16sec
		scheduled = nil
	end

	function mod:Dominion(player, spellId, _, _, spellName)
		powerTargets[#powerTargets + 1] = player
		if UnitIsUnit(player, "player") then
			self:FlashShake(79318)
		end
		if not scheduled then
			scheduled = true
			self:ScheduleTimer(powerWarn, 0.3, spellName)
		end
	end
end
	
function mod:ExplosiveCindersRemoved(player)
	self:CloseProximity(79339)
end

do
	local onyxia = EJ_GetSectionInfo(3283)
	function mod:UNIT_POWER()
		if UnitIsUnit("boss1", onyxia) then
			local power = UnitPower("boss1", ALTERNATE_POWER_INDEX)
			if power > 80 then
				self:Message(78999, L["onyxia_power_message"], "Attention", 78999)
				self:UnregisterEvent("UNIT_POWER")
			end
		end
	end
end

