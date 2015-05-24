--------------------------------------------------------------------------------
-- Module Declaration
--

local mod, CL = BigWigs:NewBoss("Madness of Deathwing", 824, 333)
if not mod then return end
-- Thrall, Deathwing, Arm Tentacle, Arm Tentacle, Wing Tentacle, Mutated Corruption
mod:RegisterEnableMob(56103, 56173, 56167, 56846, 56168, 56471)

local hemorrhage = GetSpellInfo(105863)
local cataclysm = GetSpellInfo(106523)
local impale = GetSpellInfo(106400)
local canEnable = true
local curPercent = 100
local paraCount = 0

--------------------------------------------------------------------------------
-- Localization
--

local L = mod:NewLocale("enUS", true)
if L then
	L.engage_trigger = "You have done NOTHING. I will tear your world APART."

	L.impale, L.impale_desc = EJ_GetSectionInfo(4114)
	L.impale_icon = 106400

	L.last_phase = GetSpellInfo(106708)
	L.last_phase_desc = EJ_GetSectionInfo(4046)
	L.last_phase_icon = 106834

	L.bigtentacle, L.bigtentacle_desc = EJ_GetSectionInfo(4112)
	L.bigtentacle_icon = 105563

	L.smalltentacles = EJ_GetSectionInfo(4103)
	-- Copy & Paste from Encounter Journal with correct health percentages (type '/dump EJ_GetSectionInfo(4103)' in the game)
	L.smalltentacles_desc = "At 70% and 40% remaining health the Limb Tentacle sprouts several Blistering Tentacles that are immune to Area of Effect abilities."
	L.smalltentacles_icon = 105444

	L.hemorrhage, L.hemorrhage_desc = EJ_GetSectionInfo(4108)
	L.hemorrhage_icon = "SPELL_FIRE_MOLTENBLOOD"

	L.fragment, L.fragment_desc = EJ_GetSectionInfo(4115)
	L.fragment_icon = 105563

	L.terror, L.terror_desc = EJ_GetSectionInfo(4117)
	L.terror_icon = "ability_tetanus"

	L.bolt_explode = "<Bolt Explodes>"
	L.parasite = "Parasite"
	L.blobs_soon = "%d%% - Congealing Blood soon!"
end
L = mod:GetLocale()

--------------------------------------------------------------------------------
-- Initialization
--

function mod:GetOptions()
	return {
		"bigtentacle", "impale", "smalltentacles", {105651, "FLASHSHAKE"}, "hemorrhage", 106523,
		"last_phase", "fragment", {106794, "FLASHSHAKE"}, "terror",
		{"ej:4347", "FLASHSHAKE", "ICON", "PROXIMITY", "SAY"}, "ej:4351",
		"berserk", "bosskill",
	}, {
		bigtentacle = "ej:4040",
		last_phase = "ej:4046",
		["ej:4347"] = "heroic",
		berserk = "general",
	}
end

function mod:VerifyEnable()
	return canEnable
end

function mod:OnBossEnable()
	--self:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED") --nothing helpful.
	--self:RegisterEvent("INSTANCE_ENCOUNTER_ENGAGE_UNIT", "CheckBossStatus") --Too often Called!
	self:Log("SPELL_CAST_SUCCESS", "ElementiumBolt", 105651)
	self:Log("SPELL_CAST_SUCCESS", "Impale", 106400)
	self:Log("SPELL_CAST_SUCCESS", "AgonizingPain", 106548)
	self:Log("SPELL_CAST_START", "AssaultAspects", 107018)
	self:Log("SPELL_CAST_START", "Cataclysm", 110044, 106523, 110042, 110043)
	self:Log("SPELL_AURA_APPLIED", "LastPhase", 109592, 109593, 106834, 109594) -- 25/LFR, 10HC, 10N, 25HC (Phase 2: Corrupted Blood)
	self:Log("SPELL_AURA_APPLIED", "Shrapnel", 106794, 110141, 110140, 110139) -- 106794 10N, 110141 LFR
	self:Log("SPELL_AURA_APPLIED", "Parasite", 108649)
	self:Log("SPELL_AURA_REMOVED", "ParasiteRemoved", 108649)
	
	self:Emote("SmallTentacles","ability_warrior_bloodnova")
	self:Yell("Engage", L["engage_trigger"])
	self:Log("SPELL_CAST_SUCCESS", "Win", 110063) -- Astral Recall
	self:Death("TentacleKilled", 56471)
end

function mod:OnEngage()
	curPercent = 100
	self:Berserk(900)
end

function mod:OnWin()
	canEnable = false
end

--------------------------------------------------------------------------------
-- Event Handlers
--

function mod:Impale(_, spellId, _, _, spellName)
	self:LocalMessage("impale", spellName, "Urgent", spellId, "Alarm")
	self:Bar("impale", spellName, 35-0.5, spellId)
end

function mod:TentacleKilled()
	self:SendMessage("BigWigs_StopBar", self, (GetSpellInfo(106400)))
	self:SendMessage("BigWigs_StopBar", self, L["parasite"])
end

function mod:SmallTentacles()
	self:Message("smalltentacles", L["smalltentacles"], "Urgent", L["smalltentacles_icon"], "Alarm")
end

do
	local function stillInCombat()
		for i = 1, 4,1 do
			local guid = UnitGUID("boss"..i)
			if guid and mod:GetCID(guid) == 57962 then--Deathwing
				return true
			end
		end
	end
	
	function mod:Fragments()
		if not stillInCombat() then return end
		self:Message("fragment", L["fragment"], "Urgent", L["fragment_icon"], "Alarm")
		self:Bar("fragment", L["fragment"], 90+1, L["fragment_icon"])
		self:ScheduleTimer("Fragments", 90+1)
	end
	function mod:Terrors()
		if not stillInCombat() then return end
		self:Message("terror", L["terror"], "Important", L["terror_icon"])
		self:Bar("terror", L["terror"], 90+1, L["terror_icon"])
		self:ScheduleTimer("Terrors", 90+1)
	end

	function mod:LastPhase(_, spellId)
		self:Message("last_phase", EJ_GetSectionInfo(4046), "Attention", spellId) -- Stage 2: The Last Stand
		self:Bar("fragment", L["fragment"], 3, L["fragment_icon"])
		self:ScheduleTimer("Fragments", 3)
		self:Bar("terror", L["terror"], 39, L["terror_icon"])
		self:ScheduleTimer("Terrors", 39)
		if self:Difficulty() > 2 then
			self:RegisterEvent("UNIT_HEALTH_FREQUENT")
		end
	end
end

local function hemmorageIn(self, t)
	self:Bar("hemorrhage", hemorrhage, t, 105863)
	self:DelayedMessage("hemorrhage", t, hemorrhage, "Urgent", L["hemorrhage_icon"], "Alarm")
end

function mod:AssaultAspects()
	self:ScheduleTimer("UpdatePlatform", 5)

	paraCount = 0
	if curPercent == 100 then
		curPercent = 20
		self:Bar("impale", impale, 22+1+0.5, 106400)
		self:Bar(105651, GetSpellInfo(105651), 40.5+0.5, 105651) -- Elementium Bolt
		if self:Difficulty() > 2 then
			hemmorageIn(self, 55.5)
			self:Bar("ej:4347", L["parasite"], 11, 108649)
		else
			hemmorageIn(self, 85.5+1)
		end
		self:Bar(106523, cataclysm, 117, 106523)
		self:Bar("bigtentacle", L["bigtentacle"], 11.2, L["bigtentacle_icon"])
		self:DelayedMessage("bigtentacle", 11.2, L["bigtentacle"] , "Urgent", L["bigtentacle_icon"], "Alert")
	else
		self:Bar("impale", impale, 27.5+5+1, 106400)
		self:Bar(105651, GetSpellInfo(105651), 55.5+0.5, 105651) -- Elementium Bolt
		if self:Difficulty() > 2 then
			hemmorageIn(self, 70.5)
			self:Bar("ej:4347", L["parasite"], 22.5, 108649)
		else
			hemmorageIn(self, 100.5+2)
		end
		self:Bar(106523, cataclysm, 132, 106523)
		self:Bar("bigtentacle", L["bigtentacle"], 16.7-2, L["bigtentacle_icon"])
		self:DelayedMessage("bigtentacle", 16.7-2+0.5, L["bigtentacle"] , "Urgent", L["bigtentacle_icon"], "Alert")
	end
end

function mod:Cataclysm(_, spellId, _, _, spellName)
	self:Message(106523, spellName, "Attention", spellId)
	self:SendMessage("BigWigs_StopBar", self, spellName)
	self:Bar(106523, CL["cast"]:format(spellName), 60, spellId)
end

function mod:AgonizingPain()
	self:SendMessage("BigWigs_StopBar", self, CL["cast"]:format(cataclysm))
	self:StopBar(GetSpellInfo(105651))-- Elementium Bolt
	self:StopBar(cataclysm)
	self:StopBar(hemorrhage)
	self:CancelDelayedMessage(hemorrhage)
end

function mod:Shrapnel(player, spellId, _, _, spellName)
	if UnitIsUnit(player, "player") then
		local you = CL["you"]:format(spellName)
		self:LocalMessage(106794, you, "Important", spellId, "Long")
		self:FlashShake(106794)
		self:Bar(106794, you, 7, spellId)
	end
end

function mod:Parasite(player, spellId)
	paraCount = paraCount + 1
	self:TargetMessage("ej:4347", L["parasite"], player, "Urgent", spellId)
	self:PrimaryIcon("ej:4347", player)
	if UnitIsUnit(player, "player") then
		self:FlashShake("ej:4347")
		self:Bar("ej:4347", CL["you"]:format(L["parasite"]), 10, spellId)
		self:OpenProximity(10, "ej:4347")
		self:Say("ej:4347", CL["say"]:format(L["parasite"]))
	else
		self:Bar("ej:4347", CL["other"]:format(L["parasite"], player), 10, spellId)
	end
	if paraCount < 2 then
		self:Bar("ej:4347", L["parasite"], 60, 108649)
	end
end

function mod:ParasiteRemoved(player)
	self:PrimaryIcon("ej:4347")
	if UnitIsUnit(player, "player") then
		self:CloseProximity("ej:4347")
	end
end

function mod:UNIT_HEALTH_FREQUENT(_, unitId)
	if unitId == "boss1" then
		local hp = UnitHealth(unitId) / UnitHealthMax(unitId) * 100
		if hp > 14.9 and hp < 16 and curPercent == 20 then
			self:Message("ej:4351", L["blobs_soon"]:format(15), "Positive", "ability_deathwing_bloodcorruption_earth", "Info")
			curPercent = 15
		elseif hp > 9.9 and hp < 11 and curPercent == 15 then
			self:Message("ej:4351", L["blobs_soon"]:format(10), "Positive", "ability_deathwing_bloodcorruption_earth", "Info")
			curPercent = 10
		elseif hp > 4.9 and hp < 6 and curPercent == 10 then
			self:Message("ej:4351", L["blobs_soon"]:format(5), "Positive", "ability_deathwing_bloodcorruption_earth", "Info")
			curPercent = 5
			self:UnregisterEvent("UNIT_HEALTH_FREQUENT")
		end
	end
end

do
	local ref = {[EJ_GetSectionInfo(4133)] = "blue", 
		[EJ_GetSectionInfo(4130)] = "green", 
		[EJ_GetSectionInfo(4127)] = "yellow",
		[EJ_GetSectionInfo(4124)] = "red"}
	local waitNextYell = false
	local currPlatform = "green"
	
	--some Hacky shit, because we do not want to handle a new Frame.
	local old = mod.CHAT_MSG_MONSTER_YELL
	function mod:CHAT_MSG_MONSTER_YELL(...)
		local _, _, sourceName = ...
		if waitNextYell and ref[sourceName] then
			waitNextYell = false --whee we found our Platform!
			currPlatform = ref[sourceName]
		else
			old(self, ...)
		end
	end
		
	function mod:UpdatePlatform()
		waitNextYell = true
	end
	
	local yellowBuff = GetSpellInfo(109624)
	local function flyTime()
		local isSlowed = UnitBuff("player", yellowBuff) and true
		if currPlatform == "red" then
			return isSlowed and 12.5 or 4.25
		elseif currPlatform == "yellow" then
			return 11.75 --cannot be unslowed
		elseif currPlatform == "green" then
			return isSlowed and 11.75 or 3.75
		elseif currPlatform == "blue" then
			return isSlowed and 11.5 or 3.7
		end
		--returns always - currPlatform is always initialized and only gets those variables assigned
	end
	
	function mod:ElementiumBolt(_, spellId, _, _, spellName)
		self:FlashShake(105651)
		self:Message(105651, spellName, "Important", spellId, "Long")
		self:Bar(105651, L["bolt_explode"], flyTime(), spellId)
	end
end
