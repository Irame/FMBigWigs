--------------------------------------------------------------------------------
-- Module Declaration
--

local mod, CL = BigWigs:NewBoss("Shannox", 800, 195)
if not mod then return end
mod:RegisterEnableMob(53691, 53695, 53694) --Shannox, Rageface, Riplimb

--------------------------------------------------------------------------------
-- Localization
--

local L = mod:NewLocale("enUS", true)
if L then
	L.safe = "%s safe"
	L.wary_dog = "%s is Wary!"
	L.crystal_trap = "Crystal Trap"
	L.chaseother = "%s chases"
	L.chaseyou = "%s chases YOU!"
	
	L.chase = "Rageface targeting (Only Heroic)"
	L.chase_desc = "Warn whom Rageface chases after leaving a Crystal Trap."
	L.chase_icon = 34487
	L.traps_header = "Traps"
	L.immolation = "Immolation Trap on Dog"
	L.immolation_desc = "Alert when Rageface or Riplimb steps on an Immolation Trap, gaining the 'Wary' buff."
	L.immolation_icon = 100167
	L.immolationyou = "Immolation Trap under You"
	L.immolationyou_desc = "Alert when an Immolation Trap is summoned under you."
	L.immolationyou_icon = 99838
	L.immolationyou_message = "Immolation Trap"
	L.crystal = "Crystal Trap"
	L.crystal_desc = "Warn whom Shannox casts a Crystal Trap under."
	L.crystal_icon = 99836
end
L = mod:GetLocale()

--------------------------------------------------------------------------------
-- Initialization
--

function mod:GetOptions()
	return {
		100002, {100129, "ICON"}, "berserk", "bosskill", "chase",
		100167, {"immolationyou", "FLASHSHAKE"}, {"crystal", "SAY", "FLASHSHAKE"},
	}, {
		[100002] = "general",
		[100167] = L["traps_header"],
	}
end

function mod:OnBossEnable()
	--self:Log("SPELL_AURA_APPLIED", "WaryDog", 101208, 101209, 101210, 99838)
	self:Log("SPELL_AURA_APPLIED", "WaryDog", 100167, 101215, 101216, 101217) --10, 25, 10HM, 25HM
	self:Log("SPELL_AURA_REMOVED", "TrapRemoved", 99837)
	
	self:Log("SPELL_CAST_SUCCESS", "FaceRage", 99947) --99945 is the "charge"
	self:Log("SPELL_AURA_REMOVED", "FaceRageRemoved", 99947)
	
	self:Log("SPELL_CAST_START", "HurlSpear", 100002)
	self:Log("SPELL_CAST_START", "MagmaRupture", 99840, 101205, 101206, 101207)
	
	
	--self:Log("SPELL_SUMMON", "Traps", 99836, 99839)
	--99836, 99839
	self:Log("SPELL_CAST_SUCCESS", "ThrowTraps", 99836, 99839)

	self:RegisterEvent("INSTANCE_ENCOUNTER_ENGAGE_UNIT", "CheckBossStatus")

	self:Death("Win", 53691)
end

function mod:OnEngage(diff)
	self:Bar(100002, (GetSpellInfo(100002)), 23-3, 100002) -- Hurl Spear
	self:Berserk(600)
end

--------------------------------------------------------------------------------
-- Event Handlers
--

do--Rageface after trapped
	local count = 0
	local function CheckTarget(unitID)
		count = count + 1
		local name = UnitName(unitID.."target")
		if name then
			local rageface = UnitName(unitID)
			if UnitIsUnit("player", name) then
				mod:Message(100167, L["chaseyou"]:format(rageface), "Personal", 34487, "Alert")
			else
				mod:TargetMessage(100167, L["chaseother"]:format(rageface), name, "Important", 34487)
			end
		elseif count < 6 then
			mod:ScheduleTimer(CheckTarget, 0.2,unitID)
		end
	end
	
	function mod:TrapRemoved(unit, spellId, _, _, spellName, _, _, _, _, dGUID)
		if self:Difficulty() > 2 and self.GetMobIdByGUID[dGUID] == 53695 then
			local Rageface, i = "boss1", 1
			while self.GetMobIdByGUID[UnitGUID(Rageface)] ~= 53695 do
				i = i+1
				Rageface = "boss"..i
				if i>3 then return end --no Rageface, sorry
			end
			count = 0
			CheckTarget(Rageface)
		end
	end
end

do-- Traps
	local size = { 1587.4999389648438,1058.3332824707031 }
	
	local function getDist(target)
		SetMapToCurrentZone() --for map positions
		local srcX, srcY = GetPlayerMapPosition("player")		
		local unitX, unitY = GetPlayerMapPosition(target)
		local dx = (unitX - srcX) * size[1]
		local dy = (unitY - srcY) * size[2]
		
		return (dx * dx + dy * dy) ^ 0.5
	end
						
	function mod:ThrowTraps(player,spellId , _, _, spellName, _, _, _, _, dGUID)
		if player then
			if UnitIsUnit("player", player) then
				if spellId == 99836 then
					self:FlashShake("crystal")
					self:Say("crystal", CL["say"]:format(L["crystal_trap"]))
					self:TargetMessage("crystal", L["crystal_trap"], player, "Urgent", spellId, "Alarm")
				else
					self:FlashShake("immolationyou")
					self:LocalMessage("immolationyou", CL["underyou"]:format(L["immolationyou_message"]), "Personal", spellId, "Alarm")
				end
			elseif getDist(player) < 3 then
				if spellId == 99836 then
					self:FlashShake("crystal")
					self:TargetMessage("crystal", L["crystal_trap"], UnitName("player"), "Urgent", spellId, "Alarm") --fake target
				else
					self:FlashShake("immolationyou")
					self:LocalMessage("immolationyou", CL["underyou"]:format(L["immolationyou_message"]), "Personal", spellId, "Alarm")
				end
			elseif spellId == 99836 then
				self:TargetMessage("crystal", L["crystal_trap"], player, "Urgent", spellId, "Alarm")
			end
		end
	end
end

function mod:WaryDog(unit, spellId, _, _, spellName, _, _, _, _, dGUID)
	-- We use the Immolation Trap IDs as we only want to warn for Wary after a
	-- Immolation Trap not a Crystal Trap, which also applies Wary.
	local creatureId = self.GetMobIdByGUID[dGUID]
	if creatureId == 53695 or creatureId == 53694 then
		self:Message(100167, L["wary_dog"]:format(unit), "Attention", 100167)
		self:Bar(100167, L["wary_dog"]:format(unit), self:Difficulty() > 2 and 25 or 15, 100167)
	end
end

function mod:HurlSpear(_, _, _, _, spellName)
	self:Message(100002, spellName, "Attention", 100002, "Info")
	self:Bar(100002, spellName, 42.1, 100002)
end

function mod:MagmaRupture(_, _, _, _, spellName)
	self:Message(100002, spellName, "Attention", 99840, "Info")
	self:Bar(100002, spellName, 16.5, 99840)
end

do
	handler = nil
	function mod:FaceRage(player, _, _, _, spellName)
		self:TargetMessage(100129, spellName, player, "Important", 100129, "Alert")
		self:PrimaryIcon(100129, player)
		
		self:Bar(100129,spellName,30,100129)
		
		--sometimes he seems to skip one. Start another 30sec Timer for the upcoming FaceRage
		if handler then self:CancelTimer(handler, true) end
		handler = self:ScheduleTimer(function(n) 
			self:Bar(100129,n,30,100129) 
		end, 30, spellName)
	end
end

function mod:FaceRageRemoved(player)
	self:Message(100129, L["safe"]:format(player), "Positive", 100129)
	self:PrimaryIcon(100129)
end

