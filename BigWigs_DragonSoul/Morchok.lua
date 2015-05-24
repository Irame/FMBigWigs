--------------------------------------------------------------------------------
-- Module Declaration
--

local mod, CL = BigWigs:NewBoss("Morchok", 824, 311)
if not mod then return end
mod:RegisterEnableMob(55265)

local kohcrom = EJ_GetSectionInfo(4262)
local crystalCount, stompCount = 0, 1
local nextCrystal, nextStomp = 0,0

--------------------------------------------------------------------------------
-- Localization
--

local L = mod:NewLocale("enUS", true)
if L then
	L.engage_trigger = "You seek to halt an avalanche. I will bury you."

	L.stomp_boss, L.stomp_boss_desc = EJ_GetSectionInfo(3879)
	L.stomp_boss_icon = 103414
	L.crystal_boss, L.crystal_boss_desc = EJ_GetSectionInfo(3876)
	L.crystal_boss_icon = 103640

	L.stomp_add, L.stomp_add_desc =  EJ_GetSectionInfo(3879)
	L.stomp_add_icon = "INV_DataCrystal12"--103414
	L.crystal_add, L.crystal_add_desc = EJ_GetSectionInfo(3876)
	L.crystal_add_icon = "Spell_Nature_AbolishMagic"--103640

	L.crush = "Crush Armor"
	L.crush_desc = "Tank alert only. Count the stacks of crush armor and show a duration bar."
	L.crush_icon = 103687
	L.crush_message = "%2$dx Crush on %1$s"

	L.blood = "Black Blood"

	L.explosion = "Explosion"
	L.crystal = "Crystal"
end
L = mod:GetLocale()
L.crush = L.crush.." "..INLINE_TANK_ICON

--------------------------------------------------------------------------------
-- Initialization
--

function mod:GetOptions()
	return {
		"stomp_boss", "crystal_boss",
		"stomp_add", "crystal_add",
		109017, {103851, "FLASHSHAKE"}, "crush", 103846, "berserk", "bosskill",
	}, {
		stomp_boss = self.displayName,
		stomp_add = kohcrom,
		[109017] = "general",
	}
end

function mod:OnBossEnable()
	--Heroic
	self:Log("SPELL_SUMMON", "SummonKohcrom", 109017)

	--Normal
	self:RegisterEvent("UNIT_SPELLCAST_CHANNEL_STOP", "BloodOver")
	self:Log("SPELL_CAST_START", "Stomp", 108571, 109033, 109034, 103414)
	self:Log("SPELL_CAST_START", "BlackBlood", 103851)
	self:Log("SPELL_AURA_APPLIED", "Furious", 103846)
	self:Log("SPELL_AURA_APPLIED", "Crush", 103687)
	self:Log("SPELL_AURA_APPLIED_DOSE", "Crush", 103687)
	self:Log("SPELL_AURA_APPLIED", "BlackBloodStacks", 110287, 110288, 103785, 108570)
	self:Log("SPELL_AURA_APPLIED_DOSE", "BlackBloodStacks", 110287, 110288, 103785, 108570)
	self:Log("SPELL_SUMMON", "ResonatingCrystal", 103639)

	self:RegisterEvent("INSTANCE_ENCOUNTER_ENGAGE_UNIT", "CheckBossStatus")

	self:Death("Win", 55265)
end

function mod:OnEngage(diff)
	self:Berserk(420) -- confirmed
	self:Bar("stomp_boss", L["stomp_boss"], 11+1, L["stomp_boss_icon"])
	self:Bar("crystal_boss", L["crystal"], 16+3, L["crystal_boss_icon"])
	local now = GetTime()
	nextCrystal,nextStomp = now+16+3, now+11+1
	
	self:Bar(103851, L["blood"], 56+2+3, 103851)
	crystalCount, stompCount = 1, 2 --0 ,1
end

--------------------------------------------------------------------------------
-- Event Handlers
--

function mod:SummonKohcrom(_, spellId, _, _, spellName)
	self:SendMessage("BigWigs_StopBar", self, L["crystal"])
	self:SendMessage("BigWigs_StopBar", self, L["stomp_boss"].." CD")
	self:SendMessage("BigWigs_StopBar", self, L["stomp_boss"])
	
	self:Message(109017, spellName, "Positive", spellId)
	local offset = (self:Difficulty() == 3) and 6 or 5
	if nextStomp > nextCrystal then
		--crystal -> 5.5
		--stomp -> 12
		self:Bar("stomp_boss", self.displayName.." - "..L["stomp_boss"], 12, L["stomp_boss_icon"])
		self:Bar("crystal_boss", self.displayName.." - "..L["crystal"], 5.5, L["crystal_boss_icon"])
		
		self:Bar("stomp_add", kohcrom.." - "..L["stomp_boss"], 12+offset, L["stomp_add_icon"])
		self:Bar("crystal_add", kohcrom.." - "..L["crystal"], 5.5+offset, L["crystal_add_icon"])
		
	else
		--crystal -> 15
		--stomp -> 6
		self:Bar("stomp_boss", self.displayName.." - "..L["stomp_boss"], 6, L["stomp_boss_icon"])
		self:Bar("crystal_boss", self.displayName.." - "..L["crystal"], 15, L["crystal_boss_icon"])
		
		self:Bar("stomp_add", kohcrom.." - "..L["stomp_boss"], 6+offset, L["stomp_add_icon"])
		self:Bar("crystal_add", kohcrom.." - "..L["crystal"], 15+offset, L["crystal_add_icon"])
	end
end

local function AfterBloodTimers(self, add)
	self:Bar(103851, L["blood"], 75+add, 103851)
	if self:Difficulty() > 2 and UnitExists("boss2") then
		local crystal, stomp = 26+add, 19+add
		local offset = (self:Difficulty() == 3) and 6 or 5
		
		self:Bar("stomp_boss", self.displayName.." - "..L["stomp_boss"], stomp, L["stomp_boss_icon"])
		self:Bar("crystal_boss", self.displayName.." - "..L["crystal"], crystal, L["crystal_boss_icon"])
		
		self:Bar("stomp_add", kohcrom.." - "..L["stomp_boss"], stomp+offset, L["stomp_add_icon"])
		self:Bar("crystal_add", kohcrom.." - "..L["crystal"], crystal+14+offset, L["crystal_add_icon"])
	else
		local now = GetTime();
		self:Bar("stomp_boss", L["stomp_boss"], 5+14+add, L["stomp_boss_icon"])
		nextStomp = now+5+14+add
		self:Bar("crystal_boss", L["crystal"], 29-2+add, L["crystal_boss_icon"])
		nextCrystal = now+29-2+add
	end
end
-- I know it's ugly to use this, but if we were to start bars at :BlackBlood then we are subject to BlackBlood duration changes
function mod:BloodOver(_, unit, _, _, _, spellId)
	if unit == "boss1" and spellId == 103851 then
		AfterBloodTimers(self, 0)
	end
end

function mod:Stomp(_, spellId, source, _, spellName)
	if self:Difficulty() > 2 and UnitExists("boss2") then -- Check if heroic and if kohncrom has spawned yet.
		local offset = (self:Difficulty() == 3) and 6 or 5
		if source == kohcrom then
			self:Message("stomp_add", source.." - "..spellName, "Important", L["stomp_add_icon"])
			if stompCount < 4 then
				self:Bar("stomp_add", source.." - "..spellName, 12, L["stomp_add_icon"])
			end
		else -- Since we trigger bars off morchok casts, we gotta make sure kohcrom isn't caster to avoid bad timers.
			self:Message("stomp_boss", source.." - "..spellName, "Important", L["stomp_boss_icon"])
			if stompCount < 4 then
				self:Bar("stomp_add", kohcrom.." - "..spellName, offset, L["stomp_add_icon"])
				self:Bar("stomp_boss", source.." - "..spellName.." CD", 12, L["stomp_boss_icon"])
			end
			stompCount = stompCount + 1
		end
	else -- Not heroic, or Kohcrom isn't out yet, just do normal bar.
		if stompCount < 4 then
			nextStomp = GetTime()+12
			self:Bar("stomp_boss", spellName.." CD", 12, L["stomp_boss_icon"])
			self:Message("stomp_boss", spellName, "Important", L["stomp_boss_icon"])
			stompCount = stompCount + 1
		end
	end
end

function mod:Furious(_, spellId, _, _, spellName)
	self:Message(103846, spellName, "Positive", spellId) -- Positive?
end

do
	local prev = 0
	function mod:BlackBlood(_, spellId, _, _, spellName)
		local t = GetTime()
		if t-prev > 5 then
			prev = t
			crystalCount, stompCount = 0, 1
			self:Message(103851, spellName, "Personal", spellId, "Long") -- not really personal, but we tend to associate personal with fns
			self:Bar(103851, CL["cast"]:format(L["blood"]), 17, spellId)
			AfterBloodTimers(self, 17)
		end
	end
end

do
	local prev = 0
	function mod:BlackBloodStacks(player, spellId, _, _, spellName)
		local t = GetTime()
		if t-prev > 2 and UnitIsUnit("player", player) then
			prev = t
			self:FlashShake(103851)
			self:LocalMessage(103851, CL["underyou"]:format(L["blood"]), "Personal", spellId, "Long")
		end
	end
end

function mod:ResonatingCrystal(_, spellId, source, _, spellName)
	if source == self.displayName then crystalCount = crystalCount + 1 end -- Only increment count off morchok casts.
	if self:Difficulty() > 2 and UnitExists("boss2") then
		if source == kohcrom then
			self:Message("crystal_add", source.." - "..L["crystal"], "Urgent", L["crystal_add_icon"], "Alarm")
			self:Bar("crystal_add", source.." - "..(L["explosion"]), 12, L["crystal_add_icon"])
		else
			self:Message("crystal_boss", source.." - "..L["crystal"], "Urgent", L["crystal_boss_icon"], "Alarm")
			self:Bar("crystal_boss", source.." - "..(L["explosion"]), 12, L["crystal_boss_icon"])
		end
	else
		self:Message("crystal_boss", L["crystal"], "Urgent", L["crystal_boss_icon"], "Alarm")
		self:Bar("crystal_boss", L["explosion"], 12, L["crystal_boss_icon"])
		nextCrystal = GetTime()+14
	end
end

function mod:Crush(player, spellId, _, _, spellName, buffStack)
	if self:Tank() then
		buffStack = buffStack or 1
		self:SendMessage("BigWigs_StopBar", self, L["crush_message"]:format(player, buffStack - 1))
		self:Bar("crush", L["crush_message"]:format(player, buffStack), 20, spellId)
		self:LocalMessage("crush", L["crush_message"], "Urgent", spellId, buffStack > 2 and "Info" or nil, player, buffStack)
	end
end

