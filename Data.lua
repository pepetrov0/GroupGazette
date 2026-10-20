local addonName, GG = ...

---------------------------------------------------------------------------
-- Normalisation: lowercase, and put a space between letters and digits so
-- "icc25", "toc5", "aq40" and "2dps" can be matched as separate words.
---------------------------------------------------------------------------
function GG.Normalize(s)
    s = string.lower(s)
    s = string.gsub(s, "(%a)(%d)", "%1 %2")
    s = string.gsub(s, "(%d)(%a)", "%1 %2")
    return s
end

---------------------------------------------------------------------------
-- Dictionary: { label, category, keyword, keyword, ... }
-- Categories: "raid", "dungeon", "other"
-- When a message mentions several instances the one mentioned FIRST wins;
-- on a tie, the entry that appears first in this list wins (so "toc 5"
-- must be listed before plain "toc").
-- Keywords are matched as whole words.
---------------------------------------------------------------------------
GG.Instances = {
    -- ===== WotLK raids =====
    { "ICC",   "raid", "icc", "icecrown citadel", "icecrown", "lich king" },
    { "RS",    "raid", "rs", "ruby sanctum", "halion" },
    { "ToC5",  "dungeon", "toc5", "totc", "trial of the champion" },
    { "ToC",   "raid", "toc", "togc", "totgc", "trial of the crusader", "trial of the grand crusader", "grand crusader" },
    { "Ulduar","raid", "ulduar", "uld" },
    { "Naxx",  "raid", "naxx", "naxxramas" },
    { "EoE",   "raid", "eoe", "malygos", "eye of eternity" },
    { "OS",    "raid", "os", "obsidian sanctum", "sartharion", "sarth" },
    { "VoA",   "raid", "voa", "vault of archavon", "archavon", "koralon", "emalon", "toravon" },
    { "Ony",   "raid", "ony", "onyxia" },

    -- ===== WotLK dungeons =====
    { "Nexus", "dungeon", "nexus" },
    { "UP",    "dungeon", "up", "utgarde pinnacle", "pinnacle" },
    { "UK",    "dungeon", "uk", "utgarde keep", "utgarde" },
    { "AN",    "dungeon", "azjol", "azjol-nerub", "azjol nerub" },
    { "AK",    "dungeon", "ahn'kahet", "ahnkahet", "ahn kahet", "old kingdom", "ak" },
    { "DTK",   "dungeon", "dtk", "drak'tharon", "draktharon", "drak tharon", "drak" },
    { "VH",    "dungeon", "vh", "violet hold", "violethold" },
    { "Gundrak","dungeon", "gundrak" },
    { "HoS",   "dungeon", "hos", "halls of stone" },
    { "HoL",   "dungeon", "hol", "halls of lightning" },
    { "Oculus","dungeon", "oculus", "ocu", "occ" },
    { "CoS",   "dungeon", "cos", "culling", "culling of stratholme" },
    { "FoS",   "dungeon", "fos", "forge of souls" },
    { "PoS",   "dungeon", "pos", "pit of saron" },
    { "HoR",   "dungeon", "hor", "halls of reflection" },

    -- ===== TBC raids =====
    { "Kara",  "raid", "kara", "karazhan" },
    { "Gruul", "raid", "gruul" },
    { "Mag",   "raid", "magtheridon", "maggy" },
    { "SSC",   "raid", "ssc", "serpentshrine" },
    { "TK",    "raid", "tk", "tempest keep" },
    { "Hyjal", "raid", "hyjal", "mount hyjal" },
    { "BT",    "raid", "bt", "black temple" },
    { "ZA",    "raid", "za", "zul'aman", "zulaman" },
    { "SWP",   "raid", "swp", "sunwell" },

    -- ===== Classic raids =====
    { "MC",    "raid", "mc", "molten core" },
    { "BWL",   "raid", "bwl", "blackwing lair" },
    { "AQ40",  "raid", "aq40", "temple of ahn'qiraj" },
    { "AQ20",  "raid", "aq20", "ruins of ahn'qiraj" },
    { "ZG",    "raid", "zg", "zul'gurub", "zulgurub" },

    -- ===== TBC dungeons =====
    { "Ramparts",  "dungeon", "ramparts", "ramps", "hellfire ramparts" },
    { "BF",        "dungeon", "blood furnace" },
    { "SH",        "dungeon", "shattered halls" },
    { "SP",        "dungeon", "slave pens" },
    { "UB",        "dungeon", "underbog" },
    { "SV",        "dungeon", "steamvault", "steam vault" },
    { "MT",        "dungeon", "mana-tombs", "mana tombs", "manatombs" },
    { "AC",        "dungeon", "auchenai crypts" },
    { "Sethekk",   "dungeon", "sethekk", "sethekk halls" },
    { "SLabs",     "dungeon", "shadow labyrinth", "slabs", "shadow lab" },
    { "OHF",       "dungeon", "old hillsbrad", "ohb", "durnholde" },
    { "BM",        "dungeon", "black morass" },
    { "Mech",      "dungeon", "mechanar", "mech" },
    { "Bot",       "dungeon", "botanica" },
    { "Arc",       "dungeon", "arcatraz" },
    { "MgT",       "dungeon", "magisters' terrace", "magisters terrace", "mgt" },

    -- ===== Classic dungeons =====
    { "RFC",    "dungeon", "rfc", "ragefire chasm" },
    { "VC",     "dungeon", "deadmines", "vc" },
    { "WC",     "dungeon", "wailing caverns" },
    { "SFK",    "dungeon", "sfk", "shadowfang keep" },
    { "BFD",    "dungeon", "bfd", "blackfathom deeps" },
    { "Stocks", "dungeon", "stockade", "stockades" },
    { "Gnomer", "dungeon", "gnomer", "gnomeregan" },
    { "RFK",    "dungeon", "rfk", "razorfen kraul" },
    { "RFD",    "dungeon", "rfd", "razorfen downs" },
    { "SM",     "dungeon", "sm", "scarlet monastery" },
    { "Ulda",   "dungeon", "ulda", "uldaman" },
    { "ZF",     "dungeon", "zf", "zul'farrak", "zulfarrak" },
    { "Mara",   "dungeon", "mara", "maraudon" },
    { "ST",     "dungeon", "sunken temple", "temple of atal'hakkar" },
    { "BRD",    "dungeon", "brd", "blackrock depths" },
    { "LBRS",   "dungeon", "lbrs", "lower blackrock spire" },
    { "UBRS",   "dungeon", "ubrs", "upper blackrock spire" },
    { "Scholo", "dungeon", "scholo", "scholomance" },
    { "Strat",  "dungeon", "strat", "stratholme" },
    { "DM",     "dungeon", "dire maul", "dme", "dmn", "dmw" },

    -- ===== Everything else =====
    { "Arena",  "other", "arena", "2v2", "3v3", "5v5", "2s", "3s", "5s" },
    { "BG",     "other", "bg", "bgs", "battleground", "wsg", "warsong", "arathi", "alterac", "eots", "eye of the storm", "ioc", "isle of conquest", "strand of the ancients", "sota" },
    { "WG",     "other", "wintergrasp", "wg" },
    { "Quest",  "other", "quest", "quests", "dailies", "daily" },
    { "Achiev", "other", "achievement", "achiev", "achi", "ach", "meta" },
    { "Farm",   "other", "farm", "farming" },
}
