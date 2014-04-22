--------------------------------------------------------------------------------
-- Module Declaration
--

local mod, CL = BigWigs:NewBoss("Ascendant Council", 758, 158)
if not mod then return end
mod:RegisterEnableMob(43686, 43687, 43688, 43689, 43735) --Ignacious, Feludius, Arion, Terrastra, Elementium Monstrosity

--------------------------------------------------------------------------------
-- Locals
--

local lrTargets, gcTargets = mod:NewTargetList(), mod:NewTargetList()
local glaciate = GetSpellInfo(82746)
local quake, thundershock, hardenSkin = GetSpellInfo(83565), GetSpellInfo(83067), GetSpellInfo(83718)
local gravityCrush = GetSpellInfo(84948)
local crushMarked = false
local timeLeft = 8
local triggerCount = 0
local first = nil
local lastLastPhase = 0

--------------------------------------------------------------------------------
-- Localization
--

local L = mod:NewLocale("enUS", true)
if L then
	L.static_overload_say = "Overload on ME!"
	L.gravity_core_say = "Gravity on ME!"
	L.frost_beacon_say = "Frozen Orb on ME!"
	L.health_report = "%s at %d%%, phase change soon!"
	L.switch = "Switch"
	L.switch_desc = "Warning for boss switches."

	L.shield_up_message = "Shield is UP!"
	L.shield_down_message = "Shield is DOWN!"
	L.shield_bar = "Shield"

	L.switch_trigger = "Enough of this foolishness!" --"We will handle them!" FM-Style.

	L.thundershock_quake_soon = "%s in 10sec!"

	--FM yells this on caststart - noneed
	L.quake_trigger = "The ground beneath you rumbles ominously..."
	L.thundershock_trigger = "The surrounding air crackles with energy..."

	L.thundershock_quake_spam = "%s in %d"

	L.last_phase_trigger = "An impressive display..."
end
L = mod:GetLocale()

--------------------------------------------------------------------------------
-- Initialization
--

function mod:GetOptions()
	return {
		-- Ignacious
		82631, {82660, "FLASHSHAKE"},
		-- Feludius
		82746, {82665, "FLASHSHAKE"}, 82762,
		-- Arion
		83067, {83099, "SAY", "FLASHSHAKE", "PROXIMITY"},
		-- Terrastra
		83565, 83718,
		-- Monstrosity
		{84948, "ICON"},
		{92480, "PROXIMITY"},
		-- Heroic
		{92067, "FLASHSHAKE", "SAY", "ICON", "PROXIMITY"},
		{92075, "FLASHSHAKE", "SAY", "ICON"},
		{92307, "FLASHSHAKE", "SAY", "ICON", "WHISPER"},
		-- General
		"switch", "bosskill"
	}, {
		[82631] = "ej:3118", -- Ignacious
		[82746] = "ej:3110", -- Feludius
		[83067] = "ej:3123", -- Arion
		[83565] = "ej:3125", -- Terrastra
		[84948] = "ej:3145", -- Elementium Monstrosity
		[92067] = "heroic"
	}
end

function mod:OnBossEnable()
	--heroic
	self:Log("SPELL_AURA_APPLIED", "StaticOverload", 92067)
	self:Log("SPELL_AURA_REMOVED", "StaticOverloadRemoved", 92067)
	self:Log("SPELL_AURA_APPLIED", "GravityCore", 92075)
	self:Log("SPELL_AURA_REMOVED", "GravityCoreRemoved", 92075)
	self:Log("SPELL_AURA_APPLIED", "FrostBeacon", 92307)

	--normal
	self:Log("SPELL_AURA_APPLIED", "LightningRodApplied", 83099)
	self:Log("SPELL_AURA_REMOVED", "LightningRodRemoved", 83099)

	--Shield
	self:Log("SPELL_CAST_START", "FlameShield", 82631, 92513, 92512, 92514)
	self:Log("SPELL_AURA_REMOVED", "FlameShieldRemoved", 82631, 92513, 92512, 92514)

	self:Log("SPELL_CAST_START", "HardenSkinStart", 92541, 92542, 92543, 83718)
	self:Log("SPELL_CAST_START", "Glaciate", 82746, 92507, 92506, 92508)
	self:Log("SPELL_AURA_APPLIED", "Waterlogged", 82762)
	self:Log("SPELL_CAST_SUCCESS", "HeartofIce", 82665)
	self:Log("SPELL_CAST_SUCCESS", "BurningBlood", 82660)
	self:Log("SPELL_AURA_APPLIED", "GravityCrush", 84948, 92486, 92487, 92488)

	self:Yell("Switch", L["switch_trigger"])

	self:Log("SPELL_CAST_START", "Quake", 83565, 92544, 92545, 92546)
	self:Log("SPELL_CAST_START", "Thundershock", 83067, 92469, 92470, 92471)

	--self:Emote("QuakeTrigger", L["quake_trigger"])
	--self:Emote("ThundershockTrigger", L["thundershock_trigger"])

	self:RegisterEvent("INSTANCE_ENCOUNTER_ENGAGE_UNIT", "CheckBossStatus")

	self:Yell("LastPhase", L["last_phase_trigger"])

	self:Death("Win", 43735) -- Elementium Monstrosity
end

function mod:OnEngage(diff)
	if GetTime() - lastLastPhase < 30 then
		self:Bar(84948, gravityCrush, 26, 84948)
		self:OpenProximity(10, 92480)
	else
		if diff > 2 then
			self:OpenProximity(10, 92067)
		end

		self:Bar(82631, L["shield_bar"], 34, 82631)
		self:Bar(82746, glaciate, 30, 82746)

		triggerCount = 0
		first = nil
		crushMarked = false
		self:RegisterEvent("UNIT_HEALTH_FREQUENT")
	end
end

--------------------------------------------------------------------------------
-- Event Handlers
--

do
	local scheduled, playerIsTarget = nil, nil
	local function lrWarn(spellName)
		if not playerIsTarget then
			mod:OpenProximity(10, 83099, lrTargets)
		end
		mod:TargetMessage(83099, spellName, lrTargets, "Important", 83099, "Alert")
		scheduled, playerIsTarget = nil, nil
	end
	function mod:LightningRodApplied(player, _, _, _, spellName)
		lrTargets[#lrTargets + 1] = player
		if not scheduled then
			scheduled = true
			self:ScheduleTimer(lrWarn, 0.3, spellName)
		end
		if UnitIsUnit(player, "player") then
			playerIsTarget = true
			self:Say(83099, CL["say"]:format(spellName))
			self:FlashShake(83099)
			self:OpenProximity(10, 83099)
		end
	end
end

do
	local scheduled = nil
	local function gcWarn(spellName)
		mod:TargetMessage(84948, spellName, gcTargets, "Important", 84948, "Alert")
		scheduled = nil
	end
	local function marked()
		crushMarked = false
	end
	function mod:GravityCrush(player, spellId, _, _, spellName)
		gcTargets[#gcTargets + 1] = player
		if not crushMarked  then
			self:PrimaryIcon(84948, player)
			crushMarked = true
			self:ScheduleTimer(marked, 5)
		end
		if not scheduled then
			scheduled = true
			self:ScheduleTimer(gcWarn, 0.2, spellName)
		end
		self:Bar(84948, spellName, 25, spellId)
	end
end

function mod:LightningRodRemoved(player, spellId)
	if UnitIsUnit(player, "player") then
		if self:Difficulty() > 2 then
			self:OpenProximity(10, 92067)
		else
			self:CloseProximity(83099)
		end
	end
end

function mod:GravityCore(player, spellId, _, _, spellName)
	if UnitIsUnit(player, "player") then
		self:Say(92075, L["gravity_core_say"])
		self:FlashShake(92075)
	end
	self:TargetMessage(92075, spellName, player, "Attention", spellId, "Alarm")
	self:SecondaryIcon(92075, player)
end

function mod:GravityCoreRemoved()
	self:SecondaryIcon(92075)
end

function mod:StaticOverload(player, spellId, _, _, spellName)
	if UnitIsUnit(player, "player") then
		self:Say(92067, L["static_overload_say"])
		self:FlashShake(92067)
	end
	self:TargetMessage(92067, spellName, player, "Attention", spellId, "Alarm")
	self:PrimaryIcon(92067, player)
end

function mod:StaticOverloadRemoved()
	self:PrimaryIcon(92067)
end

do
	local lastOrbGuid
	function mod:FrostBeacon(player, spellId, _, _, spellName, _, _, _, _, _, sGUID)
		if UnitIsUnit(player, "player") then
			self:Say(92307, L["frost_beacon_say"])
			self:FlashShake(92307)
		end
		self:TargetMessage(92307, spellName, player, "Attention", spellId, "Alarm")
		self:Whisper(92307, player, spellName)
		self:PrimaryIcon(92307, player)
		
		if lastOrbGuid ~= sGUID then--we do not want to restart Bar, if the Orb only searched for a new target.
			self:Bar(92307,"frozenOrb",20-2,92307)-- -2 for locationMarkerSpawn
			lastOrbGuid = sGUID
		end
	end
end

do
	local terrastra = EJ_GetSectionInfo(3125)
	local arion = EJ_GetSectionInfo(3123)
	function mod:UNIT_HEALTH_FREQUENT(_, unit)
		if unit == "boss1" or unit == "boss2" or unit == "boss3" or unit == "boss4" then
			local hp = UnitHealth(unit) / UnitHealthMax(unit) * 100
			if not first then
				if hp < 30 then
					self:Message("switch", L["health_report"]:format((UnitName(unit)), hp), "Attention", 26662, "Info")
					first = true
				end
			else
				if hp > 1 and hp < 30 and (UnitName(unit) == arion or UnitName(unit) == terrastra) then
					self:Message("switch", L["health_report"]:format((UnitName(unit)), hp), "Attention", 26662, "Info")
					self:UnregisterEvent("UNIT_HEALTH_FREQUENT")
				end
			end
		end
	end
end

function mod:FlameShield(_, spellId)
	self:Bar(82631, L["shield_bar"], 65, spellId)
	self:Message(82631, L["shield_up_message"], "Important", spellId, "Alert")
end

function mod:FlameShieldRemoved(_, spellId)
	self:Message(82631, L["shield_down_message"], "Important", spellId, "Alert")
end

function mod:HardenSkinStart(_, spellId, _, _, spellName)
	self:Bar(83718, spellName, 44, spellId)
	self:Message(83718, spellName, "Urgent", spellId, "Info")
end

function mod:Glaciate(_, spellId, _, _, spellName)
	self:Bar(82746, spellName, 40, spellId)
	self:Message(82746, spellName, "Attention", spellId, "Alert")
end

function mod:Waterlogged(player, spellId, _, _, spellName)
	if UnitIsUnit(player, "player") then
		self:LocalMessage(82762, spellName, "Personal", spellId, "Long")
	end
end

function mod:HeartofIce(player, spellId, _, _, spellName)
	self:TargetMessage(82665, spellName, player, "Important", spellId)
	if UnitIsUnit(player, "player") then
		self:FlashShake(82665)
	end
end

function mod:BurningBlood(player, spellId, _, _, spellName)
	self:TargetMessage(82660, spellName, player, "Important", spellId)
	if UnitIsUnit(player, "player") then
		self:FlashShake(82660)
	end
end

do
	local currentTimer = nil
	local buff = {[83565] = GetSpellInfo(83500), [83067] = GetSpellInfo(83581)}
	local name = {[83565] = quake, [83067] = thundershock}
	
	local function incoming(id)
		local buffName, _, icon = UnitDebuff("player", buff[id])
		if buffName or timeLeft <= 0 then --do not need to call 0 or lower, 0 is called from Spell itself.
			mod:CancelTimer(currentTimer, true)
			currentTimer = nil
			return
		end
		mod:LocalMessage(id, L["thundershock_quake_spam"]:format(name[id], timeLeft), "Personal", icon, "Info")
		timeLeft = timeLeft - 2
	end
	
	local function quakeSpam()
		--self:Bar(83565, quake, 10, 83565)
		self:Message(83565, L["thundershock_quake_soon"]:format(quake), "Important", 83565, "Info")
		timeLeft = 8
		if currentTimer then 
			self:CancelTimer(currentTimer,true)
			currentTimer = nil 
		end
		currentTimer = self:ScheduleRepeatingTimer(incoming, 2, 83565)
	end

	local function thundershockSpam()
		self:Message(83067, L["thundershock_quake_soon"]:format(thundershock), "Important", 83067, "Info")
		--self:Bar(83067, thundershock, 10, 83067)
		timeLeft = 8
		if currentTimer then 
			self:CancelTimer(currentTimer,true)
			currentTimer = nil 
		end
		currentTimer = self:ScheduleRepeatingTimer(thunderShockIncoming, 2, 83067)
	end
	
	local nextQuake, nextThunder --we want only the next happening thing to be shown, so we save us the times.
	function mod:Quake(_, spellId, _, _, spellName)
		self:Bar(83067, thundershock, nextThunder-GetTime(), 83067)
		
		nextQuake = GetTime() + 72 -- +2 for Casttime
		self:ScheduleTimer(quakeSpam,62)
		self:Message(83565, spellName, "Important", spellId, "Alarm")
		
		self:ScheduleTimer(function(self)
			if not currentTimer then return end
			self:CancelTimer(currentTimer, true)
			currentTimer = nil
		end , 3, self)
	end

	function mod:Thundershock(_, spellId, _, _, spellName)
		self:Bar(83565, quake, nextQuake-GetTime(), 83565)
		
		nextThunder = GetTime() + 72
		self:ScheduleTimer(thundershockSpam,62)
		self:Message(83067, spellName, "Important", spellId, "Alarm")
		
		self:ScheduleTimer(function(self)
			if not currentTimer then return end
			self:CancelTimer(currentTimer, true)
			currentTimer = nil
		end , 3, self)
	end
	
	function mod:Switch()
		triggerCount = triggerCount + 1
		if triggerCount > 1 then return end
		
		self:StopBar(L["shield_bar"])
		self:StopBar(glaciate)
		self:CancelAllTimers()
		
		nextQuake = GetTime() + 32
		self:Bar(83565, quake, 30+2, 83565)--maybe 30 + casttime
		self:ScheduleTimer(quakeSpam, 30+2 -10)
		
		nextThunder = GetTime() + 32+35
		self:ScheduleTimer(thundershockSpam, 32+35 -10)
		
		self:Bar(83718, hardenSkin, 25.5, 83718)
		-- XXX this needs to be delayed
	end
end

function mod:LastPhase()
	lastLastPhase = GetTime()
	self:StopBar(quake)
	self:StopBar(thundershock)
	self:StopBar(hardenSkin)
	self:CancelAllTimers()
	self:Bar(84948, gravityCrush, 43, 84948)
	self:OpenProximity(10, 92480)
	self:UnregisterEvent("UNIT_HEALTH")
end

