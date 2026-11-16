-- Carbonite | Modules / Gather / GatherStorage
-- The Carbonite gather subsystem: per-node-type herb/mine/timber
-- metadata, the in-memory gather cache, and every Nx:Gather*
-- function (recording, lookup, delete). Lifted out of Carbonite.lua; methods
-- stay on Nx because the Modules/Gather/* documented surfaces
-- (Gather.lua, GatherEvents.lua, GatherEngine.lua) still proxy
-- through these.
--
-- Three earlier extractions related to gather already exist:
--   * Modules/Gather/Gather.lua           - documented public API
--   * Modules/Gather/GatherEvents.lua     - public surface for events
--   * Modules/Gather/GatherEngine.lua     - Nx:GetMaxGatherSkill /
--                                           ShouldShowGatherNode /
--                                           GetGatherNodeName
-- This file owns the data + bulk of the per-node bookkeeping.

local L = LibStub("AceLocale-3.0"):GetLocale("Carbonite")

-------------------------------------------------------------------------------
-- GATHERING SYSTEM
-- Tracks and stores locations of herb/mining nodes
-- Data structure: { skillLevel, iconPath, localizedName }
-------------------------------------------------------------------------------

Nx.GatherInfo = {
    [" "] = {    -- Misc
        ["Art"] = { 0, "Trade_Archaeology", L["Artifact"]},
        ["Everfrost"] = { 0, "spell_shadow_teleport", L["Everfrost"]},
        ["Gas"] = { 0, "inv_gizmo_zapthrottlegascollector",    L["Gas"]},
    },
    ["L"] = {    -- Timber (WoD Lumber Mill)
        { 1, "inv_tradeskillitem_03", L["Small Timber"]},
        { 2, "inv_tradeskillitem_03", L["Medium Timber"]},
        { 3, "inv_tradeskillitem_03", L["Large Timber"]},
    },
    ["H"] = {    -- Herbs (4th element is itemId for localization)
        { 340,    "inv_misc_herb_ancientlichen",L["Ancient Lichen"], 22790},
        { 220,    "inv_misc_herb_13",L["Arthas' Tears"], 8836},
        { 300,    "inv_misc_herb_17",L["Black Lotus"], 13468},
        { 235,    "inv_misc_herb_14",L["Blindweed"], 8839},
        { 1,    "inv_misc_herb_11a",L["Bloodthistle"], 22710},
        { 70,    "inv_misc_root_01",L["Briarthorn"], 2450},
        { 100,    "inv_misc_herb_01",L["Bruiseweed"], 2453},
        { 270,    "inv_misc_herb_dreamfoil",L["Dreamfoil"], 13463},
        { 315,    "inv_misc_herb_dreamingglory",L["Dreaming Glory"], 22786},
        { 15,    "inv_misc_herb_07",L["Earthroot"], 2449},
        { 160,    "inv_misc_herb_12",L["Fadeleaf"], 3818},
        { 300,    "inv_misc_herb_felweed",L["Felweed"], 22785},
        { 205,    "inv_misc_herb_19",L["Firebloom"], 4625},
        { 335,    "inv_misc_herb_flamecap",L["Flame Cap"], 22788},
        { 245,    "inv_mushroom_08",L["Ghost Mushroom"], 8845},
        { 260,    "inv_misc_herb_sansamroot",L["Golden Sansam"], 13464},
        { 170,    "inv_misc_herb_15",L["Goldthorn"], 3821},
        { 120,    "inv_misc_dust_02",L["Grave Moss"], 3369},
        { 250,    "inv_misc_herb_16",L["Gromsblood"], 8846},
        { 290,    "inv_misc_herb_iceCap",L["Icecap"], 13467},
        { 185,    "inv_misc_herb_08",L["Khadgar's Whisker"], 3358},
        { 125,    "inv_misc_herb_03",L["Kingsblood"], 3356},
        { 150,    "inv_misc_root_02",L["Liferoot"], 3357},
        { 50,    "inv_jewelry_talisman_03",L["Mageroyal"], 785},
        { 375,    "inv_misc_herb_manathistle",L["Mana Thistle"], 22793},
        { 280,    "inv_misc_herb_mountainsilversage",L["Mountain Silversage"], 13465},
        { 350,    "inv_misc_herb_netherbloom",L["Netherbloom"], 22791},
        { 350,    "inv_enchant_dustsoul",L["Netherdust Bush"], 32468},
        { 365,    "inv_misc_herb_nightmarevine",L["Nightmare Vine"], 22792},
        { 1,    "inv_misc_flower_02",L["Peacebloom"], 2447},
        { 285,    "inv_misc_herb_plaguebloom",L["Plaguebloom"], 13466},
        { 210,    "inv_misc_herb_17",L["Purple Lotus"], 8831},
        { 325,    "inv_misc_herb_ragveil",L["Ragveil"], 22787},
        { 1,    "inv_misc_herb_10",L["Silverleaf"], 765},
        { 85,    "inv_misc_herb_11",L["Stranglekelp"], 3820},
        { 230,    "inv_misc_herb_18",L["Sungrass"], 8838},
        { 325,    "inv_misc_herb_terrocone",L["Terocone"], 22789},
        { 115,    "inv_misc_flower_01",L["Wild Steelbloom"], 3355},
        { 195,    "inv_misc_flower_03",L["Dragon's Teeth"], 3819},
        { 1,    "inv_mushroom_02",L["Glowcap"], 24245},
        { 350,    "inv_misc_herb_goldclover",L["Goldclover"], 36901},
        { 385,    "inv_misc_herb_talandrasrose",L["Talandra's Rose"], 36907},
        { 400,    "inv_misc_herb_evergreenmoss",L["Adder's Tongue"], 36903},
        { 400,    "inv_misc_herb_goldclover",L["Frozen Herb"], 36908},
        { 400,    "inv_misc_herb_tigerlily",L["Tiger Lily"], 36904},
        { 425,    "inv_misc_herb_whispervine",L["Lichbloom"], 36905},
        { 435,    "inv_misc_herb_icethorn",L["Icethorn"], 36906},
        { 450,    "inv_misc_herb_frostlotus",L["Frost Lotus"], 36908},
        { 360,    "inv_misc_herb_11a",L["Firethorn"], 39970},
        { 425, "inv_misc_herb_azsharasveil", L["Azshara's Veil"], 52983},
        { 425, "inv_misc_herb_cinderbloom", L["Cinderbloom"], 52983},
        { 425, "inv_misc_herb_stormvine", L["Stormvine"], 52987},
        { 475, "inv_misc_herb_heartblossom", L["Heartblossom"], 52986},
        { 500, "inv_misc_herb_whiptail", L["Whiptail"], 52988},
        { 525, "inv_misc_herb_twilightjasmine", L["Twilight Jasmine"], 52984},
        { 600,    "inv_misc_herb_foolscap",L["Fool's Cap"], 79011},
        { 550,    "inv_misc_herb_goldenlotus",L["Golden Lotus"], 72238},
        { 500,    "inv_misc_herb_jadetealeaf",L["Green Tea Leaf"], 72234},
        { 525,    "inv_misc_herb_rainpoppy",L["Rain Poppy"], 72237},
        { 575,    "inv_misc_herb_shaherb",L["Sha-Touched Herb"], 79010},
        { 545,    "inv_misc_herb_silkweed",L["Silkweed"], 72235},
        { 550,    "inv_misc_herb_snowlily",L["Snow Lily"], 79010},
        { 550,    "inv_misc_herb_chamlotus",L["Chameleon Lotus"], 97619},
        -- WoD Herbs
        { 1,    "inv_misc_herb_frostweed",L["Frostweed"], 109124},
        { 1,    "inv_misc_herb_flytrap",L["Gorgrond Flytrap"], 109126},
        { 1,    "inv_misc_herb_starflower",L["Starflower"], 109127},
        { 1,    "inv_misc_herb_arrowbloom",L["Nagrand Arrowbloom"], 109128},
        { 1,    "inv_misc_herb_taladororchid",L["Talador Orchid"], 109129},
        { 1,    "inv_misc_herb_fireweed",L["Fireweed"], 109125},
        { 1,    "inv_farm_pumpkinseed_yellow",L["Withered Herb"], 109125},
        -- Legion Herbs
        { 1,    "inv_herbalism_70_aethril",L["Aethril"], 124101},
        { 1,    "inv_herbalism_70_dreamleaf",L["Dreamleaf"], 124102},
        { 1,    "inv_herbalism_70_felwort",L["Felwort"], 124106},
        { 1,    "inv_herbalism_70_fjarnskaggl",L["Fjarnskaggl"], 124104},
        { 1,    "inv_herbalism_70_foxflower",L["Foxflower"], 124103},
        { 1,    "inv_herbalism_70_starlightrosepetals",L["Starlight Rose"], 124105},
        { 1,    "inv_misc_herb_astralglory",L["Astral Glory"], 151565},
        -- BfA Herbs
        { 1,    "inv_misc_herb_akundasbite",L["Akunda's Bite"], 152507},
        { 1,    "inv_misc_herb_anchorweed",L["Anchor Weed"], 152510},
        { 1,    "inv_misc_herb_riverbud",L["Riverbud"], 152505},
        { 1,    "inv_misc_herb_seastalk",L["Sea Stalks"], 152511},
        { 1,    "inv_misc_herb_pollen",L["Siren's Sting"], 152509},
        { 1,    "inv_misc_herb_starmoss",L["Star Moss"], 152506},
        { 1,    "inv_misc_herb_winterskiss",L["Winter's Kiss"], 152508},
        -- Shadowlands Herbs
        { 1,    "inv_misc_herb_bloodcup",L["Widowbloom"], 168583},
        { 1,    "inv_misc_herb_deathblossom",L["Death Blossom"], 168586},
        { 1,    "inv_misc_herb_risingglory",L["Rising Glory"], 168589},
        { 1,    "inv_misc_herb_marrowroot",L["Marrowroot"], 168583},
        { 1,    "inv_misc_herb_ardenweald",L["Vigil's Torch"], 170554},
        { 1,    "inv_misc_herb_nightshade",L["Nightshade"], 171315},
        -- Dragonflight Herbs
        { 1,    "Inv_misc_herb_dragonsbreath",L["Hochenblume"], 191460},
        { 1,    "Inv_misc_herb_bubblepoppy",L["Bubble Poppy"], 191467},
        { 1,    "Inv_misc_herb_saxifrage",L["Saxifrage"], 191470},
        { 1,    "Inv_misc_herb_writhebark",L["Writhebark"], 191473},
        -- The War Within Herbs
        { 1,    "Inv_misc_herb_mycobloom",L["Mycobloom"], 210796},
        { 1,    "Inv_misc_herb_mycobloom",L["Altered Mycobloom"], 210796},
        { 1,    "Inv_misc_herb_mycobloom",L["Crystallized Mycobloom"], 210796},
        { 1,    "Inv_misc_herb_mycobloom",L["Irradiated Mycobloom"], 210796},
        { 1,    "Inv_misc_herb_mycobloom",L["Lush Mycobloom"], 210796},
        { 1,    "Inv_misc_herb_mycobloom",L["Sporefused Mycobloom"], 210796},
        { 1,    "inv_misc_herb_luredrop",L["Luredrop"], 210798},
        { 1,    "inv_misc_herb_luredrop",L["Altered Luredrop"], 210798},
        { 1,    "inv_misc_herb_luredrop",L["Crystallized Luredrop"], 210798},
        { 1,    "inv_misc_herb_luredrop",L["Irradiated Luredrop"], 210798},
        { 1,    "inv_misc_herb_luredrop",L["Lush Luredrop"], 210798},
        { 1,    "inv_misc_herb_luredrop",L["Sporefused Luredrop"], 210798},
        { 1,    "inv_misc_herb_arathorsspear",L["Arathor's Spear"], 210799},
        { 1,    "inv_misc_herb_arathorsspear",L["Crystallized Arathor's Spear"], 210799},
        { 1,    "inv_misc_herb_arathorsspear",L["Irradiated Arathor's Spear"], 210799},
        { 1,    "inv_misc_herb_arathorsspear",L["Lush Arathor's Spear"], 210799},
        { 1,    "inv_misc_herb_arathorsspear",L["Sporefused Arathor's Spear"], 210799},
        { 1,    "inv_misc_herb_blessingblossom",L["Blessing Blossom"], 210800},
        { 1,    "inv_misc_herb_blessingblossom",L["Crystallized Blessing Blossom"], 210800},
        { 1,    "inv_misc_herb_blessingblossom",L["Irradiated Blessing Blossom"], 210800},
        { 1,    "inv_misc_herb_blessingblossom",L["Lush Blessing Blossom"], 210800},
        { 1,    "inv_misc_herb_blessingblossom",L["Sporefused Blessing Blossom"], 210800},
        { 1,    "inv_misc_herb_orbinid",L["Orbinid"], 210797},
        { 1,    "inv_misc_herb_orbinid",L["Altered Orbinid"], 210797},
        { 1,    "inv_misc_herb_orbinid",L["Crystallized Orbinid"], 210797},
        { 1,    "inv_misc_herb_orbinid",L["Irradiated Orbinid"], 210797},
        { 1,    "inv_misc_herb_orbinid",L["Lush Orbinid"], 210797},
        { 1,    "inv_misc_herb_orbinid",L["Sporefused Orbinid"], 210797},
        -- Midnight Herbs
        { 1,    "inv_misc_herb_silverleaf",L["Argentleaf"], 256963},
        { 1,    "inv_misc_herb_earthroot",L["Azeroot"], 256964},
        { 1,    "inv_misc_herb_mageroyal",L["Mana Lily"], 256965},
        { 1,    "inv_herb_bloodthistle",L["Sanguithorn"], 256966},
        { 1,    "inv_misc_herb_peacebloom",L["Tranquility Bloom"], 256967},
    },
    ["M"] = {    -- Mine node (4th element is itemId for localization)
        { 325,    "inv_ore_adamantium",L["Adamantite Deposit"], 23425},
        { 375,    "inv_misc_gem_01",L["Ancient Gem Vein"], 23426},
        { 1,    "inv_ore_copper_01",L["Copper Vein"], 2770},
        { 230,    "inv_ore_mithril_01",L["Dark Iron Deposit"], 11370},
        { 300,    "inv_ore_feliron",L["Fel Iron Deposit"], 23424},
        { 155,    "inv_ore_copper_01",L["Gold Vein"], 2776},
        { 65,    "inv_ore_thorium_01",L["Incendicite Mineral Vein"], 3340},
        { 150,    "inv_ore_mithril_01",L["Indurium Mineral Vein"], 5833},
        { 125,    "inv_ore_iron_01",L["Iron Deposit"], 2772},
        { 375,    "inv_ore_khorium",L["Khorium Vein"], 23426},
        { 305,    "inv_stone_15",L["Large Obsidian Chunk"], 22203},
        { 75,    "inv_ore_thorium_01",L["Lesser Bloodstone Deposit"], 4278},
        { 175,    "inv_ore_mithril_02",L["Mithril Deposit"], 3858},
        { 275,    "inv_ore_ethernium_01",L["Nethercite Deposit"], 32464},
        { 350,    "inv_ore_adamantium",L["Rich Adamantite Deposit"], 23425},
        { 255,    "inv_ore_thorium_02",L["Rich Thorium Vein"], 10620},
        { 75,    "inv_stone_16",L["Silver Vein"], 2775},
        { 305,    "inv_misc_stonetablet_01",L["Small Obsidian Chunk"], 22202},
        { 230,    "inv_ore_thorium_02",L["Small Thorium Vein"], 10620},
        { 65,    "inv_ore_tin_01",L["Tin Vein"], 2771},
        { 230,    "inv_ore_truesilver_01",L["Truesilver Deposit"], 7911},
        { 350,    "inv_ore_cobalt",L["Cobalt Deposit"], 36909},
        { 375,    "inv_ore_cobalt",L["Rich Cobalt Deposit"], 36909},
        { 425,    "inv_ore_saronite_01",L["Saronite Deposit"], 36912},
        { 425,    "inv_ore_saronite_01",L["Rich Saronite Deposit"], 36912},
        { 450,    "inv_ore_platinum_01",L["Titanium Vein"], 36910},
        { 425,    "item_elementiumore", L["Obsidium Deposit"], 53038},
        { 450,    "item_elementiumore", L["Rich Obsidium Deposit"], 53038},
        { 475,    "item_pyriumore", L["Elementium Vein"], 52185},
        { 500,    "item_pyriumore", L["Rich Elementium Vein"], 52185},
        { 525,    "inv_ore_arcanite_01", L["Pyrite Deposit"], 52183},
        { 525,    "inv_ore_arcanite_01", L["Rich Pyrite Deposit"], 52183},
        { 515,    "inv_ore_ghostiron",L["Ghost Iron Deposit"], 72092},
        { 550,    "inv_ore_ghostiron",L["Rich Ghost Iron Deposit"], 72092},
        { 550,    "inv_ore_manticyte",L["Kyparite Deposit"], 72093},
        { 575,    "inv_ore_manticyte",L["Rich Kyparite Deposit"], 72093},
        { 600,    "inv_ore_trilliumwhite",L["Trillium Vein"], 72094},
        { 600,    "inv_ore_trilliumWhite",L["Rich Trillium Vein"], 72094},
        -- WoD Mining
        { 1,    "inv_ore_trueironore",L["True Iron Deposit"], 109118},
        { 1,    "inv_ore_trueironore",L["Rich True Iron Deposit"], 109118},
        { 1,    "inv_ore_trueironore",L["Smoldering True Iron Deposit"], 109118},
        { 1,    "inv_ore_blackrock_ore",L["Blackrock Deposit"], 109119},
        { 1,    "inv_ore_blackrock_ore",L["Rich Blackrock Deposit"], 109119},
        -- Legion Mining
        { 1,    "inv_felslate",L["Felslate Deposit"], 123919},
        { 1,    "inv_felslate",L["Felslate Seam"], 123919},
        { 1,    "inv_felslate",L["Living Felslate"], 123919},
        { 1,    "inv_leystone",L["Leystone Deposit"], 123918},
        { 1,    "inv_leystone",L["Leystone Seam"], 123918},
        { 1,    "inv_leystone",L["Living Leystone"], 123918},
        { 1,    "inv_misc_starmetal",L["Empyrium Deposit"], 151564},
        { 1,    "inv_misc_starmetal",L["Rich Empyrium Deposit"], 151564},
        { 1,    "inv_misc_starmetal",L["Empyrium Seam"], 151564},
        -- BfA Mining
        { 1,    "inv_ore_monalite",L["Monelite Deposit"], 152512},
        { 1,    "inv_ore_monalite",L["Rich Monelite Deposit"], 152512},
        { 1,    "inv_ore_monalite",L["Monelite Seam"], 152512},
        { 1,    "inv_ore_platinum",L["Platinum Deposit"], 152513},
        { 1,    "inv_ore_platinum",L["Rich Platinum Deposit"], 152513},
        { 1,    "inv_ore_stormsilver",L["Storm Silver Deposit"], 152579},
        { 1,    "inv_ore_stormsilver",L["Rich Storm Silver Deposit"], 152579},
        { 1,    "inv_ore_stormsilver",L["Storm Silver Seam"], 152579},
        -- Shadowlands Mining
        { 1,    "inv_ore_lastrite",L["Laestrite Deposit"], 171828},
        { 1,    "inv_ore_lastrite",L["Rich Laestrite Deposit"], 171828},
        { 1,    "inv_ore_elethium",L["Elethium Deposit"], 171833},
        { 1,    "inv_ore_elethium",L["Rich Elethium Deposit"], 171833},
        { 1,    "inv_ore_solenium",L["Solenium Deposit"], 171829},
        { 1,    "inv_ore_solenium",L["Rich Solenium Deposit"], 171829},
        { 1,    "inv_ore_oxxein",L["Oxxein Deposit"], 171830},
        { 1,    "inv_ore_oxxein",L["Rich Oxxein Deposit"], 171830},
        { 1,    "inv_ore_phaedrite",L["Phaedrum Deposit"], 171831},
        { 1,    "inv_ore_phaedrite",L["Rich Phaedrum Deposit"], 171831},
        { 1,    "inv_ore_sinvyr",L["Sinvyr Deposit"], 171832},
        { 1,    "inv_ore_sinvyr",L["Rich Sinvyr Deposit"], 171832},
        -- Dragonflight Mining
        { 1,    "Inv_ore_tyrivite",L["Serevite Deposit"], 190395},
        { 1,    "Inv_ore_tyrivite",L["Hardened Serevite Deposit"], 190395},
        { 1,    "Inv_ore_tyrivite",L["Infurious Serevite Deposit"], 190395},
        { 1,    "Inv_ore_tyrivite",L["Molten Serevite Deposit"], 190395},
        { 1,    "Inv_ore_tyrivite",L["Primal Serevite Deposit"], 190395},
        { 1,    "Inv_ore_tyrivite",L["Rich Serevite Deposit"], 190395},
        { 1,    "Inv_ore_tyrivite",L["Titan-Touched Serevite Deposit"], 190395},
        { 1,    "Inv_ore_draconium",L["Draconium Deposit"], 189143},
        { 1,    "Inv_ore_draconium",L["Hardened Draconium Deposit"], 189143},
        { 1,    "Inv_ore_draconium",L["Infurious Draconium Deposit"], 189143},
        { 1,    "Inv_ore_draconium",L["Molten Draconium Deposit"], 189143},
        { 1,    "Inv_ore_draconium",L["Primal Draconium Deposit"], 189143},
        { 1,    "Inv_ore_draconium",L["Rich Draconium Deposit"], 189143},
        { 1,    "Inv_ore_draconium",L["Titan-Touched Draconium Deposit"], 189143},
        -- The War Within Mining
        { 1,    "inv_ore_bismuth",L["Bismuth"], 210930},
        { 1,    "inv_ore_bismuth",L["Crystallized Bismuth"], 210930},
        { 1,    "inv_ore_bismuth",L["EZ-Mine Bismuth"], 210930},
        { 1,    "inv_ore_bismuth",L["Rich Bismuth"], 210930},
        { 1,    "inv_ore_bismuth",L["Weeping Bismuth"], 210930},
        { 1,    "inv_ore_ironclaw_normal",L["Ironclaw"], 210932},
        { 1,    "inv_ore_ironclaw_normal",L["Crystallized Ironclaw"], 210932},
        { 1,    "inv_ore_ironclaw_normal",L["EZ-Mine Ironclaw"], 210932},
        { 1,    "inv_ore_ironclaw_normal",L["Rich Ironclaw"], 210932},
        { 1,    "inv_ore_ironclaw_normal",L["Weeping Ironclaw"], 210932},
        { 1,    "inv_ore_nerubian_red",L["Aqirite"], 210933},
        { 1,    "inv_ore_nerubian_red",L["Crystallized Aqirite"], 210933},
        { 1,    "inv_ore_nerubian_red",L["EZ-Mine Aqirite"], 210933},
        { 1,    "inv_ore_nerubian_red",L["Rich Aqirite"], 210933},
        { 1,    "inv_ore_nerubian_red",L["Weeping Aqirite"], 210933},
        { 1,    "ui_profession_mining",L["Webbed Ore Deposit"], 210933},
        -- Midnight Mining
        { 1,    "inv_ore_brilliantsilver",L["Brilliant Silver"], 256970},
        { 1,    "inv_ore_refulgentcopper",L["Refulgent Copper"], 256971},
        { 1,    "inv_ore_umbraltin",L["Umbral Tin"], 256972},
    }
}

-- Midnight resource modifiers share the base node's icon, item, option, and
-- stored ID. Keep that established storage layout while accepting every live
-- localized target name supplied by UNIT_SPELLCAST_SENT.
local GatherNameAliases = {}

local function addGatherNameAliases(baseName, ...)
    local base = L[baseName] or baseName
    for index = 1, select("#", ...) do
        local aliasName = select(index, ...)
        local localizedAlias = L[aliasName] or aliasName
        GatherNameAliases[localizedAlias] = base
    end
end

addGatherNameAliases(
    "Argentleaf", "Lush Argentleaf", "Lightfused Argentleaf",
    "Primal Argentleaf", "Voidbound Argentleaf", "Wild Argentleaf")
addGatherNameAliases(
    "Azeroot", "Lush Azeroot", "Lightfused Azeroot", "Primal Azeroot",
    "Voidbound Azeroot", "Wild Azeroot")
addGatherNameAliases(
    "Mana Lily", "Lush Mana Lily", "Lightfused Mana Lily", "Primal Mana Lily",
    "Voidbound Mana Lily", "Wild Mana Lily")
addGatherNameAliases(
    "Sanguithorn", "Lush Sanguithorn", "Lightfused Sanguithorn",
    "Primal Sanguithorn", "Voidbound Sanguithorn", "Wild Sanguithorn")
addGatherNameAliases(
    "Tranquility Bloom", "Lush Tranquility Bloom",
    "Lightfused Tranquility Bloom", "Primal Tranquility Bloom",
    "Voidbound Tranquility Bloom", "Wild Tranquility Bloom")
addGatherNameAliases(
    "Brilliant Silver", "Rich Brilliant Silver", "Lightfused Brilliant Silver",
    "Primal Brilliant Silver", "Voidbound Brilliant Silver",
    "Wild Brilliant Silver")
addGatherNameAliases(
    "Refulgent Copper", "Rich Refulgent Copper", "Lightfused Refulgent Copper",
    "Primal Refulgent Copper", "Voidbound Refulgent Copper",
    "Wild Refulgent Copper")
addGatherNameAliases(
    "Umbral Tin", "Rich Umbral Tin", "Lightfused Umbral Tin",
    "Primal Umbral Tin", "Voidbound Umbral Tin", "Wild Umbral Tin")

local function getGatherNameAlias(name)
    return GatherNameAliases[name]
end

local function normalizeGatherName(name)
    if type(name) ~= "string" then return name end
    local ok, aliasName = pcall(getGatherNameAlias, name)
    return ok and (aliasName or name) or name
end

Nx.GatherRemap = {
    ["NXHerb"] = {
        [47] = 46,        -- Icethorn
    },
    ["NXMine"] = {
        [6] = 9,        -- Gold
        [17] = 20,        -- Silver
        [23] = 22,        -- Rich Cobalt Deposit
        [25] = 24,        -- Rich Saronite Deposit
        [26] = 24,        -- Titanium
    }
}

---
-- Initialize gathering system
-- Must be called after map init for proper node display
--
function Nx:GatherInit()
    if self.DoGatherUpgrade then
        self.DoGatherUpgrade = nil
        Nx:GatherVerUpgrade()
    end
    Nx.GatherVerUpgrade = nil        -- Kill it
    Nx.GatherVerUpgradeType = nil        -- Kill it
end

---
-- Get gather node info by type and ID
-- @param typ  Node type: "H" (herb), "M" (mine)
-- @param id   Node ID number
-- @return     name, iconPath, skillLevel
--
function Nx:GetGather (typ, id)
    local v = Nx.GatherInfo[typ][id]
    if v then
        return v[3], v[2], v[1]
    end
end

-- Cache for quick node type lookups (nil = not yet built)
Nx.GatherCache = {}
Nx.GatherCache.H = nil  -- Herbs
Nx.GatherCache.M = nil  -- Mines

---
-- Check if a spell name is a gathering spell
-- @param nodename  Spell/node name
-- @return          "Herb Gathering" or "Mining" or nil
--
function Nx:IsGathering(nodename)
    if not Nx.GatherCache.H then
        Nx.GatherCache.H = {}
        for k, v in ipairs (Nx.GatherInfo["H"]) do
            if type(v[3]) == "string" then
                Nx.GatherCache.H[v[3]] = true
            end
        end
    end
    if not Nx.GatherCache.M then
        Nx.GatherCache.M = {}
        for k, v in ipairs (Nx.GatherInfo["M"]) do
            if type(v[3]) == "string" then
                Nx.GatherCache.M[v[3]] = true
            end
        end
    end
    if type(nodename) ~= "string" then return end
    nodename = normalizeGatherName(nodename)
    local isHerb, isMine = false, false
    pcall(function() isHerb = Nx.GatherCache.H[nodename] end)
    pcall(function() isMine = Nx.GatherCache.M[nodename] end)
    if isHerb then return L["Herb Gathering"] end
    if isMine then return L["Mining"] end
end

---
-- Convert herb name to internal ID
-- @param name  Localized herb name
-- @return      Herb ID or nil if not found
--
function Nx:HerbNameToId (name)
    name = normalizeGatherName(name)
    for k, v in ipairs (Nx.GatherInfo["H"]) do
        if v[3] == name then
            return k
        end
    end

    if Nx.db.profile.Debug.DBGather then
        Nx.prt (L["Unknown herb"] .. " %s", name)
    end
end

---
-- Convert mining node name to internal ID
-- @param name  Localized node name
-- @return      Node ID or nil if not found
--
function Nx:MineNameToId (name)

    name = normalizeGatherName(name)
    name = gsub (name, L["Ooze Covered"] .. " ", "")
    if name == L["Thorium Vein"] then                -- Created when Ooze Covered removed
        name = L["Small Thorium Vein"]
    end
    for k, v in ipairs (Nx.GatherInfo["M"]) do
        if v[3] == name then
            return k
        end
    end

    if Nx.db.profile.Debug.DBGather then
        Nx.prt (L["Unknown ore"] .. " %s", name)
    end
end

--------
-- Upgrade gather data

function Nx:GatherVerUpgrade()
    Nx:GatherVerUpgradeType ("NXHerb")
    Nx:GatherVerUpgradeType ("NXMine")
    Nx:GatherVerUpgradeType ("NXTimber")
end

function Nx:GatherVerUpgradeType (tName)
end

---
-- Record a gathered herb location
-- @param id     Herb ID
-- @param mapId  Map ID
-- @param x      Zone X (0-100)
-- @param y      Zone Y (0-100)
-- @param level  Dungeon level
--
function Nx:GatherHerb (id, mapId, x, y, level)
    self:Gather ("NXHerb", id, mapId, x, y, level, "ShowGatherH")
end

---
-- Record a gathered mining node location
-- @param id     Node ID
-- @param mapId  Map ID
-- @param x      Zone X (0-100)
-- @param y      Zone Y (0-100)
-- @param level  Dungeon level
--
function Nx:GatherMine (id, mapId, x, y, level)
    self:Gather ("NXMine", id, mapId, x, y, level, "ShowGatherM")
end

---
-- Record a gathered timber location
-- @param id     Timber ID (1=Small, 2=Medium, 3=Large)
-- @param mapId  Map ID
-- @param x      Zone X (0-100)
-- @param y      Zone Y (0-100)
-- @param level  Dungeon level
--
function Nx:GatherTimber (id, mapId, x, y, level)
    self:Gather ("NXTimber", id, mapId, x, y, level, "ShowGatherL")
end

---
-- Record a gathered node location (generic)
-- Merges nearby nodes and stores position
-- @param nodeType  "NXHerb", "NXMine", or "Misc"
-- @param id        Node ID
-- @param mapId     Map ID
-- @param x         Zone X (0-100)
-- @param y         Zone Y (0-100)
-- @param level     Dungeon level
-- @param showSetting  Optional live-map visibility setting to refresh
--
function Nx:Gather (nodeType, id, mapId, x, y, level, showSetting)
    level = level or 0  -- Default to 0 if not provided
    local remap = self.GatherRemap[nodeType]
    if remap then
        id = remap[id] or id
    end
    local data = Nx.db.profile.GatherData[nodeType]
    if not data then
        Nx.db.profile.GatherData[nodeType] = {}
        data = Nx.db.profile.GatherData[nodeType]
    end

    local zoneT = data[mapId]

    -- Saved gather data is valid even when Carbonite has not resolved this
    -- map's render metadata yet. Replacing zoneT in that state discarded the
    -- previously recorded locations on every subsequent gather.
    if not zoneT then
--        Nx.prt ("Gather new %d", mapId)
        zoneT = {}
        data[mapId] = zoneT
    end

    local maxDist = (5 / Nx.Map:GetWorldZoneScale (mapId)) ^ 2
    local index
    local nodeT = zoneT[id] or {}
    zoneT[id] = nodeT

    for n, node in ipairs (nodeT) do
        local nx, ny, nlevel = Nx.Split("|",node)
        nx, ny, nlevel = tonumber(nx), tonumber(ny), tonumber(nlevel)

        if not nlevel then
            nlevel = 0
        end
        if nlevel == level then
            local dist = (nx - x) ^ 2 + (ny - y) ^ 2
            if dist < maxDist then        -- Squared compare
                index = n
                break
            end
        end
    end
    local cnt = 1
    if not index then
        index = #nodeT + 1
    else
        local nx,xy, level = Nx.Split ("|", nodeT[index])
    end
    nodeT[index] = format ("%f|%f|%d", x, y, level)

    -- Live gathers should appear on the currently displayed Carbonite map
    -- immediately. Imports omit showSetting and keep their single batch-end
    -- refresh, avoiding a full icon rebuild for every imported node.
    local mapSettings = Nx.db.char and Nx.db.char.Map
    if showSetting and mapSettings and mapSettings[showSetting] then
        local guide = Nx.Map and Nx.Map.Guide
        local map = guide and guide.Map
        if map and map:GetCurrentMapId() == mapId then
            guide:UpdateMapIcons()
        end
    end
end

---
-- Unpack gather node position string
-- Optimized to avoid creating temporary tables
-- @param item  "x|y|level" string
-- @return      x, y, level numbers
--
function Nx:GatherUnpack (item)
    -- Use string.find instead of Split to avoid table creation
    local p1 = string.find(item, "|", 1, true)
    if not p1 then
        return tonumber(item), 0, 0
    end
    local p2 = string.find(item, "|", p1 + 1, true)
    local x = tonumber(string.sub(item, 1, p1 - 1))
    local y, level
    if p2 then
        y = tonumber(string.sub(item, p1 + 1, p2 - 1))
        level = tonumber(string.sub(item, p2 + 1)) or 0
    else
        y = tonumber(string.sub(item, p1 + 1))
        level = 0
    end
    return x, y, level
end

---
-- Delete all herb gathering data
--
function Nx:GatherDeleteHerb()
    Nx.db.profile.GatherData.NXHerb = {}
end

---
-- Delete all mining gathering data
--
function Nx:GatherDeleteMine()
    Nx.db.profile.GatherData.NXMine = {}
end

---
-- Delete all timber gathering data
--
function Nx:GatherDeleteTimber()
    Nx.db.profile.GatherData.NXTimber = {}
end

---
-- Delete all misc gathering data
--
function Nx:GatherDeleteMisc()
    Nx.db.profile.GatherData["Misc"] = {}
end

