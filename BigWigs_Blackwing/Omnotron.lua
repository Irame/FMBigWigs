--------------------------------------------------------------------------------
-- Module Declaration
--

local mod, CL = BigWigs:NewBoss("Omnotron Defense System", 754, 169)
if not mod then return end
mod:RegisterEnableMob(42166, 42179, 42178, 42180, 49226) -- Arcanotron, Electron, Magmatron, Toxitron, Lord Victor Nefarius

--------------------------------------------------------------------------------
-- Localization
--

local L = mod:NewLocale("enUS", true)
if L then
	L.nef = "Lord Victor Nefarius"
	L.nef_desc = "Warnings for Lord Victor Nefarius abilities."

	L.pool = "Pool Explosion"

	L.switch = "Switch"
	L.switch_desc = "Warning for Switches."
	L.switch_message = "%s %s"

	L.next_switch = "Next activation"

	L.nef_next = "~Ability buff"

	L.acquiring_target = "Acquiring target"

	L.bomb_message = "Blob chasing YOU!"
	L.cloud_message = "Cloud under YOU!"
	L.protocol_message = "Blobs incoming!"

	L.iconomnotron = "Icon on active boss"
	L.iconomnotron_desc = "Place the primary raid icon on the active boss (requires promoted or leader)."
end
L = mod:GetLocale()

--------------------------------------------------------------------------------
-- Initialization
--

function mod:GetOptions()
	return {
		{79501, "ICON", "FLASHSHAKE"}, 79023, 
		{79888, "ICON", "FLASHSHAKE", "PROXIMITY"},
		{80161, "FLASHSHAKE"}, {80157, "FLASHSHAKE", "SAY"}, 80053, {80094, "FLASHSHAKE", "WHISPER"},
		"nef", 91849, 91879, {92048, "ICON"}, 92023, {"switch", "ICON"},
		"berserk", "bosskill"
	}, {
		[79501] = "ej:3207", -- Electron
		[79888] = "ej:3201", -- Magmatron
		[80161] = "ej:3208", -- Toxitron
		nef = "heroic",
		switch = "general"
	}
end

function mod:OnBossEnable()
	self:Log("SPELL_AURA_APPLIED", "AcquiringTarget", 79501, 92035, 92036, 92037)
	self:Log("SPELL_CAST_START","Incinerate",79023, 91519, 91520, 91521)
	
	self:Log("SPELL_CAST_START", "Grip", 91849)
	self:Log("SPELL_CAST_SUCCESS", "PoolExplosion", 91857)

	self:Log("SPELL_CAST_SUCCESS", "PoisonProtocol", 91513, 80053, 91514, 91515)
	self:Log("SPELL_AURA_APPLIED", "Fixate", 80094)

	self:Log("SPELL_AURA_APPLIED", "ChemicalCloud", 80161, 91480, 91479, 91473, 91471) --91471 for 25norm, not sure about the rest, obviously 1 is wron
	
	self:Log("SPELL_CAST_SUCCESS", "ChemicalCloudCast", 80157)
	self:Log("SPELL_AURA_APPLIED", "ShadowInfusion", 92048)
	self:Log("SPELL_AURA_APPLIED", "EncasingShadows", 92023)
	self:Log("SPELL_AURA_APPLIED", "LightningConductor", 79888, 91433, 91431, 91432)
	self:Log("SPELL_AURA_REMOVED", "LightningConductorRemoved", 79888, 91433, 91431, 91432)
	self:Log("SPELL_AURA_APPLIED", "Switch", 78740, 95016, 95017, 95018)

	self:RegisterEvent("INSTANCE_ENCOUNTER_ENGAGE_UNIT", "CheckBossStatus")

	self:Death("Deaths", 42166, 42179, 42178, 42180)
end

local countUsedSpells = {}

function mod:OnEngage(diff)
	if diff > 2 then
		countUsedSpells = {}
		self:Berserk(600)
	end
end


--------------------------------------------------------------------------------
-- Event Handlers
--

do
	local function checkTarget(sGUID)
		for i = 1, 4 do
			local bossId = ("boss%d"):format(i)
			if UnitGUID(bossId) == sGUID and UnitIsUnit(bossId.."target", "player") then
				mod:FlashShake(80157)
				mod:Say(80157, CL["say"]:format((GetSpellInfo(80157))))
				break
			end
		end
	end
	function mod:ChemicalCloudCast(...)
		local sGUID = select(11, ...)
		self:ScheduleTimer(checkTarget, 0.1, sGUID)
		
		countUsedSpells.ChemicalCloud = countUsedSpells.ChemicalCloud or 0
		countUsedSpells.ChemicalCloud = countUsedSpells.ChemicalCloud + 1
		if countUsedSpells.ChemicalCloud < 2 then
			self:Bar(80161, "Chemical Cloud", 30, 80161) --appears to be the same on NH/HC
		end
	end
end

function mod:PoolExplosion()
	self:Message(91879, L["pool"], "Urgent", 91879)
	self:Bar("nef", L["nef_next"], 35, 69005)
	self:Bar(91879, L["pool"], 8, 91879)
end

function mod:GolemActivated(unit,unitGUID)
	local bossID = self.GetMobIdByGUID[unitGUID]
	if bossID == 42178 then --Magmatron 42178
		countUsedSpells.AcquiringTarget = 0
		self:Bar(79501, L.acquiring_target, 24, 79501)
		countUsedSpells.Incinerate = 0
		self:Bar(79023, "Incinerate", 10.5, 79023)
	elseif bossID == 42179 then --Elektron 42179
		countUsedSpells.LightningConductor = 0
		self:Bar(79888, "Lightning Conductor", 13, 79888) --same Timer NH/HC
	elseif bossID == 42180 then --Toxitron 42180
		countUsedSpells.PoisonProtocol = 0
		countUsedSpells.ChemicalCloud = 0
		if self:Difficulty() > 2 then --HC
			self:Bar(91513, "Poison Protocol", 15, 91513) 
			self:Bar(80161, "Chemical Cloud", 25, 80161) 
		else --NH
			self:Bar(91513, "Poison Protocol", 21, 91513)
			self:Bar(80161, "Chemical Cloud", 11, 80161)
		end
	elseif bossID == 42166 then --Arkanotron 42166
	end
end

do
	local prev = 0
	function mod:Switch(unit, spellId, _, _, spellName, _, _, _, _, dGUID)
		local timer = self:Difficulty() > 2 and 27 or 42
		local t = GetTime()
		if (t - prev) > timer then
			prev = t
			self:Bar("switch", L["next_switch"], timer+3, spellId)
			self:Message("switch", L["switch_message"]:format(unit, spellName), "Positive", spellId, "Long")
			--Using dGUID to avoid issues with names appearing as "UNKNOWN" for a second or so
			for i = 1, 4 do
				local bossId = ("boss%d"):format(i)
				if UnitGUID(bossId) == dGUID then
					self:GolemActivated(unit,dGUID)
					self:PrimaryIcon("switch", bossId)
					break
				end
			end
		end
	end
end

function mod:Grip(_, spellId, _, _, spellName)
	self:Message(91849, spellName, "Urgent", 91849)
	self:Bar("nef", L["nef_next"], 35, 69005)
end

function mod:ShadowInfusion(player, spellId, _, _, spellName)
	if UnitIsUnit(player, "player") then
		self:FlashShake(92048)
	end
	self:TargetMessage(92048, spellName, player, "Urgent", spellId)
	self:Bar("nef", L["nef_next"], 35, 69005)
	self:SecondaryIcon(92048, player)
end

function mod:EncasingShadows(player, spellId, _, _, spellName)
	self:TargetMessage(92023, spellName, player, "Urgent", spellId)
	self:Bar("nef", L["nef_next"], 35, 69005)
end

function mod:Incinerate(player, spellId)
	countUsedSpells.Incinerate = countUsedSpells.Incinerate or 0
	countUsedSpells.Incinerate = countUsedSpells.Incinerate + 1
	if countUsedSpells.Incinerate < 2 or countUsedSpells.Incinerate < 3 and self:Difficulty() < 3 then
		self:Bar(79501, "Incinerate", 48, 79501)
	end
end

function mod:AcquiringTarget(player, spellId)
	if UnitIsUnit(player, "player") then
		self:FlashShake(79501)
	end
	self:TargetMessage(79501, L["acquiring_target"], player, "Urgent", spellId, "Alarm")
	self:SecondaryIcon(79501, player)
	
	countUsedSpells.AcquiringTarget = countUsedSpells.AcquiringTarget or 0
	countUsedSpells.AcquiringTarget = countUsedSpells.AcquiringTarget + 1
	if countUsedSpells.AcquiringTarget < 2 then
		self:Bar(79501, L.acquiring_target, 27, 79501)
	end
end

function mod:Fixate(player, spellId, _, _, spellName)
	if UnitIsUnit(player, "player") then
		self:FlashShake(80094)
		self:LocalMessage(80094, L["bomb_message"], "Personal", spellId, "Alarm")
	else
		self:Whisper(80094, player, L["bomb_message"], true)
	end
end

function mod:LightningConductor(player, spellId, _, _, spellName)
	if UnitIsUnit(player, "player") then
		self:FlashShake(79888)
		self:OpenProximity(8, 79888) --assumed
	else
		self:OpenProximity(8, 79888, player)
	end
	self:TargetMessage(79888, spellName, player, "Attention", spellId, "Alarm")
	self:SecondaryIcon(79888, player)
	
	countUsedSpells.LightningConductor = countUsedSpells.LightningConductor or 0
	countUsedSpells.LightningConductor = countUsedSpells.LightningConductor + 1
	
	if self:Difficulty() > 2 then
	--HC
		if countUsedSpells.LightningConductor < 3 then
			self:Bar(79888, "Lightning Conductor", 20, 79888)
		end
	else
	--NH
		if countUsedSpells.LightningConductor < 4 then
			self:Bar(79888, "Lightning Conductor", 25, 79888)
		end
	end
end

function mod:LightningConductorRemoved(player)
	self:CloseProximity(79888)
end

function mod:PoisonProtocol(_, spellId, _, _, spellName)
	self:Bar(80053, spellName, 45, spellId)
	self:Message(80053, L["protocol_message"], "Important", spellId, "Alert")
		
	countUsedSpells.PoisonProtocol = countUsedSpells.PoisonProtocol or 0
	countUsedSpells.PoisonProtocol = countUsedSpells.PoisonProtocol + 1
	if countUsedSpells.PoisonProtocol < 2 then --both modes 2 casts.
		if self:Difficulty() > 2 then --HC
			self:Bar(91513, "Poison Protocol", 25, 91513)
		else --NH
			self:Bar(91513, "Poison Protocol", 45, 91513)
		end
	end
end

do
	local last = 0
	function mod:ChemicalCloud(player, spellId)
		local time = GetTime()
		if (time - last) > 2 then
			last = time
			if UnitIsUnit(player, "player") then
				self:LocalMessage(80161, L["cloud_message"], "Personal", spellId, "Info")
				self:FlashShake(80161)
			end
		end
	end
end

do
	local deaths = 0
	function mod:Deaths()
		--Prevent the module from re-enabling in the second or so after 1 boss dies
		deaths = deaths + 1
		if deaths == 4 then
			self:Win()
		end
	end
end

