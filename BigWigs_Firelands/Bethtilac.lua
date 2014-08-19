--------------------------------------------------------------------------------
-- Module Declaration
--

local mod, CL = BigWigs:NewBoss("Beth'tilac", 800, 192)
if not mod then return end
mod:RegisterEnableMob(52498)

--------------------------------------------------------------------------------
-- Locals
--

local droneTbl = {}
local devastateCount = 1
local lastBroodlingTarget = ""
local spiderling = EJ_GetSectionInfo(2778)
local spinner = EJ_GetSectionInfo(2770)
local drone = EJ_GetSectionInfo(2773)

--------------------------------------------------------------------------------
--  Localization
--

local L = mod:NewLocale("enUS", true)
if L then
	L.flare = GetSpellInfo(99859)
	L.flare_desc = "Show a timer bar for AoE flare."
	L.flare_icon = 99859

	L.drone, L.drone_desc = EJ_GetSectionInfo(2773)
	L.drone_icon = "INV_Misc_Head_Nerubian_01"

	L.spinner, L.spinner_desc = EJ_GetSectionInfo(2770)
	L.spinner_icon = "spell_fire_moltenblood"

	L.devastate_message = "Devastate #%d"
	L.drone_bar = "Drone"
	L.drone_message = "Drone incoming!"
	L.kiss_message = "Kiss"
	L.spinner_warn = "Spinners #%d"
end
L = mod:GetLocale()

--------------------------------------------------------------------------------
-- Initialization
--

function mod:GetOptions()
	return {
		{99052, "FLASHSHAKE"}, "drone", "spinner",
		99506, 99497, "flare",
		{99559, "FLASHSHAKE", "WHISPER"}, {99990, "FLASHSHAKE", "SAY"},
		"bosskill"
	}, {
		[99052] = "ej:2764",
		[99506] = "ej:2782",
		[99559] = "heroic",
		bosskill = "general"
	}
end

function mod:OnBossEnable()
	self:Log("SPELL_DAMAGE", "BroodlingWatcher", "*")
	self:Log("SPELL_MISS", "BroodlingWatcher", "*")

	self:Log("SPELL_CAST_SUCCESS", "DroneCleave", 99463, 100121, 100832, 100833)
	self:Log("SPELL_CAST_SUCCESS", "DroneSpit", 98471, 100826, 100827, 100828)
	
	self:Log("SPELL_AURA_APPLIED", "Fixate", 99526)
	self:Log("SPELL_AURA_APPLIED", "FixateDrone", 99559)
	self:Log("SPELL_AURA_APPLIED", "Frenzy", 99497)
	self:Log("SPELL_AURA_APPLIED", "Kiss", 99506)
	self:Log("SPELL_CAST_START", "Devastate", 99052)
	self:Log("SPELL_CAST_SUCCESS", "Flare", 99859, 100935, 100936, 100649)

	self:RegisterEvent("INSTANCE_ENCOUNTER_ENGAGE_UNIT", "CheckBossStatus")

	--self:Death("Win", 52498)
	--Beth won't die, but there is always someone killing her! - FUCK LOGIC
	self:Log("PARTY_KILL", "Win", 52498)
end

local function spiderlingIn(t)
	mod:Bar("spinner", spiderling, t, "INV_Trinket_Naxxramas04")
	mod:DelayedMessage("spinner", t, spiderling, "Positive", "INV_Trinket_Naxxramas04")
end

local function spinnerIn(t)
	mod:Bar("spinner", spinner, t, L["spinner_icon"])
	mod:DelayedMessage("spinner", t, spinner, "Positive", L["spinner_icon"])
	
	mod:Bar("spinner", spinner.." #2", t+10, L["spinner_icon"])
	
	mod:Bar("spinner", spinner.." #3", t+19, L["spinner_icon"])
end

function mod:OnEngage(diff)
	droneTbl = {}
	devastateCount = 1
	lastBroodlingTarget = ""
	local devastate = L["devastate_message"]:format(1)
	self:Message(99052, CL["custom_start_s"]:format(self.displayName, devastate, 80), "Positive", "inv_misc_monsterspidercarapace_01")
	self:Bar(99052, devastate, 80+3, 99052)
	self:CancelTimer(scheduled, true)
	
	mod:Bar("drone", drone, 44, L["drone_icon"])
	
	spinnerIn(13)
	
	spiderlingIn(12)
	self:ScheduleTimer(spiderlingIn, 12,31)
	self:ScheduleTimer(spiderlingIn, 43,30)
	
end

--------------------------------------------------------------------------------
-- Event Handlers
--

do
	function mod:DroneSpit(...) --this one is not casted everytime, just if the drone has a target within sight
		local sGUID = select(11,...) --52581
		if self.GetMobIdByGUID[sGUID] ~= 53635 or droneTbl[sGUID] then return end
		droneTbl[sGUID] = true
		self:Bar("drone", "~"..drone, 55-2, L["drone_icon"])
		self:Message("drone", drone, "Attention", L["drone_icon"], "Info")
	end
	
	function mod:DroneCleave(...)
		local sGUID = select(11,...)
		if self.GetMobIdByGUID[sGUID] ~= 53635 or droneTbl[sGUID] then return end
		droneTbl[sGUID] = true
		self:Bar("drone", "~"..drone, 55-6, L["drone_icon"])
	end
	
	function mod:FixateDrone(...)
		local dGUID = select(10,...)
		if droneTbl[dGUID] then return end
		droneTbl[dGUID] = true
		self:Bar("drone", "~"..drone, 55-15, L["drone_icon"])
	end
end

do
	local burst = GetSpellInfo(99990)

	function mod:BroodlingWatcher()
		if self:Difficulty() < 3 then return end
		local broodling = self:GetUnitIdByGUID(53745)
		if broodling and UnitExists(broodling.."target") and UnitExists(lastBroodlingTarget) then
			if UnitIsUnit(broodling.."target", lastBroodlingTarget) then return end
			lastBroodlingTarget = UnitName(broodling.."target")
			self:TargetMessage(99990, burst, lastBroodlingTarget, "Important", 99990, "Alert")
			if UnitIsUnit(lastBroodlingTarget, "player") then
				self:FlashShake(99990)
				self:Say(99990, CL["say"]:format(burst))
			end
		end
	end
end

function mod:Fixate(player, spellId, _, _, spellName)
	if not UnitIsPlayer(player) then return end --Affects the NPC and a player
	self:TargetMessage(99559, spellName, player, "Attention", spellId, "Alarm")
	if UnitIsUnit("player", player) then
		self:FlashShake(99559)
		self:Whisper(99559, player, CL["you"]:format(spellName))
	end
end

function mod:Frenzy()
	self:CancelAllTimers()
	self:StopBar("~"..drone)
	self:Bar(99506, L["kiss_message"], 10, 99506)
end

function mod:Kiss(player, spellId, _, _, spellName)
	self:TargetMessage(99506, L["kiss_message"], player, "Urgent", spellId)
	self:Bar(99506, L["kiss_message"], 32, spellId)
	-- We play the sound manually because TargetMessage strips it unless the target is the player
	self:PlaySound(99506, "Info")
end

function mod:Devastate(_, spellId)
	local name = GetSpellInfo(100048) --Fiery Web Silk
	local hasDebuff = UnitDebuff("player", name)
	if hasDebuff then
		local devastate = L["devastate_message"]:format(devastateCount)
		self:Message(99052, devastate, "Important", spellId, "Long")
		self:Bar(99052, CL["cast"]:format(devastate), 8, spellId)
		self:FlashShake(99052)
	else
		self:Message(99052, L["devastate_message"]:format(devastateCount), "Attention", spellId)
	end
	devastateCount = devastateCount + 1
	-- This timer is only accurate if you dont fail with the Drones
	-- Might need to use the bosses power bar or something to adjust this
	if devastateCount > 3 then 
		self:Bar(99506, L["kiss_message"], 25, 99506)
		self:DelayedMessage(99497,8, CL["phase"]:format(2), "Positive", 99497, "Alarm")
		return 
	end
	self:Bar(99052, L["devastate_message"]:format(devastateCount), 90, spellId)
	
	spiderlingIn(20)
	self:ScheduleTimer(spiderlingIn, 20,31)
	self:ScheduleTimer(spiderlingIn, 51,30)
	
	spinnerIn(16)
end

function mod:Flare(_, spellId, _, _, spellName)
	self:Bar("flare", spellName, 6, spellId)
end

