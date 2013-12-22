-------------------------------------------------------------------------------
-- Module Declaration
--

local plugin = BigWigs:NewPlugin("Statistics")
if not plugin then return end

-------------------------------------------------------------------------------
-- Locals
--

local L = LibStub("AceLocale-3.0"):GetLocale("Big Wigs: Plugins")
local activeEncounters = {}
local difficultyTable = {"10", "25", "10h", "25h", "lfr"}
local zoneModules = {}
local deleteOptions = {
	zoneToDelete = -1, --NONE
	encounterToDelete = -2 --ALL
}

--[[
1."10 Player"
2."25 Player"
3."10 Player (Heroic)"
4."25 Player (Heroic)"
5."Looking For Raid"
]]--

-------------------------------------------------------------------------------
-- Options
--

plugin.defaultDB = {
	enabled = true,
	saveKills = true,
	saveWipes = true,
	saveBestKill = true,
	printKills = true,
	printWipes = true,
	printNewBestKill = true,
	showBar = true,
}

StaticPopupDialogs["BIGWIGS_STATISTICS_CONFIRM_DELETE_ALL"] = {
	text = L.confirmDeleteAll,
	button1 = YES,
	button2 = NO,
	OnAccept = function(self)
		if not BigWigsStatisticsDB then return end
		wipe(BigWigsStatisticsDB)
		BigWigsStatisticsDB = {}
	end,
	timeout = 0,
	whileDead = 1,
	exclusive = 1,
	showAlert = 1,
	hideOnEscape = 1,
	EditBoxOnEscapePressed = function(self)
		self:GetParent():Hide();
		ClearCursor();
	end
}

StaticPopupDialogs["BIGWIGS_STATISTICS_CONFIRM_DELETE_SELECTED"] = {
	text = L.confirmDeleteSelected,
	button1 = YES,
	button2 = NO,
	OnAccept = function(self)
		if not BigWigsStatisticsDB then return end
		local zoneToDelete, encounterToDelete = deleteOptions.zoneToDelete, deleteOptions.encounterToDelete
		if encounterToDelete < 0 then
			BigWigsStatisticsDB[zoneToDelete] = nil
			deleteOptions.zoneToDelete = -1
		else
			BigWigsStatisticsDB[zoneToDelete][encounterToDelete] = nil
			deleteOptions.encounterToDelete = -2
			if not next(BigWigsStatisticsDB[zoneToDelete]) then
				BigWigsStatisticsDB[zoneToDelete] = nil
				deleteOptions.zoneToDelete = -1
			end
		end
	end,
	timeout = 0,
	whileDead = 1,
	exclusive = 1,
	showAlert = 1,
	hideOnEscape = 1,
	EditBoxOnEscapePressed = function(self)
		self:GetParent():Hide();
		ClearCursor();
	end
}


local function translateZoneID(id)
	if not id or type(id) ~= "number" then return end
	local name
	if id < 10 then
		name = select(id, GetMapContinents())
	else
		name = GetMapNameByID(id)
	end
	--XXX MoP temp
	if not name then
		if id == 886 then
			name = "Terrace of Endless Spring"
		elseif id == 897 then
			name = "Heart of Fear"
		elseif id == 896 then
			name = "Mogu'shan Vaults"
		end
	end
	if not name then
		print(("Big Wigs: Tried to translate %q as a zone ID, but it could not be resolved into a name."):format(tostring(id)))
	end
	return name
end

local function GetZoneList()
	local list = {}
	list[-1] = L.None
	for zone,_ in pairs(zoneModules) do
		if BigWigsStatisticsDB[zone] then
			list[zone] = translateZoneID(zone)
		end
	end
	return list
end

local function GetEncounterList()
	local list = {}
	list[-2] = L.All
	local zoneId = deleteOptions.zoneToDelete
	if not zoneId or zoneId == -1 then return list end
	for encounterId, name in pairs(zoneModules[zoneId]) do
		if BigWigsStatisticsDB[zoneId] and BigWigsStatisticsDB[zoneId][encounterId] then
			list[encounterId] = name
		end
	end
	return list
end

local function checkDisabled() return not plugin.db.profile.enabled end
plugin.subPanelOptions = {
	key = "Big Wigs: Boss Statistics",
	name = L.bossStatistics,
	options = {
		name = L.bossStatistics,
		type = "group",
		childGroups = "tab",
		get = function(i) return plugin.db.profile[i[#i]] end,
		set = function(i, value) plugin.db.profile[i[#i]] = value end,
		args = {
			heading = {
				type = "description",
				name = L.bossStatsDescription.."\n\n",
				order = 1,
				width = "full",
				fontSize = "medium",
			},
			enabled = {
				type = "toggle",
				name = L.enableStats,
				order = 2,
				width = "full",
				set = function(i, value)
					plugin.db.profile[i[#i]] = value
					plugin:Disable()
					plugin:Enable()
				end,
			},
			printGroup = {
				type = "group",
				name = L.chatMessages,
				order = 3,
				disabled = checkDisabled,
				inline = true,
				args = {
					printWipes = {
						type = "toggle",
						name = L.printWipeOption,
						order = 1,
					},
					printKills = {
						type = "toggle",
						name = L.printDefeatOption,
						order = 2,
					},
					printNewBestKill = {
						type = "toggle",
						name = L.printBestTimeOption,
						order = 3,
						disabled = function() return not plugin.db.profile.saveBestKill or not plugin.db.profile.enabled end,
					},
				},
			},
			saveKills = {
				type = "toggle",
				name = L.countDefeats,
				order = 4,
				disabled = checkDisabled,
				width = "full",
			},
			saveWipes = {
				type = "toggle",
				name = L.countWipes,
				order = 5,
				disabled = checkDisabled,
				width = "full",
			},
			saveBestKill = {
				type = "toggle",
				name = L.recordBestTime,
				order = 6,
				disabled = checkDisabled,
				width = "full",
			},
			showBar = {
				type = "toggle",
				name = L.createTimeBar,
				order = 7,
				disabled = checkDisabled,
				width = "full",
			},
			deleteGroup = {
				type = "group",
				name = L.deleteData,
				order = 8,
				disabled = checkDisabled,
				inline = true,
				get = function(i) return deleteOptions[i[#i]] end,
				--set = function(i, value) deleteOptions[i[#i]] = value end,
				args = {
					zoneToDelete = {
						type = "select",
						name = L.zoneToDelete,
						order = 1,
						values = GetZoneList,
						set = function(i, value) 
							if deleteOptions[i[#i]] ~= value then
								deleteOptions.encounterToDelete = -2 --ALL
								deleteOptions[i[#i]] = value
							end
						end,
					},
					encounterToDelete = {
						type = "select",
						name = L.encounterToDelete,
						order = 2,
						values = GetEncounterList,
						disabled = function()
							return deleteOptions.zoneToDelete == -1 --NONE
						end,
						set = function(i, value) deleteOptions[i[#i]] = value end,
					},
					deleteSelected = {
						type = "execute",
						name = L.deleteSelected,
						order = 3,
						disabled = function()
							return deleteOptions.zoneToDelete == -1 --NONE
						end,
						func = function()
							local zoneToDelete, encounterToDelete = deleteOptions.zoneToDelete, deleteOptions.encounterToDelete
							if zoneToDelete < 0 then return end
							StaticPopup_Show("BIGWIGS_STATISTICS_CONFIRM_DELETE_SELECTED", (encounterToDelete < 0 and L.allEncounters or zoneModules[zoneToDelete][encounterToDelete]), translateZoneID(zoneToDelete))
						end,
					},
					deleteSelectedHint = {
						type = "description",
						name = L.deleteSelectedHint.."\n",
						order = 4,
						width = "full",
						fontSize = "small",
					},
					deleteAll = {
						type = "execute",
						name = L.deleteAll,
						order = 5,
						func = function()
							StaticPopup_Show("BIGWIGS_STATISTICS_CONFIRM_DELETE_ALL")
						end,
					},
				}
			},
		},
	},
}

-------------------------------------------------------------------------------
-- Initialization
--

function plugin:OnPluginEnable()
	if not BigWigsStatisticsDB then
		BigWigsStatisticsDB = {}
	end
	
	for name, module in BigWigs:IterateBossModules() do
		self:Register("BigWigs_BossModuleRegistered", name, module)
	end
	self:RegisterMessage("BigWigs_BossModuleRegistered", "Register")
	
	if self.db.profile.enabled then
		self:RegisterMessage("BigWigs_OnBossEngage")
		self:RegisterMessage("BigWigs_OnBossWin")
		self:RegisterMessage("BigWigs_OnBossWipe")
		self:RegisterMessage("BigWigs_OnBossDisable")
	end
end

do
	local registered = {}
	function plugin:Register(message, moduleName, module)
		if registered[module.name] then return end
		registered[module.name] = true
		local zone = module.otherMenu or module.zoneId
		if not zone then return end
		if not module.encounterId then return end
		if not zoneModules[zone] then zoneModules[zone] = {} end
		zoneModules[zone][module.encounterId] = module.displayName
	end
end
-------------------------------------------------------------------------------
-- Event Handlers
--

function plugin:BigWigs_OnBossEngage(event, module, diff)
	if module.encounterId and module.zoneId and diff and difficultyTable[diff] and not module.worldBoss then -- Raid restricted for now
		if activeEncounters[module.encounterId] then 
			if activeEncounters[module.encounterId].timer then self:CancelTimer(activeEncounters[module.encounterId].timer, true) end
		else
			activeEncounters[module.encounterId] = {start = GetTime()}
			
			local sDB = BigWigsStatisticsDB
			if not sDB[module.zoneId] then sDB[module.zoneId] = {} end
			if not sDB[module.zoneId][module.encounterId] then sDB[module.zoneId][module.encounterId] = {} end
			sDB = sDB[module.zoneId][module.encounterId]
			if not sDB[difficultyTable[diff]] then sDB[difficultyTable[diff]] = {} end

			local best = sDB[difficultyTable[diff]].best
			if self.db.profile.showBar and best then
				self:SendMessage("BigWigs_StartBar", self, nil, L.bestTimeBar, best, "Interface\\Icons\\spell_holy_borrowedtime")
			end
		end
	end
end

local function saveEncounter(module)
	local curFight = activeEncounters[module.encounterId]
	if curFight then
		local sDB = BigWigsStatisticsDB[module.zoneId][module.encounterId][difficultyTable[module:Difficulty()]]
		local elapsed = curFight.stop - curFight.start
		if curFight.isWin then
			if plugin.db.profile.printKills then
				BigWigs:Print(L.bossDefeatDurationPrint:format(module.displayName, SecondsToTime(elapsed)))
			end

			if plugin.db.profile.saveKills then
				sDB.kills = sDB.kills and sDB.kills + 1 or 1
			end

			if plugin.db.profile.saveBestKill and (not sDB.best or elapsed < sDB.best) then
				sDB.best = elapsed
				if plugin.db.profile.printNewBestKill then
					BigWigs:Print(L.newBestTime)
				end
			end
		else
			if elapsed > 30 then -- Fight must last longer than 30 seconds to be an actual wipe worth noting
				if plugin.db.profile.printWipes then
					BigWigs:Print(L.bossWipeDurationPrint:format(module.displayName, SecondsToTime(elapsed)))
				end

				if plugin.db.profile.saveWipes then
					local sDB = BigWigsStatisticsDB[module.zoneId][module.encounterId][difficultyTable[module:Difficulty()]]
					sDB.wipes = sDB.wipes and sDB.wipes + 1 or 1
				end
			end
		end
		activeEncounters[module.encounterId] = nil
	end
end

function plugin:BigWigs_OnBossWin(event, module)
	if module.encounterId and activeEncounters[module.encounterId] then
		local curFight = activeEncounters[module.encounterId]
		if not curFight.stop then curFight.stop = GetTime() end
		curFight.isWin = true
		if curFight.timer then self:CancelTimer(curFight.timer, true) end
		saveEncounter(module)
	end
end

function plugin:BigWigs_OnBossWipe(event, module)
	if module.encounterId and activeEncounters[module.encounterId] then
		local curFight = activeEncounters[module.encounterId]
		if not curFight.stop then curFight.stop = GetTime() end
		if not curFight.timer then curFight.timer = self:ScheduleTimer(saveEncounter, 5, module) end
	end
end

function plugin:BigWigs_OnBossDisable()
	self:SendMessage("BigWigs_StopBar", self, L.bestTimeBar)
end

