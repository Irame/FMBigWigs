if not GetNumGroupMembers then return end
--------------------------------------------------------------------------------
-- Module Declaration
--

local mod, CL = BigWigs:NewBoss("Blade Lord Ta'yak", 897, 744)
if not mod then return end
mod:RegisterEnableMob(62543)

--------------------------------------------------------------------------------
-- Locals
--

local unseenStrike = (GetSpellInfo(122994))

--------------------------------------------------------------------------------
-- Localization
--

local L = mod:NewLocale("enUS", true)
if L then
	L.unseenstrike_cone = "Cone of Unseen Strike"

	L.phase2_warning = "Phase 2 soon!"

	L.assault = "Overwhelming Assault"
	L.assault_desc = "Tank alert only. The attack leaves the target's defenses exposed, increasing the target's damage taken when an Overwhelming Assault lands by 100% for 45 sec."
	L.assault_icon = 123474
end
L = mod:GetLocale()
L.assault = L.assault.." "..INLINE_TANK_ICON

--------------------------------------------------------------------------------
-- Initialization
--

function mod:GetOptions()
	return {
		{ "ej:6346", "ICON" }, "assault", "proximity", 122842, "ej:6350",
		"berserk", "bosskill",
	}, {
		["ej:6346"] = "general",
	}
end

function mod:OnBossEnable()
	self:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
	self:Log("SPELL_CAST_SUCCESS", "Assault", 123474)

	self:RegisterEvent("INSTANCE_ENCOUNTER_ENGAGE_UNIT", "CheckBossStatus")

	self:Death("Win", 62543)
end

function mod:OnEngage(diff)
	self:OpenProximity(8)
	self:RegisterEvent("UNIT_HEALTH_FREQUENT")
	self:Bar("ej:6346", unseenStrike, 30, 122994)
end

--------------------------------------------------------------------------------
-- Event Handlers
--

do
	local function warnStrike(spellName)
		local player = UnitName("boss1target") -- because this event does not supply destName with UNIT_SPELLCAST_SUCCEEDED
		mod:TargetMessage("ej:6346", spellName, player, "Urgent", 122994, "Alarm")
		mod:PrimaryIcon("ej:6346", player)
	end
	function mod:UNIT_SPELLCAST_SUCCEEDED(_, unit, spellName, _, _, spellId)
		if unit == "boss1" then
			if spellId == 122949 then
				self:Bar("ej:6346", L["unseenstrike_cone"], 5, 122994)
				self:Bar("ej:6346", spellName, 60, 122994)
				self:ScheduleTimer(warnStrike, 0.5, spellName) -- still faster than using boss emote (0.4 needs testing)
			elseif spellId == 122839 then -- correct spellId -- tempest slash
				self:Bar(122842, "~"..spellName, 15.6, 122842)
				-- don't think this needs a message
			end
		end
	end
end

function mod:Assault(player, spellId, _, _, spellName)
	if self:Tank() then -- uncommented for debugging purpose
		-- ability has a 21sec CD might want to add a bar for that too
		self:Bar("assault", ("%s (%s)"):format(player, spellName), 45, spellId)
		self:TargetMessage("assault", spellName, player, "Urgent", spellId)
	end
end

function mod:UNIT_HEALTH_FREQUENT(_, unitId)
	if unitId == "boss1" then
		local hp = UnitHealth(unitId) / UnitHealthMax(unitId) * 100
		if hp < 25 then -- phase starts at 20
			self:Message("ej:6350", L["phase2_warning"], "Positive", 106996, "Info") -- the corrent icon
			self:UnregisterEvent("UNIT_HEALTH_FREQUENT")
		end
	end
end
