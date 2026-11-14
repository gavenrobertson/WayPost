-- luacheck configuration for Waypost (WoW addon, Lua 5.1)
std = "lua51"
max_line_length = false
unused_args = false
exclude_files = { "Waypost/Data", "Waypost_Routes_*", "tests/wowmock.lua" }
globals = {
	"Waypost", "WaypostDB", "WaypostCharDB", "WaypostBackup", "SlashCmdList", "StaticPopupDialogs", "UISpecialFrames",
	"SLASH_WAYPOST1", "SLASH_WAYPOST2", "SLASH_WAYPOST3", "SLASH_WAYPOSTREPORT1", "SLASH_WAYPOSTREPORT2",
	"BINDING_HEADER_WAYPOST", "BINDING_NAME_WAYPOST_TOGGLE", "BINDING_NAME_WAYPOST_NEXT", "BINDING_NAME_WAYPOST_PREV",
	"BINDING_NAME_WAYPOST_SKIP", "BINDING_NAME_WAYPOST_GUIDES",
	"Waypost_OnAddonCompartmentClick", "Waypost_OnAddonCompartmentEnter", "Waypost_OnAddonCompartmentLeave",
}
read_globals = {
	"ITEM_QUALITY_COLORS", "CreateColor", "GetXPExhaustion",
	"AcceptQuest", "AcknowledgeAutoAcceptQuest", "CLOSE", "C_AddOns", "C_ChatInfo", "C_Container", "C_EncodingUtil",
	"C_GossipInfo", "C_GuildInfo", "C_Item", "C_Map", "C_MerchantFrame", "C_Minimap", "C_QuestLog", "C_SpellBook",
	"C_Timer", "CompleteQuest", "ConfirmAcceptQuest", "CreateFont", "CreateFrame", "CreateVector2D",
	"DEFAULT_CHAT_FRAME", "ERR_NEWTAXIPATH", "Enum", "GameTooltip", "GetActiveQuestID", "GetActiveTitle",
	"GetAddOnMemoryUsage", "GetAvailableQuestInfo", "GetBindLocation", "GetBindingKey", "GetBindingText",
	"GetBuildInfo", "GetCVar", "GetCoinTextureString", "GetCursorPosition", "GetGuildInfo", "GetGuildRosterInfo",
	"GetInventoryItemLink", "GetItemCooldown", "GetItemCount", "GetItemIcon", "GetItemInfo", "GetLocale",
	"GetMerchantItemInfo", "GetMerchantItemLink", "GetMerchantNumItems", "GetMoney", "GetNormalizedRealmName",
	"GetNumActiveQuests", "GetNumAvailableQuests", "GetNumGuildMembers", "GetNumQuestChoices", "GetNumSubgroupMembers",
	"GetPlayerFacing", "GetQuestID", "GetQuestItemLink", "GetQuestReward", "GetRealZoneText", "GetRealmName",
	"GetSubZoneText", "GetTime", "GetUnitSpeed", "HideUIPanel", "InCombatLockdown", "IsInGroup", "IsInGuild",
	"IsIndoors", "IsPlayerSpell", "IsQuestCompletable", "IsShiftKeyDown", "IsSpellKnown", "IsTrialAccount",
	"IsUsableItem", "LOCALIZED_CLASS_NAMES_MALE", "Minimap", "NO", "NumTaxiNodes", "PawnGetItemData",
	"PawnIsItemAnUpgrade", "PlaySound", "QuestGetAutoAccept", "QuestInfoFrame", "QuestInfo_GetRewardButton",
	"QuestLogPushQuest", "RAID_CLASS_COLORS", "SOUNDKIT", "STANDARD_TEXT_FONT", "SelectActiveQuest",
	"SelectAvailableQuest", "SendChatMessage", "Settings", "SettingsPanel", "StaticPopup_Show", "TakeTaxiNode",
	"TaxiNodeGetType", "TaxiNodeName", "TomTom", "UIParent", "UnitClass", "UnitFactionGroup", "UnitGUID", "UnitLevel",
	"UnitName", "UnitOnTaxi", "UnitPosition", "UnitRace", "UnitXP", "UnitXPMax", "UpdateAddOnMemoryUsage",
	"WorldMapFrame", "YES", "geterrorhandler", "hash_SlashCmdList", "hooksecurefunc", "issecretvalue", "strsplit",
	"time", "tinsert",
}
files["tests/run.lua"] = { globals = { "WaypostFrame", "WaypostArrow", "WaypostItemButton", "WorldMapFrame", "C_AddOns", "GameMenuFrame", "WaypostPicker", "WaypostOptions", "WaypostXPTracker" } }
