--------------------------------------------------------------------------------
-- Module Declaration
--

local mod, CL = BigWigs:NewBoss("Omnotron Defense System", 754, 169)
if not mod then return end
mod:RegisterEnableMob(42166, 42179, 42178, 42180, 49226) -- Arcanotron, Electron, Magmatron, Toxitron, Lord Victor Nefarius

local Incinerate = GetSpellInfo(79023)
local Lightning_Conductor = GetSpellInfo(79888)
local Poison_Protocol = GetSpellInfo(91513)
local Chemical_Cloud = GetSpellInfo(80161)

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
	
	L.incinerate = "Incinerate"
	
	L.acquiring_target = "Acquiring target"

	L.bomb_message = "Blob chasing YOU!"
	L.cloud_message = "Cloud under YOU!"
	L.protocol_message = "Blobs incoming!"

	L.iconomnotron = "Icon on active boss"
	L.iconomnotron_desc = "Place the primary raid icon on the active boss (requires promoted or leader)."
end
L = mod:GetLocale()

--Nef-Timers
local showedTimers = {}--obviously the nef-timers
local hcNef = {}
local lastNefAction = nil
local M, T, E, A = GetSpellInfo(92023),GetSpellInfo(91849),GetSpellInfo(92051),L.pool --"Magmatron","Toxitron","Electron","Arkanotron"
--actual SpellNames are not always "the good alternative"
local nefIconByName = {}
nefIconByName[M], nefIconByName[T], nefIconByName[E], nefIconByName[A] = "Spell_Fire_MoltenBlood",91849,"Spell_Shadow_MindTwisting","Spell_Nature_WispSplode"
--mostly changed icons, because that ones, that are used are pretty unuseful.
local nefOptionRelative = {}
nefOptionRelative[M], nefOptionRelative[T], nefOptionRelative[E], nefOptionRelative[A] = 92023,91849,92048,91879

--------------------------------------------------------------------------------
-- Initialization
--

function mod:GetOptions()
	return {
		{79501, "ICON", "FLASHSHAKE"}, 79023, 
		{79888, "ICON", "FLASHSHAKE", "PROXIMITY"},
		{80161, "FLASHSHAKE"}, {80157, "FLASHSHAKE", "SAY"}, 80053, {80094, "FLASHSHAKE", "WHISPER"},
		91849, 91879, {92048, "ICON"}, 92023, 
		{"switch", "ICON"}, "berserk", "bosskill"
	}, {
		[79501] = "ej:3207", -- Electron
		[79888] = "ej:3201", -- Magmatron
		[80161] = "ej:3208", -- Toxitron
		[91849] = "heroic",
		switch = "general"
	}
end

function mod:OnBossEnable()
	self:Log("SPELL_AURA_APPLIED", "AcquiringTarget", 79501, 92035, 92036, 92037)
	self:Log("SPELL_CAST_START","Incinerate",79023, 91519, 91520, 91521)
	
	self:Log("SPELL_CAST_START", "Grip", 91849)
	self:Log("SPELL_AURA_APPLIED", "PoolExplosion", 91857)
	self:Log("SPELL_AURA_APPLIED", "PoolSpawned", 79628)

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
	lastNefAction = nil
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
		
		countUsedSpells.ChemicalCloud = (countUsedSpells.ChemicalCloud or 0) + 1
		if countUsedSpells.ChemicalCloud < 2 then
			self:Bar(80161, Chemical_Cloud, 30, 80161) --appears to be the same on NH/HC
			hcNef.realtimeAdjust(T,30)
		end
	end
end

function mod:PoolExplosion()
	self:Message(91879, L["pool"], "Urgent", 91879)
	hcNef.spellUsed(A)
end

function mod:PoolSpawned()
	hcNef.realtimeAdjust(A,12,19) --so random - just try it with two spots
end

function mod:GolemActivated(unit,unitGUID)
	local bossID = self.GetMobIdByGUID[unitGUID]
	if bossID == 42178 then --Magmatron 42178
		countUsedSpells.AcquiringTarget = 0
		self:Bar(79501, L.acquiring_target, 20, 79501) -- -4sec(10HC)
		hcNef.realtimeAdjust(M,20,47)
		
		countUsedSpells.Incinerate = 0
		self:Bar(79023, L.incinerate, 10.5, 79023)
		
		if not lastNefAction and self:Difficulty() > 2 then --first Aquiring is Rooted.
			self:Bar(nefOptionRelative[M], M, 20, nefIconByName[M])
			showedTimers[M] = GetTime() + 20
		end
		
	elseif bossID == 42179 then --Elektron 42179
		countUsedSpells.LightningConductor = 0
		self:Bar(79888, Lightning_Conductor, 13, 79888) --same Timer NH/HC
		hcNef.realtimeAdjust(E,13,33,53)
		
		if not lastNefAction and self:Difficulty() > 2 then --first Conductor is a ShadowConductor.
			self:Bar(nefOptionRelative[E], E, 13, nefIconByName[E])
			showedTimers[E] = GetTime() + 13
		end
		
	elseif bossID == 42180 then --Toxitron 42180
		countUsedSpells.PoisonProtocol = 0
		countUsedSpells.ChemicalCloud = 0
		if self:Difficulty() > 2 then --HC
			self:Bar(91513, Poison_Protocol, 15, 91513) 
			self:Bar(80161, Chemical_Cloud, 25, 80161)
			hcNef.realtimeAdjust(T,25,55)
		else --NH
			self:Bar(91513, Poison_Protocol, 21, 91513)
			self:Bar(80161, Chemical_Cloud, 11, 80161)
		end
		
		if not lastNefAction and self:Difficulty() > 2 then --Currently Omnotron cannot start with Toxitron, but we will assume it would be the first Chemical Cloud.
			self:Bar(nefOptionRelative[T], T, 25, nefIconByName[T])
			showedTimers[T] = GetTime() + 25
		end
		
	elseif bossID == 42166 then --Arkanotron 42166
			--16sec Pool#1 +12/+19 for explo = 28/35
			--46sec Pool#2 +12/+19 for explo = 58/65
		--try realTimeAdjust - pretty sure those wont work as good as the others do.
		hcNef.realtimeAdjust(A, 28, 35, 58, 65)
		
		if not lastNefAction and self:Difficulty() > 2 then --this one is a little bit tricky because its related to how fast arcanotron is kicked
			self:Bar(nefOptionRelative[A], A, 27, nefIconByName[A])
			showedTimers[A] = GetTime() + 27
		end
	
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
	hcNef.spellUsed(T)
end

function mod:ShadowInfusion(player, spellId, _, _, spellName)
	if UnitIsUnit(player, "player") then
		self:FlashShake(92048)
	end
	self:TargetMessage(92048, spellName, player, "Urgent", spellId)
	self:SecondaryIcon(92048, player)
	hcNef.spellUsed(E)
end

function mod:EncasingShadows(player, spellId, _, _, spellName)
	self:TargetMessage(92023, spellName, player, "Urgent", spellId)
	hcNef.spellUsed(M)
end

function mod:Incinerate(player, spellId)

	countUsedSpells.Incinerate = (countUsedSpells.Incinerate or 0) + 1
	local diff = self:Difficulty()
	local casted = countUsedSpells.Incinerate
	if casted < 3 and diff < 3 then --normal
		if casted < 2 then
			self:Bar(79501, L.incinerate, 41, 79501) --scnd in ~41-42sec
		else
			self:Bar(79501, L.incinerate, 35, 79501) --thrd in ~35 sec
		end
	elseif casted < 2 then --heroic (only tested in 10man)
		self:Bar(79501, L.incinerate, 48, 79501) --only 2
	end
end

function mod:AcquiringTarget(player, spellId)
	if UnitIsUnit(player, "player") then
		self:FlashShake(79501)
	end
	self:TargetMessage(79501, L["acquiring_target"], player, "Urgent", spellId, "Alarm")
	self:SecondaryIcon(79501, player)
	
	countUsedSpells.AcquiringTarget = (countUsedSpells.AcquiringTarget or 0) + 1
	if countUsedSpells.AcquiringTarget < 2 then
		self:Bar(79501, L.acquiring_target, 27, 79501)
		hcNef.realtimeAdjust(M,27)
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
	
	countUsedSpells.LightningConductor = (countUsedSpells.LightningConductor or 0) + 1
	
	if self:Difficulty() > 2 then
	--HC
		if countUsedSpells.LightningConductor < 3 then
			self:Bar(79888, Lightning_Conductor, 20, 79888)
			hcNef.realtimeAdjust(E,20)
		end
	else
	--NH
		if countUsedSpells.LightningConductor < 4 then
			self:Bar(79888, Lightning_Conductor, 25, 79888)
		end
	end
end

function mod:LightningConductorRemoved(player)
	self:CloseProximity(79888)
end

function mod:PoisonProtocol(_, spellId, _, _, spellName)
	self:Bar(80053, spellName, 45, spellId)
	self:Message(80053, L["protocol_message"], "Important", spellId, "Alert")
		
	countUsedSpells.PoisonProtocol = (countUsedSpells.PoisonProtocol or 0) + 1
	if countUsedSpells.PoisonProtocol < 2 then --both modes 2 casts.
		if self:Difficulty() > 2 then --HC
			self:Bar(91513, Poison_Protocol, 25, 91513)
		else --NH
			self:Bar(91513, Poison_Protocol, 45, 91513)
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

do --Nef in HC
	local predictions = {}
	do --rotations
		predictions[M] = {}
		predictions[T] = {}
		predictions[E] = {}
		predictions[A] = {}
		
		local function CreatePredictionTable(start, preRot, rot)
			local p = setmetatable({}, {__index = function(tbl, num)
					local pred
					if num > #preRot then
						local i = (num - #preRot)%(#rot)
						if i == 0 then i = #rot end
						pred = rot[i]
					elseif num == 0 then
						pred = {nil, start}
					else
						pred = preRot[num]
					end
					rawset(tbl, num, pred)
					return pred
				end})
				
			predictions[start][#predictions[start] + 1] = p
			return p
		end
		
		--PREDICTIONS
		
		do --M1
			local start = M
			local preRot = {{45,E},{51,A}, {24,M},{43,E}}
			local rot = {{52,A}, {23,M}, {44,E}}
			CreatePredictionTable(start, preRot, rot)
		end
		
		do --M2
			local start = M	--first is pretty variable.
			local preRot = {{53,E},{40,E},{32,T},{45,E}}
			local rot = {{40,E}, {32,T}, {45,E}}
			CreatePredictionTable(start, preRot, rot)
		end	
		
		do --M3 
			--happened once, im Adding :)
			local start = M
			local preRot = {{67,A}}
		end
			
		do --E1
			local start = E
			local preRot = {{44,A},{29,A},{21,M},{40,T},{59,A}}
			local rot = {{20,M}, {40,T}, {60,A}}
			CreatePredictionTable(start, preRot, rot)
		end

		do --E2
			local start = E	
			local preRot = {{45,A},{25,M},{40,T},{35,E},{50,A}}
			local rot = {{25,M}, {40,T}, {60,A}}
			CreatePredictionTable(start, preRot, rot)
		end
		
		do --E3
			local start = E	
			local preRot = {{41,A},{25,M},{37,T},{32,T}}
			local rot = {{60,A}, {20,M}, {40,T}}
			CreatePredictionTable(start, preRot, rot)
		end
		
		do --E4
			local start = E
			local preRot = {{36,M},{65,A},{34,T}}
			local rot = {{58,A}, {30,A}, {30,T}}
			CreatePredictionTable(start, preRot, rot)
		end

		do --A1
			local start = A
			local preRot = {{31,A},{23,M},{40,T},{30,T}}
			local rot = {{35,E}, {45,M}, {40,T}}
			CreatePredictionTable(start, preRot, rot)
		end
		
		do --A2
			local start = A
			local preRot = {{31,A},{20,M}, {36,E},{33,T}}
			local rot = {{48,E}, {40,E}, {30,T}}
			CreatePredictionTable(start, preRot, rot)
		end	
		
		do --A3
			local start = A
			local preRot = {{20,E},{37,M}, {39,T},{45,E}}
			local rot = {{37,M}, {37,T}, {45,E}}
			CreatePredictionTable(start, preRot, rot)
		end
		
		do --A4
			local start = A
			local preRot = {{21,E},{35,M},{38,T},{46,E},{36,M},{35,T},{32,T}}
			local rot =  {{37,E}, {42,M}, {39,T}} --not confirmed!
			CreatePredictionTable(start, preRot, rot)
		end
		
		do --A5
			local start = A
			local preRot = {{32,A},{19,E},{40,E}}
		end
		
		
	end
	
	do --Fight Handling
		local startGolem = nil
		local nefActionCounter = 0
		local lastTimestamp = nil
		local fittingRotations = {}
		local adjustTimes = {}
		local predictionSolutions = {}
		--do not care what values are in there. - will be changed either way before first usage.
		
		local matchDiff = 5
			
		local function matchPrediction(tbl1, tbl2)
			local time1,boss1 = unpack(tbl1)
			local time2,boss2 = unpack(tbl2)
			if boss1 == boss2 then
				if time1 == time2 then --solves problem of both timers being nil.
					return true
				elseif time1 and time2 and math.abs(time2 - time1) < matchDiff then 
					return true
				end
			end
			return false
		end
				
		local function copyTable(tbl)
			local t = {}
			for i,v in pairs(tbl) do
				t[i] = v
			end
			return t
		end
		
		local function newPull(start)
			startGolem = start
			currentString = start
			nefActionCounter = 1
			lastTimestamp = nil
			fittingRotations = copyTable(predictions[start])
		end
		
		local function hideNefBars()
			for txt, b in pairs(showedTimers) do
				if b then 
					mod:SendMessage("BigWigs_StopBar", mod, txt)
				end
			end
			showedTimers = {}
		end
		
		function hcNef.spellUsed(boss) --acctually boss is now the barText according to the boss-Ability - does not change bahavior
			if not boss then return end
			nefActionCounter = nefActionCounter + 1 
			
			if not lastNefAction then
				newPull(boss)
			end
			lastNefAction = boss
			
			timestamp = GetTime()
			local t
			if lastTimestamp then
				t = timestamp-lastTimestamp
			end
			lastTimestamp = timestamp
			
			hideNefBars()
			
			predictionSolutions = {[A] = {},[M] = {},[T] = {},[E] = {}}
			for i,pred in pairs(fittingRotations) do
				local check, upcoming = pred[nefActionCounter-1], pred[nefActionCounter]
				local upT, upB = unpack(upcoming)
				
				if matchPrediction(check, {t,boss}) then
					predictionSolutions[upB][#predictionSolutions[upB] + 1] = upT
				else
					fittingRotations[i] = nil
				end
			end
			
			for solutionBoss,bossTbl in pairs(predictionSolutions) do --solutionBoss == E|M|A|T
				local txt = solutionBoss
				for i,timer in pairs(bossTbl) do
					if i > 1 then
						--to make the strings still diff from each other
						txt = txt.." " 
					end
					showedTimers[txt] = GetTime() + timer
				end
			end
			
			--started timers - try to adjust them instantly - obviously by saves from previous adjusts
			for b,_ in pairs(predictions) do
				hcNef.realtimeAdjust(b,"saves")
			end
		end
		
		function hcNef.realtimeAdjust(boss,t,...)
		--[[Searches for Timers matching this Timers expiration time and then edits those to the given timing]]
			if not t then return end
			
			if t == "saves" then
				if adjustTimes[boss] then
					local tbl = {}
					for i, expir in pairs(adjustTimes[boss]) do
						tbl[i] = expir - GetTime()
					end
					adjustTimes[boss] = {} -- will be filled up again within the call below. (only with numbers that make sense upon this time.)
					hcNef.realtimeAdjust(boss,unpack(tbl))
				end
				return --there is nothing else to do here.
			end
			
			if type(t) ~= "number" or t < 0 then
				--just nonsense to go on with this one.
				if ... then hcNef.realtimeAdjust(boss,...) end -- maybe the other ones have better values.
				return
			end
				
			local expir = GetTime() + t
			local foundTimer
			
			for txt,timerExpir in pairs(showedTimers) do
				if txt:find(boss) and math.abs(timerExpir - expir) <= 4 then
					mod:StopBar(txt)
					showedTimers[txt] = nil
					if not foundTimer then
						foundTimer = txt
					end
				end
			end
			
			--do not show the timers before we go on checking - because we always want to priorize the first arguements.
			if ... then 
				hcNef.realtimeAdjust(boss,...) 
			end
			adjustTimes[boss] = adjustTimes[boss] and {expir, unpack(adjustTimes[boss])} or {expir}
			
			if foundTimer then
				mod:Bar(nefOptionRelative[boss], foundTimer, t, nefIconByName[boss])
				showedTimers[foundTimer] = expir
				if t > 5 then
					mod:DelayedMessage(nefOptionRelative[boss], t-5, boss.." soon", "Urgent", nefIconByName[boss])
				else
					mod:Message(nefOptionRelative[boss], boss.." soon", "Urgent", nefIconByName[boss])
				end
			end
		end
	end
	
end