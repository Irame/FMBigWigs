--------------------------------------------------------------------------------
-- Module Declaration
--

local mod, CL = BigWigs:NewBoss("Lord Rhyolith", 800, 193)
if not mod then return end
mod:RegisterEnableMob(52577, 53087, 52558) -- Left foot, Right Foot, Lord Rhyolith

--------------------------------------------------------------------------------
-- Locales
--

local moltenArmor = GetSpellInfo(98255)
local lastFragments = nil

--------------------------------------------------------------------------------
--  Localization
--

local L = mod:NewLocale("enUS", true)
if L then
	L.armor = "Obsidian Armor"
	L.armor_desc = "Warn when armor stacks are being removed from Rhyolith."
	L.armor_icon = 98632
	L.armor_message = "%d%% armor left"
	L.armor_gone_message = "Armor go bye-bye!"

	L.adds_header = "Adds"
	L.big_add_message = "Big add spawned!"
	L.small_adds_message = "Small adds inc!"

	L.phase2_warning = "Phase 2 soon!"

	L.molten_message = "%dx stacks on boss!"

	L.stomp_message = "Stomp! Stomp! Stomp!"
	L.stomp = "Stomp"
end
L = mod:GetLocale()

--------------------------------------------------------------------------------
-- Initialization
--

function mod:GetOptions()
	return {
		98552, 98136, 98493,
		"armor", 97282, 98255, "ej:2537", 101304, "bosskill"
	}, {
		[98552] = L["adds_header"],
		["armor"] = "general"
	}
end

function mod:OnBossEnable()
	self:Log("SPELL_AURA_APPLIED_DOSE", "MoltenArmor", 98255, 101157)
	self:Log("SPELL_CAST_START", "Stomp", 97282, 100411, 100968, 100969)
	self:Log("SPELL_SUMMON", "Spark", 98552)
	self:Log("SPELL_SUMMON", "Fragments", 100392, 98136)
	self:Log("SPELL_AURA_REMOVED_DOSE", "ObsidianStack", 98632)
	self:Log("SPELL_AURA_REMOVED", "Obsidian", 98632)
	
	self:Log("SPELL_AURA_APPLIED", "Superheated", 101304)
	self:Log("SPELL_AURA_APPLIED_DOSE", "Superheated", 101304)
	
	self:Log("SPELL_CAST_SUCCESS", "VulcanoActivated", 98493)

	self:RegisterEvent("INSTANCE_ENCOUNTER_ENGAGE_UNIT", "CheckBossStatus")

	self:Death("Win", 52558)
end

function mod:OnEngage(diff)
	self:Berserk(diff > 2 and 300 or 360, nil, nil, 101304)
	self:Bar(97282, L["stomp"], 15, 97282)
	self:RegisterEvent("UNIT_HEALTH_FREQUENT")
	lastFragments = GetTime() --30
end

--------------------------------------------------------------------------------
-- Event Handlers
--

do
	local last = 0
	local scheduled = nil
	function mod:VulcanoActivated(_,_,_,_, spellName)
		last = GetTime()
		self:Bar(98493, spellName, 39, 98493)
		
		--if there is no Vulcano, he cant activate one and will skip this activation
		--we assume there will never be two skipped in a row.
		if scheduled then
			self:CancelTimer(scheduled, true)
		end
		self:ScheduleTimer(function(txt) 
			self:Bar(98493, txt, 36, 98493)
		end, 42, spellName)
		
	end
end

function mod:Superheated(player, spellId, _, _, spellName, stack)
	self:Message(101304, spellName..": "..((stack or 1)*10).."%", "Positive", spellId)
end

function mod:Obsidian(_, spellId, _, _, _, _, _, _, _, dGUID)
	if self:GetCID(dGUID) == 52558 then
		self:Message("armor", L["armor_gone_message"], "Positive", spellId)
	end
end

function mod:ObsidianStack(_, spellId, _, _, _, buffStack, _, _, _, dGUID)
	if buffStack % 20 == 0 and self:GetCID(dGUID) == 52558 then -- Only warn every 20
		self:Message("armor", L["armor_message"]:format(buffStack), "Positive", spellId)
	end
end

do
	local scheduled 
	local function sparkIn(t)
		mod:Bar(98136, L["big_add_message"], t, 98136)
		if scheduled then mod:CancelTimer(scheduled, true) end
		scheduled = mod:ScheduleTimer(sparkIn, 35, 25)
	end
	
	function mod:Spark(_, spellId)
		self:Message(98552, L["big_add_message"], "Important", spellId, "Alarm")
		sparkIn(30)
	end
end

do
	local scheduled 
	local function fragmentsIn(t)
		mod:Bar(98136, L["small_adds_message"], t, 98136)
		if scheduled then mod:CancelTimer(scheduled, true) end
		scheduled = mod:ScheduleTimer(fragmentsIn, 35, 25)
	end
	
	function mod:Fragments(_, spellId)
		local t = GetTime()
		if lastFragments and t < (lastFragments + 5) then return end
		lastFragments = t
		self:Message(98136, L["small_adds_message"], "Attention", spellId, "Info")
		fragmentsIn(30)
	end
end

function mod:Stomp(_, spellId, _, _, spellName)
	self:Message(97282, L["stomp_message"], "Urgent",  spellId, "Alert")
	self:Bar(97282, L["stomp"], 30, spellId)
	self:Bar(97282, CL["cast"]:format(L["stomp"]), 3, spellId)
end

function mod:MoltenArmor(player, spellId, _, _, spellName, stack, _, _, _, dGUID)
	if stack > 3 and stack % 2 == 0 and self:GetCID(dGUID) == 52558 then
		self:Message(98255, L["molten_message"]:format(stack), "Attention", spellId)
	end
end

function mod:UNIT_HEALTH_FREQUENT(_, unitId)
	-- Boss frames were jumping around, there are 3 up with the buff on, so one of boss1 or boss2 is bound to exist
	if unitId == "boss1" or unitId == "boss2" then
		local hp = UnitHealth(unitId) / UnitHealthMax(unitId) * 100
		if hp < 30 then -- phase starts at 25
			self:Message("ej:2537", L["phase2_warning"], "Positive", 99846, "Info")
			self:UnregisterEvent("UNIT_HEALTH_FREQUENT")
			local stack = select(4, UnitBuff(unitId, moltenArmor))
			if stack then
				self:Message(98255, L["molten_message"]:format(stack), "Important", 98255, "Alarm")
			end
		end
	end
end

