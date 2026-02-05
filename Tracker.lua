-- PlayerStats: Event tracking for all statistics
local PS = PlayerStats

local HEARTHSTONE_SPELL    = 8690
local ASTRAL_RECALL_SPELL = 556
local NAARUS_EMBRACE_SPELL = 1265709
local PVP_TRINKET_SPELL = 42292

-- Aura-based food/drink/well-fed detection
local wasEating = false
local wasDrinking = false

-- PvP death detection
local lastDmgFlags = 0
local lastDmgTime = 0

-- Instance tracking
local currentInstance = nil

-- BG/Arena tracking
local inBG = false
local inArena = false
local arenaBracket = nil
local bgName = nil
local bgResultRecorded = false

-- Gold source tracking
local merchantOpen = false
local lastKnownMoney = 0
local lootGoldThisFrame = false
local questGoldPending = false

-- Gathering tracking
local pendingGatherSpell = nil
local pendingGatherTarget = nil
local pendingGatherTime = 0
local gatherCountedThisNode = false

-- Common social emotes to track
local TRACKED_EMOTES = {
    -- Greetings/Farewells
    ["wave"] = true, ["bow"] = true, ["salute"] = true, ["hello"] = true,
    ["hi"] = true, ["bye"] = true, ["goodbye"] = true, ["welcome"] = true,
    -- Positive
    ["thank"] = true, ["thanks"] = true, ["cheer"] = true, ["clap"] = true,
    ["congratulate"] = true, ["grats"] = true, ["applaud"] = true, ["bravo"] = true,
    ["nod"] = true, ["yes"] = true, ["agree"] = true, ["smile"] = true,
    ["grin"] = true, ["happy"] = true, ["hug"] = true, ["cuddle"] = true,
    ["comfort"] = true, ["pat"] = true, ["love"] = true, ["kiss"] = true,
    ["blow"] = true, ["wink"] = true, ["flirt"] = true, ["sexy"] = true,
    -- Negative
    ["no"] = true, ["disagree"] = true, ["shrug"] = true, ["sigh"] = true,
    ["cry"] = true, ["sob"] = true, ["frown"] = true, ["disappointed"] = true,
    ["angry"] = true, ["rage"] = true, ["frustrated"] = true, ["facepalm"] = true,
    -- Humor
    ["laugh"] = true, ["lol"] = true, ["rofl"] = true, ["giggle"] = true,
    ["chuckle"] = true, ["snicker"] = true, ["cackle"] = true, ["guffaw"] = true,
    -- Actions
    ["dance"] = true, ["flex"] = true, ["point"] = true, ["beckon"] = true,
    ["kneel"] = true, ["beg"] = true, ["grovel"] = true, ["apologize"] = true,
    ["bonk"] = true, ["poke"] = true, ["slap"] = true, ["tickle"] = true,
    ["pounce"] = true, ["charge"] = true, ["attacktarget"] = true,
    -- Taunts/Rude
    ["rude"] = true, ["taunt"] = true, ["chicken"] = true, ["mock"] = true,
    ["spit"] = true, ["raspberry"] = true, ["insult"] = true, ["threaten"] = true,
    ["gloat"] = true, ["train"] = true,
    -- States
    ["bored"] = true, ["yawn"] = true, ["sleep"] = true, ["tired"] = true,
    ["cower"] = true, ["scared"] = true, ["shy"] = true, ["blush"] = true,
    ["confused"] = true, ["puzzled"] = true, ["curious"] = true, ["think"] = true,
    ["surprised"] = true, ["gasp"] = true, ["drool"] = true, ["hungry"] = true,
    -- Sounds/Expressions
    ["roar"] = true, ["growl"] = true, ["bark"] = true, ["moo"] = true,
    ["meow"] = true, ["purr"] = true, ["rasp"] = true, ["whistle"] = true,
    ["cough"] = true, ["burp"] = true, ["fart"] = true, ["sniffle"] = true,
    ["sniff"] = true, ["snort"] = true, ["crack"] = true,
    -- Combat/Group
    ["oom"] = true, ["incoming"] = true, ["charge"] = true, ["flee"] = true,
    ["retreat"] = true, ["follow"] = true, ["wait"] = true, ["healme"] = true,
    ["openfire"] = true, ["assist"] = true, ["ready"] = true, ["victory"] = true,
    ["surrender"] = true, ["doom"] = true,
    -- Misc
    ["drink"] = true, ["eat"] = true, ["sit"] = true, ["stand"] = true,
    ["lay"] = true, ["bounce"] = true, ["fidget"] = true, ["tap"] = true,
    ["peer"] = true, ["stare"] = true, ["glare"] = true, ["eye"] = true,
    ["pray"] = true, ["violin"] = true, ["mourn"] = true, ["shoo"] = true,
}

-- Known gathering materials (itemID -> gatherType) - Classic + TBC (1-70)
local GATHERING_MATERIALS = {
    -- ========== MINING ==========
    -- Ores
    [2770] = "Mining",   -- Copper Ore
    [2771] = "Mining",   -- Tin Ore
    [2775] = "Mining",   -- Silver Ore
    [2772] = "Mining",   -- Iron Ore
    [2776] = "Mining",   -- Gold Ore
    [3858] = "Mining",   -- Mithril Ore
    [7911] = "Mining",   -- Truesilver Ore
    [10620] = "Mining",  -- Thorium Ore
    [11370] = "Mining",  -- Dark Iron Ore
    [23424] = "Mining",  -- Fel Iron Ore
    [23425] = "Mining",  -- Adamantite Ore
    [23426] = "Mining",  -- Khorium Ore
    [23427] = "Mining",  -- Eternium Ore
    -- Stones
    [2835] = "Mining",   -- Rough Stone
    [2836] = "Mining",   -- Coarse Stone
    [2838] = "Mining",   -- Heavy Stone
    [7912] = "Mining",   -- Solid Stone
    [12365] = "Mining",  -- Dense Stone
    -- Classic Gems
    [774] = "Mining",    -- Malachite
    [818] = "Mining",    -- Tigerseye
    [1210] = "Mining",   -- Shadowgem
    [1206] = "Mining",   -- Moss Agate
    [1705] = "Mining",   -- Lesser Moonstone
    [1529] = "Mining",   -- Jade
    [3864] = "Mining",   -- Citrine
    [7909] = "Mining",   -- Aquamarine
    [7910] = "Mining",   -- Star Ruby
    [12800] = "Mining",  -- Azerothian Diamond
    [12361] = "Mining",  -- Blue Sapphire
    [12364] = "Mining",  -- Huge Emerald
    [12799] = "Mining",  -- Large Opal
    [12363] = "Mining",  -- Arcane Crystal
    -- TBC Uncommon Gems
    [21929] = "Mining",  -- Flame Spessarite
    [23077] = "Mining",  -- Blood Garnet
    [23079] = "Mining",  -- Deep Peridot
    [23107] = "Mining",  -- Shadow Draenite
    [23112] = "Mining",  -- Golden Draenite
    [23117] = "Mining",  -- Azure Moonstone
    -- TBC Rare Gems
    [23436] = "Mining",  -- Living Ruby
    [23437] = "Mining",  -- Talasite
    [23438] = "Mining",  -- Star of Elune
    [23439] = "Mining",  -- Noble Topaz
    [23440] = "Mining",  -- Dawnstone
    [23441] = "Mining",  -- Nightseye
    -- Motes (from mining)
    [22573] = "Mining",  -- Mote of Fire
    [22574] = "Mining",  -- Mote of Earth

    -- ========== HERBALISM ==========
    -- Classic Herbs (1-300)
    [765] = "Herbalism",   -- Silverleaf
    [2447] = "Herbalism",  -- Peacebloom
    [2449] = "Herbalism",  -- Earthroot
    [785] = "Herbalism",   -- Mageroyal
    [2450] = "Herbalism",  -- Briarthorn
    [2452] = "Herbalism",  -- Swiftthistle
    [2453] = "Herbalism",  -- Bruiseweed
    [3355] = "Herbalism",  -- Wild Steelbloom
    [3369] = "Herbalism",  -- Grave Moss
    [3356] = "Herbalism",  -- Kingsblood
    [3357] = "Herbalism",  -- Liferoot
    [3818] = "Herbalism",  -- Fadeleaf
    [3821] = "Herbalism",  -- Goldthorn
    [3358] = "Herbalism",  -- Khadgar's Whisker
    [3819] = "Herbalism",  -- Wintersbite
    [3820] = "Herbalism",  -- Stranglekelp
    [4625] = "Herbalism",  -- Firebloom
    [8831] = "Herbalism",  -- Purple Lotus
    [8836] = "Herbalism",  -- Arthas' Tears
    [8838] = "Herbalism",  -- Sungrass
    [8839] = "Herbalism",  -- Blindweed
    [8845] = "Herbalism",  -- Ghost Mushroom
    [8846] = "Herbalism",  -- Gromsblood
    [13463] = "Herbalism", -- Dreamfoil
    [13464] = "Herbalism", -- Golden Sansam
    [13465] = "Herbalism", -- Mountain Silversage
    [13466] = "Herbalism", -- Plaguebloom
    [13467] = "Herbalism", -- Icecap
    [13468] = "Herbalism", -- Black Lotus
    -- TBC Herbs (300-375)
    [22785] = "Herbalism", -- Felweed
    [22786] = "Herbalism", -- Dreaming Glory
    [22787] = "Herbalism", -- Ragveil
    [22789] = "Herbalism", -- Terocone
    [22790] = "Herbalism", -- Ancient Lichen
    [22791] = "Herbalism", -- Netherbloom
    [22792] = "Herbalism", -- Nightmare Vine
    [22793] = "Herbalism", -- Mana Thistle
    [22794] = "Herbalism", -- Fel Lotus
    -- Motes (from herbalism)
    [22575] = "Herbalism", -- Mote of Life
    [22576] = "Herbalism", -- Mote of Mana

    -- ========== SKINNING ==========
    -- Classic Leather
    [2934] = "Skinning",  -- Ruined Leather Scraps
    [2318] = "Skinning",  -- Light Leather
    [783] = "Skinning",   -- Light Hide
    [2319] = "Skinning",  -- Medium Leather
    [4232] = "Skinning",  -- Medium Hide
    [4234] = "Skinning",  -- Heavy Leather
    [4235] = "Skinning",  -- Heavy Hide
    [4304] = "Skinning",  -- Thick Leather
    [8169] = "Skinning",  -- Thick Hide
    [8170] = "Skinning",  -- Rugged Leather
    [8171] = "Skinning",  -- Rugged Hide
    -- Classic Special Leather
    [7286] = "Skinning",  -- Black Whelp Scale
    [7287] = "Skinning",  -- Red Whelp Scale
    [15412] = "Skinning", -- Green Dragonscale
    [15414] = "Skinning", -- Red Dragonscale
    [15415] = "Skinning", -- Blue Dragonscale
    [15416] = "Skinning", -- Black Dragonscale
    [15417] = "Skinning", -- Devilsaur Leather
    [15419] = "Skinning", -- Warbear Leather
    [15408] = "Skinning", -- Heavy Scorpid Scale
    [15410] = "Skinning", -- Scale of Onyxia
    [17012] = "Skinning", -- Core Leather
    [15422] = "Skinning", -- Frostsaber Leather
    [15423] = "Skinning", -- Chimera Leather
    [20381] = "Skinning", -- Dreamscale
    -- TBC Leather
    [25649] = "Skinning", -- Knothide Leather Scraps
    [25700] = "Skinning", -- Knothide Leather
    [25699] = "Skinning", -- Crystal Infused Leather
    [29539] = "Skinning", -- Cobra Scales
    [29547] = "Skinning", -- Wind Scales
    [25707] = "Skinning", -- Fel Scales
    [25708] = "Skinning", -- Thick Clefthoof Leather
    [29548] = "Skinning", -- Nether Dragonscales
    [32470] = "Skinning", -- Nethermine Flayer Hide
}

-- Boss kill dedup (30 second cooldown per boss)
local bossKillCooldowns = {}

-- ============ BOSS NPC DATABASE ============
-- { [npcID] = { bossName, instanceName, isFinalBoss } }
local BOSS_DATABASE = {
    -- === TBC DUNGEONS (Final Bosses) ===
    [18373] = { "Epoch Hunter", "Old Hillsbrad Foothills", true },
    [17881] = { "Aeonus", "The Black Morass", true },
    [17882] = { "Temporus", "The Black Morass", false },
    [17880] = { "Chrono Lord Deja", "The Black Morass", false },
    [16808] = { "Warchief Kargath Bladefist", "The Shattered Halls", true },
    [17798] = { "Warlord Kalithresh", "The Steamvault", true },
    [17797] = { "Hydromancer Thespia", "The Steamvault", false },
    [17796] = { "Mekgineer Steamrigger", "The Steamvault", false },
    [17942] = { "Quagmirran", "The Slave Pens", true },
    [17991] = { "The Black Stalker", "The Underbog", true },
    [18344] = { "Nexus-Prince Shaffar", "Mana-Tombs", true },
    [18373] = { "Epoch Hunter", "Old Hillsbrad Foothills", true },
    [18096] = { "Epoch Hunter", "Old Hillsbrad Foothills", true },
    [18708] = { "Murmur", "Shadow Labyrinth", true },
    [18731] = { "Ambassador Hellmaw", "Shadow Labyrinth", false },
    [18667] = { "Blackheart the Inciter", "Shadow Labyrinth", false },
    [18732] = { "Grandmaster Vorpil", "Shadow Labyrinth", false },
    [17977] = { "Warp Splinter", "The Botanica", true },
    [20870] = { "Zereketh the Unbound", "The Arcatraz", false },
    [20885] = { "Dalliah the Doomsayer", "The Arcatraz", false },
    [20886] = { "Wrath-Scryer Soccothrates", "The Arcatraz", false },
    [20912] = { "Harbinger Skyriss", "The Arcatraz", true },
    [19220] = { "Pathaleon the Calculator", "The Mechanar", true },
    [19219] = { "Mechano-Lord Capacitus", "The Mechanar", false },
    [19218] = { "Gatewatcher Gyro-Kill", "The Mechanar", false },
    [19221] = { "Gatewatcher Iron-Hand", "The Mechanar", false },
    [17536] = { "Nazan", "Hellfire Ramparts", true },
    [17537] = { "Vazruden the Herald", "Hellfire Ramparts", true },
    [17381] = { "Watchkeeper Gargolmar", "Hellfire Ramparts", false },
    [17380] = { "Omor the Unscarred", "Hellfire Ramparts", false },
    [17377] = { "Keli'dan the Breaker", "The Blood Furnace", true },
    [17711] = { "Broggok", "The Blood Furnace", false },
    [17670] = { "The Maker", "The Blood Furnace", false },
    [18472] = { "Exarch Maladaar", "Auchenai Crypts", true },
    [18371] = { "Shirrak the Dead Watcher", "Auchenai Crypts", false },
    [18478] = { "Talon King Ikiss", "Sethekk Halls", true },
    [18473] = { "Darkweaver Syth", "Sethekk Halls", false },
    [18521] = { "Anzu", "Sethekk Halls", false },
    [20266] = { "Aeonus", "The Black Morass", true },

    -- === TBC RAIDS ===
    -- Karazhan
    [15550] = { "Attumen the Huntsman", "Karazhan", false },
    [16151] = { "Midnight", "Karazhan", false },
    [15687] = { "Moroes", "Karazhan", false },
    [16457] = { "Maiden of Virtue", "Karazhan", false },
    [15691] = { "The Curator", "Karazhan", false },
    [15688] = { "Terestian Illhoof", "Karazhan", false },
    [16524] = { "Shade of Aran", "Karazhan", false },
    [15689] = { "Netherspite", "Karazhan", false },
    [15690] = { "Prince Malchezaar", "Karazhan", true },
    [17225] = { "Nightbane", "Karazhan", false },
    -- Gruul's Lair
    [18831] = { "High King Maulgar", "Gruul's Lair", false },
    [19044] = { "Gruul the Dragonkiller", "Gruul's Lair", true },
    -- Magtheridon's Lair
    [17257] = { "Magtheridon", "Magtheridon's Lair", true },
    -- Serpentshrine Cavern
    [21216] = { "Hydross the Unstable", "Serpentshrine Cavern", false },
    [21217] = { "The Lurker Below", "Serpentshrine Cavern", false },
    [21215] = { "Leotheras the Blind", "Serpentshrine Cavern", false },
    [21214] = { "Fathom-Lord Karathress", "Serpentshrine Cavern", false },
    [21213] = { "Morogrim Tidewalker", "Serpentshrine Cavern", false },
    [21212] = { "Lady Vashj", "Serpentshrine Cavern", true },
    -- Tempest Keep
    [19514] = { "Al'ar", "Tempest Keep", false },
    [19516] = { "Void Reaver", "Tempest Keep", false },
    [18805] = { "High Astromancer Solarian", "Tempest Keep", false },
    [19622] = { "Kael'thas Sunstrider", "Tempest Keep", true },
    -- Hyjal Summit
    [17767] = { "Rage Winterchill", "Hyjal Summit", false },
    [17808] = { "Anetheron", "Hyjal Summit", false },
    [17888] = { "Kaz'rogal", "Hyjal Summit", false },
    [17842] = { "Azgalor", "Hyjal Summit", false },
    [17968] = { "Archimonde", "Hyjal Summit", true },
    -- Black Temple
    [22887] = { "High Warlord Naj'entus", "Black Temple", false },
    [22898] = { "Supremus", "Black Temple", false },
    [22841] = { "Shade of Akama", "Black Temple", false },
    [22871] = { "Teron Gorefiend", "Black Temple", false },
    [22948] = { "Gurtogg Bloodboil", "Black Temple", false },
    [23420] = { "Reliquary of Souls", "Black Temple", false },
    [22947] = { "Mother Shahraz", "Black Temple", false },
    [23426] = { "Illidari Council", "Black Temple", false },
    [22917] = { "Illidan Stormrage", "Black Temple", true },
    -- Sunwell Plateau
    [24891] = { "Kalecgos", "Sunwell Plateau", false },
    [25038] = { "Brutallus", "Sunwell Plateau", false },
    [25165] = { "Felmyst", "Sunwell Plateau", false },
    [25166] = { "Grand Warlock Alythess", "Sunwell Plateau", false },
    [25741] = { "M'uru", "Sunwell Plateau", false },
    [25315] = { "Kil'jaeden", "Sunwell Plateau", true },
    -- Zul'Aman
    [23574] = { "Akil'zon", "Zul'Aman", false },
    [23576] = { "Nalorakk", "Zul'Aman", false },
    [23578] = { "Jan'alai", "Zul'Aman", false },
    [23577] = { "Halazzi", "Zul'Aman", false },
    [24239] = { "Hex Lord Malacrass", "Zul'Aman", false },
    [23863] = { "Zul'jin", "Zul'Aman", true },

    -- === VANILLA RAIDS ===
    -- Molten Core
    [12118] = { "Lucifron", "Molten Core", false },
    [11982] = { "Magmadar", "Molten Core", false },
    [12259] = { "Gehennas", "Molten Core", false },
    [12057] = { "Garr", "Molten Core", false },
    [12264] = { "Shazzrah", "Molten Core", false },
    [12056] = { "Baron Geddon", "Molten Core", false },
    [11988] = { "Golemagg the Incinerator", "Molten Core", false },
    [12098] = { "Sulfuron Harbinger", "Molten Core", false },
    [12018] = { "Majordomo Executus", "Molten Core", false },
    [11502] = { "Ragnaros", "Molten Core", true },
    -- Blackwing Lair
    [12435] = { "Razorgore the Untamed", "Blackwing Lair", false },
    [13020] = { "Vaelastrasz the Corrupt", "Blackwing Lair", false },
    [12017] = { "Broodlord Lashlayer", "Blackwing Lair", false },
    [11983] = { "Firemaw", "Blackwing Lair", false },
    [14601] = { "Ebonroc", "Blackwing Lair", false },
    [11981] = { "Flamegor", "Blackwing Lair", false },
    [14020] = { "Chromaggus", "Blackwing Lair", false },
    [11583] = { "Nefarian", "Blackwing Lair", true },
    -- Onyxia's Lair
    [10184] = { "Onyxia", "Onyxia's Lair", true },
    -- AQ20
    [15348] = { "Kurinnaxx", "Ruins of Ahn'Qiraj", false },
    [15341] = { "General Rajaxx", "Ruins of Ahn'Qiraj", false },
    [15340] = { "Moam", "Ruins of Ahn'Qiraj", false },
    [15370] = { "Buru the Gorger", "Ruins of Ahn'Qiraj", false },
    [15369] = { "Ayamiss the Hunter", "Ruins of Ahn'Qiraj", false },
    [15339] = { "Ossirian the Unscarred", "Ruins of Ahn'Qiraj", true },
    -- AQ40
    [15263] = { "The Prophet Skeram", "Temple of Ahn'Qiraj", false },
    [15544] = { "Vem", "Temple of Ahn'Qiraj", false },
    [15516] = { "Battleguard Sartura", "Temple of Ahn'Qiraj", false },
    [15510] = { "Fankriss the Unyielding", "Temple of Ahn'Qiraj", false },
    [15299] = { "Viscidus", "Temple of Ahn'Qiraj", false },
    [15509] = { "Princess Huhuran", "Temple of Ahn'Qiraj", false },
    [15276] = { "Emperor Vek'lor", "Temple of Ahn'Qiraj", false },
    [15275] = { "Emperor Vek'nilash", "Temple of Ahn'Qiraj", false },
    [15517] = { "Ouro", "Temple of Ahn'Qiraj", false },
    [15727] = { "C'Thun", "Temple of Ahn'Qiraj", true },
    -- Naxxramas
    [15956] = { "Anub'Rekhan", "Naxxramas", false },
    [15953] = { "Grand Widow Faerlina", "Naxxramas", false },
    [15952] = { "Maexxna", "Naxxramas", false },
    [15954] = { "Noth the Plaguebringer", "Naxxramas", false },
    [15936] = { "Heigan the Unclean", "Naxxramas", false },
    [16011] = { "Loatheb", "Naxxramas", false },
    [16061] = { "Instructor Razuvious", "Naxxramas", false },
    [16060] = { "Gothik the Harvester", "Naxxramas", false },
    [16062] = { "Highlord Mograine", "Naxxramas", false },
    [16028] = { "Patchwerk", "Naxxramas", false },
    [15931] = { "Grobbulus", "Naxxramas", false },
    [15932] = { "Gluth", "Naxxramas", false },
    [15928] = { "Thaddius", "Naxxramas", false },
    [15989] = { "Sapphiron", "Naxxramas", false },
    [15990] = { "Kel'Thuzad", "Naxxramas", true },
    -- Zul'Gurub
    [14517] = { "High Priestess Jeklik", "Zul'Gurub", false },
    [14507] = { "High Priest Venoxis", "Zul'Gurub", false },
    [14510] = { "High Priestess Mar'li", "Zul'Gurub", false },
    [14509] = { "High Priest Thekal", "Zul'Gurub", false },
    [14515] = { "High Priestess Arlokk", "Zul'Gurub", false },
    [11382] = { "Bloodlord Mandokir", "Zul'Gurub", false },
    [11380] = { "Jin'do the Hexxer", "Zul'Gurub", false },
    [15114] = { "Gahz'ranka", "Zul'Gurub", false },
    [14834] = { "Hakkar", "Zul'Gurub", true },

    -- === VANILLA DUNGEON FINAL BOSSES ===
    [1853]  = { "Darkmaster Gandling", "Scholomance", true },
    [10440] = { "Baron Rivendare", "Stratholme", true },
    [9019]  = { "Emperor Dagran Thaurissan", "Blackrock Depths", true },
    [10363] = { "General Drakkisath", "Upper Blackrock Spire", true },
    [9568]  = { "Overlord Wyrmthalak", "Lower Blackrock Spire", true },
    [5709]  = { "Shade of Eranikus", "Sunken Temple", true },
    [7358]  = { "Chief Ukorz Sandscalp", "Zul'Farrak", true },
    [4829]  = { "Aku'mai", "Blackfathom Deeps", true },
    [7800]  = { "Mekgineer Thermaplugg", "Gnomeregan", true },
    [4421]  = { "Charlga Razorflank", "Razorfen Kraul", true },
    [7355]  = { "Tuten'kash", "Razorfen Downs", false },
    [7358]  = { "Amnennar the Coldbringer", "Razorfen Downs", true },
    [3654]  = { "Mutanus the Devourer", "Wailing Caverns", true },
    [639]   = { "Edwin VanCleef", "The Deadmines", true },
    [3975]  = { "Herod", "Scarlet Monastery", false },
    [3977]  = { "High Inquisitor Whitemane", "Scarlet Monastery", true },
    [6487]  = { "Arcanist Doan", "Scarlet Monastery", false },
    [3974]  = { "Houndmaster Loksey", "Scarlet Monastery", false },
    [7361]  = { "Archaedas", "Uldaman", true },
    [12201] = { "Princess Theradras", "Maraudon", true },
    [11520] = { "Alzzin the Wildshaper", "Dire Maul", true },
    [11501] = { "King Gordok", "Dire Maul", true },
    [11496] = { "Immol'thar", "Dire Maul", true },
}

-- Raid instance lookup (for categorizing boss kills)
local RAID_INSTANCES = {
    -- Vanilla
    ["Molten Core"] = true, ["Blackwing Lair"] = true, ["Onyxia's Lair"] = true,
    ["Ruins of Ahn'Qiraj"] = true, ["Temple of Ahn'Qiraj"] = true,
    ["Naxxramas"] = true, ["Zul'Gurub"] = true,
    -- TBC
    ["Karazhan"] = true, ["Gruul's Lair"] = true, ["Magtheridon's Lair"] = true,
    ["Serpentshrine Cavern"] = true, ["Tempest Keep"] = true,
    ["Hyjal Summit"] = true, ["Black Temple"] = true,
    ["Sunwell Plateau"] = true, ["Zul'Aman"] = true,
}
PS.RAID_INSTANCES = RAID_INSTANCES

-- Extract NPC ID from GUID
local function GetNpcIdFromGuid(guid)
    if not guid then return nil end
    local _, _, _, _, _, npcId = strsplit("-", guid)
    return tonumber(npcId)
end

-- Session save
function PS:SaveSession()
    if not self.db then return end
    self.db.session = {
        start = self.sessionStart,
        kills = self.sessionKills,
        deaths = self.sessionDeaths,
        damage = self.sessionDamage,
        healing = self.sessionHealing,
        gathering = self.sessionGathering,
        pvpKills = self.sessionPvPKills,
        pvpDeaths = self.sessionPvPDeaths,
        lastSeen = time(),
    }
end

local tracker = CreateFrame("Frame")
tracker:RegisterEvent("PLAYER_LOGIN")

tracker:SetScript("OnEvent", function(self, event, ...)
    if event == "PLAYER_LOGIN" then
        self:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
        self:RegisterEvent("PLAYER_DEAD")
        self:RegisterEvent("QUEST_TURNED_IN")
        self:RegisterEvent("CHAT_MSG_MONEY")
        self:RegisterEvent("CHAT_MSG_COMBAT_HONOR_GAIN")
        self:RegisterEvent("CHAT_MSG_SYSTEM")
        self:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
        self:RegisterEvent("UNIT_SPELLCAST_SENT")
        self:RegisterEvent("CHAT_MSG_LOOT")
        self:RegisterEvent("DUEL_FINISHED")
        self:RegisterEvent("UNIT_AURA")
        self:RegisterEvent("PLAYER_ENTERING_WORLD")
        self:RegisterEvent("UPDATE_BATTLEFIELD_STATUS")
        self:RegisterEvent("CHAT_MSG_BG_SYSTEM_ALLIANCE")
        self:RegisterEvent("CHAT_MSG_BG_SYSTEM_HORDE")
        self:RegisterEvent("MERCHANT_SHOW")
        self:RegisterEvent("MERCHANT_CLOSED")
        self:RegisterEvent("PLAYER_MONEY")
        self:RegisterEvent("PLAYER_LOGOUT")
        self:RegisterEvent("CHAT_MSG_TEXT_EMOTE")

        -- Hook jump tracking
        if JumpOrAscendStart then
            hooksecurefunc("JumpOrAscendStart", function()
                if PS.db then PS.db.stats.jumps = PS.db.stats.jumps + 1 end
            end)
        end

        lastKnownMoney = GetMoney()
        return
    end

    local db = PS.db
    if not db then return end

    -- ======== COMBAT LOG ========
    if event == "COMBAT_LOG_EVENT_UNFILTERED" then
        local timestamp, subevent, hideCaster,
              sourceGUID, sourceName, sourceFlags, sourceRaidFlags,
              destGUID, destName, destFlags, destRaidFlags,
              arg12, arg13, arg14, arg15, arg16, arg17, arg18,
              arg19, arg20, arg21 = CombatLogGetCurrentEventInfo()

        local isMine = sourceFlags and bit.band(sourceFlags, COMBATLOG_OBJECT_AFFILIATION_MINE) > 0
        local isMe = sourceGUID == PS.playerGUID
        local destIsMe = destGUID == PS.playerGUID
        local destIsPlayer = destFlags and bit.band(destFlags, COMBATLOG_OBJECT_TYPE_PLAYER) > 0
        local destIsHostile = destFlags and bit.band(destFlags, COMBATLOG_OBJECT_REACTION_HOSTILE) > 0

        -- KILLING BLOWS (player + pets)
        if subevent == "PARTY_KILL" and isMine then
            db.stats.totalKills = db.stats.totalKills + 1
            PS.sessionKills = PS.sessionKills + 1
            if destIsPlayer and destIsHostile then
                db.stats.pvpKills = db.stats.pvpKills + 1
                PS.sessionPvPKills = PS.sessionPvPKills + 1
                if PS.settings and PS.settings.pvpKillSound then
                    PlaySoundFile("Interface\\AddOns\\PlayerStats\\sound_files\\kaching.ogg", "Master")
                end
                if PS.OnPvPKill then PS:OnPvPKill(destName) end
                -- Per-BG kill tracking
                if inBG and bgName then
                    if not db.bgStats[bgName] then db.bgStats[bgName] = { wins = 0, losses = 0 } end
                    db.bgStats[bgName].kills = (db.bgStats[bgName].kills or 0) + 1
                end
            end
            -- Critter detection: non-hostile NPC kills
            if not destIsPlayer and not destIsHostile then
                local destIsNPC = destFlags and bit.band(destFlags, COMBATLOG_OBJECT_TYPE_NPC) > 0
                if destIsNPC then
                    db.stats.critterKills = (db.stats.critterKills or 0) + 1
                end
            end
            if PS.RefreshMini then PS:RefreshMini() end

        -- DAMAGE DEALT
        elseif isMine and (subevent == "SWING_DAMAGE" or subevent == "SPELL_DAMAGE"
               or subevent == "SPELL_PERIODIC_DAMAGE" or subevent == "RANGE_DAMAGE") then

            local spellId, spellName, amount, critical
            if subevent == "SWING_DAMAGE" then
                amount = arg12
                critical = arg18
            else
                spellId = arg12
                spellName = arg13
                amount = arg15
                critical = arg21
            end

            if amount and amount > 0 then
                db.stats.totalDamage = db.stats.totalDamage + amount
                PS.sessionDamage = PS.sessionDamage + amount
                if amount > db.stats.highestHit then
                    db.stats.highestHit = amount
                    db.stats.highestHitSpell = spellName or "Melee"
                    db.stats.highestHitTarget = destName or ""
                end
                if critical then db.stats.critCount = db.stats.critCount + 1 end
                if isMe and spellId and spellId > 0 then
                    if not db.spells[spellId] then
                        db.spells[spellId] = { name = spellName, casts = 0, damage = 0, healing = 0, crits = 0, highestHit = 0 }
                    end
                    db.spells[spellId].damage = db.spells[spellId].damage + amount
                    if amount > (db.spells[spellId].highestHit or 0) then
                        db.spells[spellId].highestHit = amount
                    end
                    if critical then db.spells[spellId].crits = db.spells[spellId].crits + 1 end
                end
            end

        -- HEALING DONE
        elseif isMine and (subevent == "SPELL_HEAL" or subevent == "SPELL_PERIODIC_HEAL") then
            local spellId = arg12
            local spellName = arg13
            local amount = arg15
            local overhealing = arg16
            local critical = arg18

            if amount and amount > 0 then
                local effective = amount - (overhealing or 0)
                if effective > 0 then
                    db.stats.totalHealing = db.stats.totalHealing + effective
                    PS.sessionHealing = PS.sessionHealing + effective
                end
                if amount > db.stats.highestHeal then
                    db.stats.highestHeal = amount
                    db.stats.highestHealSpell = spellName or ""
                end
                if isMe and spellId and spellId > 0 then
                    if not db.spells[spellId] then
                        db.spells[spellId] = { name = spellName, casts = 0, damage = 0, healing = 0, crits = 0, highestHit = 0 }
                    end
                    db.spells[spellId].healing = db.spells[spellId].healing + (effective > 0 and effective or 0)
                    if amount > (db.spells[spellId].highestHit or 0) then
                        db.spells[spellId].highestHit = amount
                    end
                    if critical then db.spells[spellId].crits = db.spells[spellId].crits + 1 end
                end
            end

        -- DAMAGE TAKEN
        elseif destIsMe and (subevent == "SWING_DAMAGE" or subevent == "SPELL_DAMAGE"
               or subevent == "SPELL_PERIODIC_DAMAGE" or subevent == "RANGE_DAMAGE"
               or subevent == "ENVIRONMENTAL_DAMAGE") then

            local amount
            if subevent == "SWING_DAMAGE" then
                amount = arg12
            elseif subevent == "ENVIRONMENTAL_DAMAGE" then
                amount = arg13
            else
                amount = arg15
            end
            if amount and amount > 0 then
                db.stats.totalDamageTaken = db.stats.totalDamageTaken + amount
                lastDmgFlags = sourceFlags or 0
                lastDmgTime = GetTime()
            end

        -- SPELL CAST SUCCESS (cast counter - player only)
        elseif isMe and subevent == "SPELL_CAST_SUCCESS" then
            local spellId = arg12
            local spellName = arg13

            -- Hearthstone tracking (all teleport-home spells)
            if spellId == HEARTHSTONE_SPELL or spellId == ASTRAL_RECALL_SPELL or spellId == NAARUS_EMBRACE_SPELL then
                db.stats.hearthstoneUses = (db.stats.hearthstoneUses or 0) + 1
            end

            if spellId and spellId > 0 then
                if not db.spells[spellId] then
                    db.spells[spellId] = { name = spellName, casts = 0, damage = 0, healing = 0, crits = 0 }
                end
                db.spells[spellId].casts = db.spells[spellId].casts + 1
            end

        -- DISPELS (exclude PvP trinket)
        elseif isMine and (subevent == "SPELL_DISPEL" or subevent == "SPELL_STOLEN") then
            local spellId = arg12
            if spellId == PVP_TRINKET_SPELL then
                db.stats.pvpTrinketUses = (db.stats.pvpTrinketUses or 0) + 1
            else
                db.stats.dispels = (db.stats.dispels or 0) + 1
            end

        -- UNIT_DIED (boss kill tracking)
        elseif subevent == "UNIT_DIED" then
            local npcId = GetNpcIdFromGuid(destGUID)
            if npcId and BOSS_DATABASE[npcId] then
                local now = GetTime()
                if not bossKillCooldowns[npcId] or (now - bossKillCooldowns[npcId]) > 30 then
                    bossKillCooldowns[npcId] = now
                    local bossInfo = BOSS_DATABASE[npcId]
                    local bossName = bossInfo[1]
                    local instanceName = bossInfo[2]
                    local isFinalBoss = bossInfo[3]

                    local isRaid = RAID_INSTANCES[instanceName]
                    db.stats.bossKills = (db.stats.bossKills or 0) + 1

                    if isRaid then
                        db.stats.raidBossKills = (db.stats.raidBossKills or 0) + 1
                    else
                        db.stats.dungeonBossKills = (db.stats.dungeonBossKills or 0) + 1
                    end

                    -- Track per-instance boss kills
                    if not db.pveStats[instanceName] then
                        db.pveStats[instanceName] = { bosses = {}, completed = 0 }
                    end
                    db.pveStats[instanceName].bosses[bossName] = (db.pveStats[instanceName].bosses[bossName] or 0) + 1

                    -- Final boss = instance cleared
                    if isFinalBoss then
                        db.pveStats[instanceName].completed = (db.pveStats[instanceName].completed or 0) + 1
                        if isRaid then
                            db.stats.raidsCompleted = (db.stats.raidsCompleted or 0) + 1
                        else
                            db.stats.dungeonsCompleted = (db.stats.dungeonsCompleted or 0) + 1
                        end
                    end
                end
            end
        end

    -- ======== DEATH ========
    elseif event == "PLAYER_DEAD" then
        db.stats.deaths = db.stats.deaths + 1
        PS.sessionDeaths = PS.sessionDeaths + 1
        if (GetTime() - lastDmgTime) < 5 then
            local fromPlayer = bit.band(lastDmgFlags, COMBATLOG_OBJECT_TYPE_PLAYER) > 0
                or bit.band(lastDmgFlags, COMBATLOG_OBJECT_CONTROL_PLAYER) > 0
            if fromPlayer then
                db.stats.pvpDeaths = db.stats.pvpDeaths + 1
                PS.sessionPvPDeaths = PS.sessionPvPDeaths + 1
                -- Per-BG death tracking
                if inBG and bgName then
                    if not db.bgStats[bgName] then db.bgStats[bgName] = { wins = 0, losses = 0 } end
                    db.bgStats[bgName].deaths = (db.bgStats[bgName].deaths or 0) + 1
                end
            end
        end
        if PS.OnPlayerDeath then PS:OnPlayerDeath() end
        if PS.RefreshMini then PS:RefreshMini() end

    -- ======== QUESTS ========
    elseif event == "QUEST_TURNED_IN" then
        db.stats.questsCompleted = db.stats.questsCompleted + 1
        if QuestIsDaily and QuestIsDaily() then
            db.stats.dailiesCompleted = (db.stats.dailiesCompleted or 0) + 1
        end
        questGoldPending = true

    -- ======== GOLD ========
    elseif event == "CHAT_MSG_MONEY" then
        local msg = ...
        local gold = tonumber(msg:match("(%d+) Gold")) or 0
        local silver = tonumber(msg:match("(%d+) Silver")) or 0
        local copper = tonumber(msg:match("(%d+) Copper")) or 0
        db.stats.goldLooted = db.stats.goldLooted + gold * 10000 + silver * 100 + copper
        lootGoldThisFrame = true

    -- ======== HONOR (kill-based) ========
    elseif event == "CHAT_MSG_COMBAT_HONOR_GAIN" then
        local msg = ...
        if msg:match("dies") or msg:match("honorable") then
            db.stats.honorableKills = db.stats.honorableKills + 1
        end
        local honor = tonumber(msg:match("(%d+) [Hh]onor")) or 0
        db.stats.honorEarned = db.stats.honorEarned + honor

    -- ======== HONOR (system messages for BG/quest honor) ========
    elseif event == "CHAT_MSG_SYSTEM" then
        local msg = ...
        local honor = tonumber(msg:match("awarded (%d+) honor"))
        if honor then
            db.stats.honorEarned = db.stats.honorEarned + honor
        end

    -- ======== FOOD/DRINK/FOOD BUFF (Aura-based) ========
    elseif event == "UNIT_AURA" then
        local unit = ...
        if unit ~= "player" then return end
        local isEating = false
        local isDrinking = false
        for i = 1, 40 do
            local name = UnitBuff("player", i)
            if not name then break end
            if name == "Food" or name == "Food & Drink" then isEating = true end
            if name == "Drink" or name == "Food & Drink" then isDrinking = true end
        end
        -- Track eating/drinking start
        if isEating and not wasEating then
            db.stats.foodEaten = db.stats.foodEaten + 1
        end
        if isDrinking and not wasDrinking then db.stats.drinksConsumed = db.stats.drinksConsumed + 1 end
        wasEating = isEating
        wasDrinking = isDrinking

    -- ======== GATHERING TARGET CAPTURE ========
    elseif event == "UNIT_SPELLCAST_SENT" then
        local unit, target, _, spellID = ...
        if unit ~= "player" then return end
        local spellName = spellID and GetSpellInfo(spellID)
        if spellName == "Mining" or spellName == "Herb Gathering" or spellName == "Skinning" then
            pendingGatherSpell = spellName
            pendingGatherTarget = target or "Unknown"
            pendingGatherTime = GetTime()
            gatherCountedThisNode = false
        end

    -- ======== HEARTHSTONE + CRAFTING + GATHERING + PVP TRINKET ========
    elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
        local unit = ...
        if unit ~= "player" then return end
        -- Handle both Classic (unit, spellName, rank, lineID, spellID)
        -- and modern (unit, castGUID, spellID) arg formats
        local spellName, spellID
        local arg2 = select(2, ...)
        local arg3 = select(3, ...)
        if type(arg3) == "number" then
            spellID = arg3
            spellName = GetSpellInfo(spellID)
        else
            spellName = arg2
            spellID = select(5, ...)
        end
        if spellID or spellName then
            if not spellName then spellName = GetSpellInfo(spellID) end
            -- Bandage detection (the channeled spell is called "First Aid")
            if spellName == "First Aid" then
                db.stats.bandagesUsed = (db.stats.bandagesUsed or 0) + 1
            end
            -- PvP Trinket (backup tracking via spellcast)
            if spellID == PVP_TRINKET_SPELL then
                db.stats.pvpTrinketUses = (db.stats.pvpTrinketUses or 0) + 1
            end
            -- Crafting: trade skill frame is open
            local isCrafting = (TradeSkillFrame and TradeSkillFrame:IsVisible())
                or (CraftFrame and CraftFrame:IsVisible())
            if isCrafting and spellID ~= HEARTHSTONE_SPELL then
                db.stats.itemsCrafted = (db.stats.itemsCrafted or 0) + 1
            end
            -- Gathering spell names kept in pendingGatherSpell - actual counting happens on loot
        end

    -- ======== FISHING & GATHERING LOOT ========
    elseif event == "CHAT_MSG_LOOT" then
        local msg = ...
        -- Fishing detection
        local mainHand = GetInventoryItemID("player", 16)
        if mainHand then
            local _, _, _, _, _, _, subType = GetItemInfo(mainHand)
            if (subType == "Fishing Poles" or subType == "Fishing Pole") and msg:match("You receive") then
                db.stats.fishCaught = db.stats.fishCaught + 1
            end
        end

        -- Gathering: check if we have a pending gather and looted a known material
        if pendingGatherSpell and (GetTime() - pendingGatherTime) < 5 then
            -- Parse item link from loot message: "You receive loot: [Item] x5"
            local itemLink = msg:match("|c%x+|Hitem:(%d+):")
            local itemID = itemLink and tonumber(itemLink)
            local quantity = tonumber(msg:match("x(%d+)")) or 1

            if itemID and GATHERING_MATERIALS[itemID] then
                local gatherType
                if pendingGatherSpell == "Mining" then gatherType = "Mining"
                elseif pendingGatherSpell == "Herb Gathering" then gatherType = "Herbalism"
                else gatherType = "Skinning" end

                local nodeName = pendingGatherTarget or "Unknown"
                if not db.gatheringStats[gatherType] then db.gatheringStats[gatherType] = {} end
                if not db.gatheringStats[gatherType][nodeName] then
                    db.gatheringStats[gatherType][nodeName] = { count = 0, items = {} }
                end
                -- Migrate old format (number) to new format (table)
                if type(db.gatheringStats[gatherType][nodeName]) == "number" then
                    db.gatheringStats[gatherType][nodeName] = { count = db.gatheringStats[gatherType][nodeName], items = {} }
                end

                local nodeData = db.gatheringStats[gatherType][nodeName]
                -- Only increment count once per gather (first loot item)
                if not gatherCountedThisNode then
                    nodeData.count = nodeData.count + 1
                    gatherCountedThisNode = true
                    db.stats.nodesGathered = (db.stats.nodesGathered or 0) + 1
                    PS.sessionGathering = PS.sessionGathering + 1
                end

                -- Track item received
                local itemName = GetItemInfo(itemID) or ("Item" .. itemID)
                nodeData.items[itemName] = (nodeData.items[itemName] or 0) + quantity
            end
        end

    -- ======== DUELS ========
    elseif event == "DUEL_FINISHED" then
        C_Timer.After(0.1, function()
            if UnitIsDeadOrGhost("player") or (UnitHealth("player") / UnitHealthMax("player")) < 0.1 then
                db.stats.duelsLost = db.stats.duelsLost + 1
            else
                db.stats.duelsWon = db.stats.duelsWon + 1
            end
        end)

    -- ======== INSTANCE / BG / ARENA TRACKING ========
    elseif event == "PLAYER_ENTERING_WORLD" then
        local isIn, instanceType = IsInInstance()
        if isIn then
            local instanceName = GetInstanceInfo()
            if instanceType == "pvp" then
                if not inBG then
                    inBG = true
                    inArena = false
                    bgName = instanceName
                    bgResultRecorded = false
                end
            elseif instanceType == "arena" then
                if not inArena then
                    inArena = true
                    inBG = false
                    bgName = instanceName
                    bgResultRecorded = false
                    local groupSize = GetNumGroupMembers()
                    if groupSize <= 2 then arenaBracket = "2v2"
                    elseif groupSize <= 3 then arenaBracket = "3v3"
                    else arenaBracket = "5v5" end
                end
            elseif instanceType == "party" or instanceType == "raid" then
                if instanceName ~= currentInstance then
                    currentInstance = instanceName
                    db.stats.instancesEntered = (db.stats.instancesEntered or 0) + 1
                end
            end
        else
            currentInstance = nil
            inBG = false
            inArena = false
            arenaBracket = nil
            bgName = nil
        end

    -- ======== BG / ARENA RESULTS ========
    elseif event == "UPDATE_BATTLEFIELD_STATUS" then
        if (inBG or inArena) and not bgResultRecorded then
            local winner = GetBattlefieldWinner()
            if winner ~= nil then
                bgResultRecorded = true
                local myFaction = UnitFactionGroup("player")
                local won = (winner == 0 and myFaction == "Horde") or
                            (winner == 1 and myFaction == "Alliance")
                local name = bgName or "Unknown"
                if inArena then
                    local bracket = arenaBracket or "5v5"
                    if won then
                        db.stats.arenaWins = (db.stats.arenaWins or 0) + 1
                    else
                        db.stats.arenaLosses = (db.stats.arenaLosses or 0) + 1
                    end
                    if not db.arenaStats then db.arenaStats = {} end
                    if not db.arenaStats[bracket] then
                        db.arenaStats[bracket] = { wins = 0, losses = 0, maps = {} }
                    end
                    if won then
                        db.arenaStats[bracket].wins = db.arenaStats[bracket].wins + 1
                    else
                        db.arenaStats[bracket].losses = db.arenaStats[bracket].losses + 1
                    end
                    -- Per-map tracking within bracket
                    if not db.arenaStats[bracket].maps then db.arenaStats[bracket].maps = {} end
                    if not db.arenaStats[bracket].maps[name] then
                        db.arenaStats[bracket].maps[name] = { wins = 0, losses = 0 }
                    end
                    if won then
                        db.arenaStats[bracket].maps[name].wins = db.arenaStats[bracket].maps[name].wins + 1
                    else
                        db.arenaStats[bracket].maps[name].losses = db.arenaStats[bracket].maps[name].losses + 1
                    end
                else
                    if won then
                        db.stats.bgWins = (db.stats.bgWins or 0) + 1
                    else
                        db.stats.bgLosses = (db.stats.bgLosses or 0) + 1
                    end
                    if not db.bgStats then db.bgStats = {} end
                    if not db.bgStats[name] then
                        db.bgStats[name] = { wins = 0, losses = 0 }
                    end
                    if won then
                        db.bgStats[name].wins = db.bgStats[name].wins + 1
                    else
                        db.bgStats[name].losses = db.bgStats[name].losses + 1
                    end
                end
            end
        end

    -- ======== BG OBJECTIVES (flags, bases) ========
    elseif event == "CHAT_MSG_BG_SYSTEM_ALLIANCE" or event == "CHAT_MSG_BG_SYSTEM_HORDE" then
        if inBG and bgName then
            local msg = ...
            local pName = PS.playerName
            if pName and msg:match(pName) then
                if not db.bgStats[bgName] then db.bgStats[bgName] = { wins = 0, losses = 0 } end
                if msg:match("captured") then
                    db.bgStats[bgName].flagsCaptured = (db.bgStats[bgName].flagsCaptured or 0) + 1
                elseif msg:match("returned") then
                    db.bgStats[bgName].flagsReturned = (db.bgStats[bgName].flagsReturned or 0) + 1
                elseif msg:match("assaulted") or msg:match("claims") then
                    db.bgStats[bgName].basesAssaulted = (db.bgStats[bgName].basesAssaulted or 0) + 1
                elseif msg:match("defended") then
                    db.bgStats[bgName].basesDefended = (db.bgStats[bgName].basesDefended or 0) + 1
                end
            end
        end

    -- ======== GOLD SOURCE TRACKING (quest/vendor) ========
    elseif event == "MERCHANT_SHOW" then
        merchantOpen = true
    elseif event == "MERCHANT_CLOSED" then
        merchantOpen = false
    elseif event == "PLAYER_MONEY" then
        local current = GetMoney()
        local delta = current - lastKnownMoney
        lastKnownMoney = current
        if lootGoldThisFrame then
            lootGoldThisFrame = false
        elseif delta > 0 then
            if questGoldPending then
                db.stats.goldFromQuests = (db.stats.goldFromQuests or 0) + delta
                questGoldPending = false
            elseif merchantOpen then
                db.stats.goldFromVendors = (db.stats.goldFromVendors or 0) + delta
            end
        end

    -- ======== EMOTE TRACKING ========
    elseif event == "CHAT_MSG_TEXT_EMOTE" then
        local msg = ...
        -- Only track our own emotes (message starts with player name)
        if msg and PS.playerName and msg:find("^" .. PS.playerName) then
            -- Extract emote from DoEmote token pattern or common patterns
            -- Try to match the verb after the player name
            local emoteVerb = msg:match("^" .. PS.playerName .. " (%w+)")
            if emoteVerb then
                emoteVerb = emoteVerb:lower()
                -- Map common verb forms to base emote
                local emoteMap = {
                    -- Greetings
                    ["waves"] = "wave", ["bows"] = "bow", ["salutes"] = "salute",
                    ["welcomes"] = "welcome",
                    -- Positive
                    ["cheers"] = "cheer", ["claps"] = "clap", ["applauds"] = "applaud",
                    ["congratulates"] = "congratulate", ["nods"] = "nod", ["agrees"] = "agree",
                    ["smiles"] = "smile", ["grins"] = "grin", ["hugs"] = "hug",
                    ["cuddles"] = "cuddle", ["comforts"] = "comfort", ["pats"] = "pat",
                    ["loves"] = "love", ["kisses"] = "kiss", ["blows"] = "blow",
                    ["winks"] = "wink", ["flirts"] = "flirt",
                    -- Negative
                    ["disagrees"] = "disagree", ["shrugs"] = "shrug", ["sighs"] = "sigh",
                    ["cries"] = "cry", ["sobs"] = "sob", ["frowns"] = "frown",
                    ["rages"] = "rage", ["facepalms"] = "facepalm",
                    -- Humor
                    ["laughs"] = "laugh", ["giggles"] = "giggle", ["chuckles"] = "chuckle",
                    ["snickers"] = "snicker", ["cackles"] = "cackle", ["guffaws"] = "guffaw",
                    -- Actions
                    ["dances"] = "dance", ["flexes"] = "flex", ["points"] = "point",
                    ["beckons"] = "beckon", ["kneels"] = "kneel", ["begs"] = "beg",
                    ["grovels"] = "grovel", ["apologizes"] = "apologize", ["bonks"] = "bonk",
                    ["pokes"] = "poke", ["slaps"] = "slap", ["tickles"] = "tickle",
                    ["pounces"] = "pounce", ["charges"] = "charge",
                    -- Taunts
                    ["taunts"] = "taunt", ["mocks"] = "mock", ["spits"] = "spit",
                    ["insults"] = "insult", ["threatens"] = "threaten", ["gloats"] = "gloat",
                    -- States
                    ["yawns"] = "yawn", ["sleeps"] = "sleep", ["cowers"] = "cower",
                    ["blushes"] = "blush", ["drools"] = "drool", ["gasps"] = "gasp",
                    -- Sounds
                    ["roars"] = "roar", ["growls"] = "growl", ["barks"] = "bark",
                    ["moos"] = "moo", ["meows"] = "meow", ["purrs"] = "purr",
                    ["whistles"] = "whistle", ["coughs"] = "cough", ["burps"] = "burp",
                    ["farts"] = "fart", ["sniffles"] = "sniffle", ["sniffs"] = "sniff",
                    ["snorts"] = "snort", ["cracks"] = "crack",
                    -- Combat
                    ["flees"] = "flee", ["retreats"] = "retreat", ["follows"] = "follow",
                    ["waits"] = "wait", ["surrenders"] = "surrender",
                    -- Misc
                    ["drinks"] = "drink", ["eats"] = "eat", ["sits"] = "sit",
                    ["stands"] = "stand", ["lays"] = "lay", ["bounces"] = "bounce",
                    ["fidgets"] = "fidget", ["taps"] = "tap", ["peers"] = "peer",
                    ["stares"] = "stare", ["glares"] = "glare", ["eyes"] = "eye",
                    ["prays"] = "pray", ["mourns"] = "mourn",
                }
                local baseEmote = emoteMap[emoteVerb] or emoteVerb
                if TRACKED_EMOTES[baseEmote] then
                    if not db.emoteStats then db.emoteStats = {} end
                    db.emoteStats[baseEmote] = (db.emoteStats[baseEmote] or 0) + 1
                end
            end
        end

    -- ======== LOGOUT (session save) ========
    elseif event == "PLAYER_LOGOUT" then
        PS:SaveSession()
    end
end)

-- Periodic session save (every 30s)
local sessionSaveTimer = 0
tracker:SetScript("OnUpdate", function(self, dt)
    sessionSaveTimer = sessionSaveTimer + dt
    if sessionSaveTimer >= 30 then
        sessionSaveTimer = 0
        PS:SaveSession()
    end
end)
