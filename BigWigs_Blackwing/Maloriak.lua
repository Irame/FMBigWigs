--------------------------------------------------------------------------------
-- Module Declaration
--

local mod, CL = BigWigs:NewBoss("Maloriak", 754, 173)
if not mod then return end
mod:RegisterEnableMob(41378)

--------------------------------------------------------------------------------
-- Locals
--

local aberrations = 18
local phaseCounter = 0
local addCastCount = 0
local arcaneStormCount = 0
local chillTargets = mod:NewTargetList()
local isChilled, currentPhase, startPhase = nil, nil, nil
local scorchingBlast = "~"..GetSpellInfo(77679)
local flashFreeze = "~"..GetSpellInfo(77699)
local debilitatingSlime = (GetSpellInfo(77615))
local releaseAberration = GetSpellInfo(77569)
local arcaneStorm = GetSpellInfo(77896)

--------------------------------------------------------------------------------
-- Localization
--

local L = mod:NewLocale("enUS", true)
if L then
	--heroic
	L.sludge = "Dark Sludge"
	L.sludge_desc = "Warning for when you stand in Dark Sludge."
	L.sludge_message = "Sludge on YOU!"

	--normal
	L.final_phase = "Final phase"
	L.final_phase_soon = "Final phase soon!"

	L.release_aberration_message = "%d adds left!"
	L.release_all = "%d adds released!"

	L.phase = "Phase"
	L.phase_desc = "Warning for phase changes."
	L.next_phase = "Next phase"
	L.green_phase_bar = "Green phase"

	L.engage_trigger = "Nothing goes to waste...There can be no disruptions! Mustnt keep the master waiting, mustnt fail again!"
	
	L.red_phase_trigger = "Mix and stir, apply heat..."
	L.red_phase_emote_trigger = "red"
	L.red_phase = "|cFFFF0000Red|r phase"
	L.blue_phase_trigger = "How well does the mortal shell handle extreme temperature change? Must find out! For science!"
	L.blue_phase_emote_trigger = "blue"
	L.blue_phase = "|cFF809FFEBlue|r phase"
	L.green_phase_trigger = "This one's a little unstable, but what's progress without failure?"
	L.green_phase_emote_trigger = "green"
	L.green_phase = "|cFF33FF00Green|r phase"
	L.dark_phase_trigger = "Your mixtures are weak, Maloriak! They need a bit more... kick!"
	L.dark_phase_emote_trigger = "dark"
	L.dark_phase = "|cFF660099Dark|r phase"
end
L = mod:GetLocale()

--------------------------------------------------------------------------------
-- Initialization
--

function mod:GetOptions()
	return {
		{77699, "ICON", "PROXIMITY"}, {77760, "FLASHSHAKE", "WHISPER", "SAY"},
		{77786, "FLASHSHAKE", "WHISPER", "ICON"}, 77679,
		77615,
		77991, 78194,
		{"sludge", "FLASHSHAKE"},
		"phase", 77912, 77569, 77896, "berserk", "bosskill"
	}, {
		[77699] = L["blue_phase"],
		[77786] = L["red_phase"],
		[77615] = L["green_phase"],
		[77991] = L["final_phase"],
		sludge = "heroic",
		phase = "general"
	}
end

function mod:OnBossEnable()
	--heroic
	self:Log("SPELL_AURA_APPLIED", "DarkSludge", 92987, 92988)
	self:Log("SPELL_PERIODIC_DAMAGE", "DarkSludge", 92987, 92988)

	--normal
	self:Log("SPELL_CAST_START", "ReleaseAberrations", 77569)
	self:Log("SPELL_INTERRUPT", "Interrupt", "*")

	self:Log("SPELL_CAST_SUCCESS", "FlashFreezeTimer", 77699, 92979, 92978, 92980)
	self:Log("SPELL_AURA_APPLIED", "FlashFreeze", 77699, 92979, 92978, 92980)
	self:Log("SPELL_AURA_REMOVED", "FlashFreezeRemoved", 77699, 92979, 92978, 92980)
	self:Log("SPELL_AURA_APPLIED", "BitingChill", 77760)
	self:Log("SPELL_AURA_REMOVED", "BitingChillRemoved", 77760)
	self:Log("SPELL_AURA_APPLIED", "ConsumingFlames", 77786, 92972, 92971, 92973)
	self:Log("SPELL_CAST_SUCCESS", "ScorchingBlast", 77679, 92968, 92969, 92970)
	self:Log("SPELL_AURA_APPLIED", "Remedy", 77912, 92965, 92966, 92967)
	self:Log("SPELL_CAST_START", "ReleaseAll", 77991)
	self:Log("SPELL_CAST_START", "ArcaneStorm", 77896)
	self:Log("SPELL_CAST_START", "Jets", 78194)

	self:RegisterEvent("INSTANCE_ENCOUNTER_ENGAGE_UNIT", "CheckBossStatus")
	self:Yell("Engage", L["engage_trigger"])
	
	-- We keep the emotes in case the group uses Curse of Tongues, in which
	-- case the yells become Demonic.
	self:Emote("Red", L["red_phase_emote_trigger"])
	self:Emote("Blue", L["blue_phase_emote_trigger"])
	self:Emote("Green", L["green_phase_emote_trigger"])
	self:Emote("Dark", L["dark_phase_emote_trigger"])

	-- We keep the yell triggers around because sometimes he does them far ahead
	-- of the emote.
	self:Yell("Red", L["red_phase_trigger"])
	self:Yell("Blue", L["blue_phase_trigger"])
	self:Yell("Green", L["green_phase_trigger"])
	self:Yell("Dark", L["dark_phase_trigger"])
		
	-- Because the Dark Phase is not announced on FM we track the Buff he gains.
	self:Log("SPELL_AURA_APPLIED", "Dark", 92716)

	self:Death("Win", 41378)
end

function mod:OnEngage(diff)
	if diff > 2 then
		self:Bar("phase", L["next_phase"], 16, "INV_ELEMENTAL_PRIMAL_SHADOW")
		self:Berserk(720)
	else
		self:Berserk(420)
	end
	self:OpenProximity(8, 77699)
	aberrations = 18
	phaseCounter = 0
	arcaneStormCount = -1
	addCastCount = -1 --first is "out-of-phase"
	self:Bar(77569,releaseAberration,16,77569) --not confirmed for NM
	isChilled, currentPhase, startPhase = nil, nil, nil
	self:RegisterEvent("UNIT_HEALTH_FREQUENT")
end

--------------------------------------------------------------------------------
-- Event Handlers
--

do
	local last = 0
	function mod:DarkSludge(player, spellId)
		if not UnitIsUnit(player, "player") then return end
		local time = GetTime()
		if (time - last) > 2 then
			last = time
			self:LocalMessage("sludge", L["sludge_message"], "Personal", spellId, "Info")
			self:FlashShake("sludge")
		end
	end
end

local function nextPhase(timeToNext)
	phaseCounter = phaseCounter + 1
	local diff = mod:Difficulty()
	if (diff < 3 and phaseCounter == 2) or (diff > 2 and phaseCounter == 3) then
		mod:Bar("phase", L["green_phase_bar"], timeToNext, "INV_POTION_162")
	else
		mod:Bar("phase", L["next_phase"], timeToNext, "INV_ALCHEMY_ELIXIR_EMPTY")
	end
end

function mod:Red()
	if currentPhase == "red" then return end
	currentPhase = "red"
	if not startPhase then 
		self:Bar(77569,releaseAberration,15,77569) --not confirmed for NM
		startPhase = "red" 
	end
	
	self:SendMessage("BigWigs_StopBar", self, flashFreeze)
	self:Bar(77679, scorchingBlast, 25, 77679)
	self:Message("phase", L["red_phase"], "Positive", "Interface\\Icons\\INV_POTION_24", "Long")
	if not isChilled then
		self:CloseProximity(77699)
	end
	nextPhase(53)
end

function mod:Blue()
	if currentPhase == "blue" then return end
	currentPhase = "blue"
	if not startPhase then 
		self:Bar(77569,releaseAberration,15,77569) --not confirmed for NM
		startPhase = "blue" 
	end
	
	self:SendMessage("BigWigs_StopBar", self, scorchingBlast)
	self:Bar(77699, flashFreeze, 20, 77699)
	self:Message("phase", L["blue_phase"], "Positive", "Interface\\Icons\\INV_POTION_20", "Long")
	self:OpenProximity(8, 77699)
	nextPhase(53)
end

function mod:Green()
	if currentPhase == "green" then return end
	currentPhase = "green"
	self:SendMessage("BigWigs_StopBar", self, scorchingBlast)
	self:SendMessage("BigWigs_StopBar", self, flashFreeze)
	self:Bar(77615, debilitatingSlime, 15, 77615)
	self:Message("phase", L["green_phase"], "Positive", "Interface\\Icons\\INV_POTION_162", "Long")
	if not isChilled then
		self:CloseProximity(77699)
	end
	nextPhase(53)
	
	addCastCount = 0
	-- Make sure to reset after the nextPhase() call, which increments it
	startPhase = nil
	phaseCounter = 0
end

function mod:Dark()
	if currentPhase == "dark" then return end
	currentPhase = "dark"
	addCastCount = 0
	self:CancelArcaneStormTimers()
	self:Message("phase", L["dark_phase"], "Positive", "Interface\\Icons\\INV_ELEMENTAL_PRIMAL_SHADOW", "Long")
	if not isChilled then
		self:CloseProximity(77699)
	end
	nextPhase(100)
end

function mod:FlashFreezeTimer(_, spellId, _, _, spellName)
	self:Bar(77699, flashFreeze, 15, spellId)
end

function mod:FlashFreeze(player, spellId, _, _, spellName)
	self:TargetMessage(77699, spellName, player, "Attention", spellId, "Info")
	self:PrimaryIcon(77699, player)
end

function mod:FlashFreezeRemoved()
	self:PrimaryIcon(77699)
end

function mod:Remedy(unit, spellId, _, _, spellName, _, _, _, _, dGUID)
	if self:GetCID(dGUID) == 41378 then
		self:Message(77912, spellName, "Important", spellId, "Alarm")
	end
end

do
	local handle = nil
	local function release()
		aberrations = aberrations - 3
		mod:Message(77569, L["release_aberration_message"]:format(aberrations), "Important", 688, "Alert") --Summon Imp Icon
	end
	function mod:ReleaseAberrations()
		-- He keeps casting it even if there are no adds left to release...
		if aberrations < 1 then return end
		--cast is 1.95sec with Tongues, plus some latency time
		handle = self:ScheduleTimer(release, 2.1)
		
		addCastCount = addCastCount + 1
		if self:Difficulty > 2 then
		-- 15 15 20 15 15 (Red->Blue); 15 15 20 30 (Blue -> Red)
			if addCastCount < 3 then 
				self:Bar(77569,releaseAberration,15,77569) 
			elseif addCastCount == 3 then 
				self:Bar(77569,releaseAberration,20,77569) 
			elseif addCastCount > 3 then
				if startPhase == "blue" then self:Bar(77569,releaseAberration,30,77569)
				else self:Bar(77569,releaseAberration,15,77569) end
			end
		else --NM
			if addCastCount < 2 or addCastCount < 3 and startPhase == "blue" then
				self:Bar(77569,releaseAberration,15,77569)			
			elseif addCastCount == 3 and startPhase == "blue" then
				self:Bar(77569,releaseAberration,20,77569)
			elseif addCastCount == 4 and startPhase == "blue" then
				self:Bar(77569,releaseAberration,30,77569)
			elseif addCastCount == 2 --[[and startPhase == "red"]] then
				self:Bar(77569,releaseAberration,35,77569)
			elseif addCastCount  < 5 --[[and startPhase == "red"]] then
				self:Bar(77569,releaseAberration,15,77569)
			end
		end
		
		
	end
	function mod:Interrupt(_, _, _, secSpellId)
		if secSpellId ~= 77569 then return end
		-- Someone interrupted release aberrations!
		self:CancelTimer(handle, true)
		handle = nil
	end
end

function mod:ConsumingFlames(player, spellId, _, _, spellName)
	if UnitIsUnit(player, "player") then
		self:FlashShake(77786)
	end
	self:TargetMessage(77786, spellName, player, "Personal", spellId, "Info")
	self:Whisper(77786, player, spellName)
	self:PrimaryIcon(77786, player)
end

function mod:ScorchingBlast(_, spellId, _, _, spellName)
	self:Message(77679, spellName, "Attention", spellId)
	self:Bar(77679, scorchingBlast, 10, 77679)
end

function mod:ReleaseAll(_, spellId)
	if not isChilled then
		self:CloseProximity(77699)
	end
	self:SendMessage("BigWigs_StopBar", self, scorchingBlast)
	self:SendMessage("BigWigs_StopBar", self, flashFreeze)
	self:Message(77991, L["release_all"]:format(aberrations + 2), "Important", spellId, "Alert")
	self:Bar(78194, "~"..GetSpellInfo(78194), 12.5, 78194)
end

do
	local scheduled = nil
	local function chillWarn(spellName)
		mod:TargetMessage(77760, spellName, chillTargets, "Attention", 77760, "Info")
		scheduled = nil
	end
	function mod:BitingChill(player, spellId, _, _, spellName)
		chillTargets[#chillTargets + 1] = player
		if UnitIsUnit(player, "player") then
			self:Say(77760, CL["say"]:format((GetSpellInfo(77760))))
			self:FlashShake(77760)
			isChilled = true
		end
		if not scheduled then
			scheduled = true
			self:ScheduleTimer(chillWarn, 0.3, spellName)
		end
	end
end

function mod:BitingChillRemoved(player)
	if UnitIsUnit(player, "player") then
		isChilled = nil
		if currentPhase ~= "blue" then
			self:CloseProximity(77699)
		end
	end
end

do
	local preRot = {15,15,20,15,15,15,20}
	local rot = {15,15,20}
	
	local times = setmetatable({}, {__index = function(tbl, num)
		local ret
		if num > #preRot then
			local i = (num - #preRot)%(#rot)
			if i == 0 then i = #rot end
			ret = rot[i]
		elseif num == 0 then
			ret = 20
		else
			ret = preRot[num]
		end
		rawset(tbl, num, ret)
		return ret
	end})	
	
	local last
	local filler
	
	local function fill(t)
		mod:Bar(77896,arcaneStorm,t,77896)
		--if did not cancel this timer in 5 sec we assume he skipped one.
		filler = mod:ScheduleTimer(function() arcaneStormCount = arcaneStormCount + 1 end, 5)
	end
	
	function mod:ArcaneStorm(_, spellId, _, _, spellName)
		self:Message(77896, spellName, "Urgent", spellId)
		
		--this happens if he goes into black phase - need to reset "rotation"
		if not last or GetTime()-last > 60 then arcaneStormCount = 0 end
		last = GetTime()
		arcaneStormCount = arcaneStormCount + 1
		local t, t2 = times[arcaneStormCount], times[(arcaneStormCount+1)]
		
		self:CancelArcaneStormTimers()
		self:Bar(77896,arcaneStorm,t,77896)
		filler = self:ScheduleTimer(fill, t, t2) --sometimes he skips one, we need to fill this "hole" up
	end
	
	function mod:CancelArcaneStormTimers()
		self:StopBar(arcaneStorm)
		self:CancelTimer(filler, true)
		filler = nil
	end
end

function mod:Jets(_, spellId, _, _, spellName)
	self:Bar(78194, spellName, 10, spellId)
end

function mod:UNIT_HEALTH_FREQUENT(_, unit)
	if unit ~= "boss1" then return end
	local hp = UnitHealth(unit) / UnitHealthMax(unit) * 100
	if hp < 29 then --Switches at 25%
		self:Message("phase", L["final_phase_soon"], "Positive", 77991, "Info")
		self:UnregisterEvent("UNIT_HEALTH_FREQUENT")
	end
end

