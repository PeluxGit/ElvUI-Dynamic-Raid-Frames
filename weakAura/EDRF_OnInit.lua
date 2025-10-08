-- ElvUI Dynamic Raid Frames (EDRF) - On Init
-- Config, helpers, minimal enforcement, and initial scheduling.
-- No slash command; the aura updates automatically on roster/zone/combat events.

local aura_env = aura_env

------------------------------------------------------------
-- EDRF — USER CONFIG
------------------------------------------------------------
aura_env.EDRF = {
    -- Headers we manage (party + raid1–raid3 only)
    HEADERS = { "party", "raid1", "raid2", "raid3" },

    -- Bucket breakpoints (inclusive upper bounds):
    -- size <= partyMax -> party
    -- size <= raid1Max -> raid1
    -- size <= raid2Max -> raid2
    -- else -> raid3
    BUCKETS = { partyMax = 5, raid1Max = 15, raid2Max = 25 },

    -- Map bucket -> which header to show (change if you use different headers)
    MAP = { party = "party", raid1 = "raid1", raid2 = "raid2", raid3 = "raid3" },

    -- Minimal enforcement (applied to the *active raid header* only, OOC):
    ENFORCE = {
        raidWideSorting    = true,              -- keep a single pool
        groupFilter        = "1,2,3,4,5,6,7,8", -- include all groups
        keepGroupsTogether = false,             -- allow spill across columns
        numGroups          = 8,                 -- ensure capacity (40) on raid headers
        numGroupsParty     = nil,               -- set to 1 if you also want party forced
    },

    -- Timing knobs
    DELAYS = {
        debounce = 0.20, -- collapse bursts of roster events
        enforce  = 0.05, -- small wait before enforcing after rebuild
        initial  = 0.00, -- initial apply delay
    },

    -- Optional: normalize ALL managed headers once at login (DB writes only if needed)
    ENFORCE_ALL_ON_LOGIN = true,
}

------------------------------------------------------------
-- ElvUI deps (no-op if missing so WA doesn't error)
------------------------------------------------------------
local E = unpack(ElvUI)
if not E then
    aura_env.ApplyAll = function() end
    return
end
local UF = E:GetModule("UnitFrames")
if not UF then
    aura_env.ApplyAll = function() end
    return
end

------------------------------------------------------------
-- Helpers
------------------------------------------------------------
local function UnitsDB()
    return E and E.db and E.db.unitframe and E.db.unitframe.units
end

aura_env.HeaderFromKey = function(key)
    if key == "party" then return _G["ElvUF_Party"] end
    if key == "raid1" then return _G["ElvUF_Raid1"] end
    if key == "raid2" then return _G["ElvUF_Raid2"] end
    if key == "raid3" then return _G["ElvUF_Raid3"] end
    return nil
end

aura_env.GetBucket = function(size)
    local b = aura_env.EDRF.BUCKETS
    if size <= (b.partyMax or 5) then
        return "party"
    elseif size <= (b.raid1Max or 15) then
        return "raid1"
    elseif size <= (b.raid2Max or 25) then
        return "raid2"
    else
        return "raid3"
    end
end

local function SetHeaderVisibility(units, showKey, keys)
    local changed = false
    for _, key in ipairs(keys) do
        local conf = units[key]
        if conf then
            local want = (key == showKey) and "show" or "hide"
            if conf.visibility ~= want then
                conf.visibility = want
                changed = true
            end
        end
    end
    return changed
end

------------------------------------------------------------
-- Minimal enforcement: raidWideSorting, groupFilter, keepGroupsTogether, numGroups
------------------------------------------------------------
aura_env._enforcing = false
aura_env.EnforceMinimal = function(headerKey)
    if not headerKey then return end
    if InCombatLockdown() or aura_env._enforcing then return end

    local units = UnitsDB()
    local cfg   = units and units[headerKey]
    if not cfg then return end

    local ENF = aura_env.EDRF.ENFORCE
    local changed = false
    local function setDB(k, v)
        if cfg[k] ~= v then
            cfg[k] = v
            changed = true
        end
    end

    if headerKey ~= "party" then
        -- Raid headers: enforce all minimal knobs
        setDB("raidWideSorting", ENF.raidWideSorting and true or false)
        setDB("groupFilter", ENF.groupFilter or "1,2,3,4,5,6,7,8")
        setDB("keepGroupsTogether", ENF.keepGroupsTogether and true or false)
        if ENF.numGroups then setDB("numGroups", ENF.numGroups) end
    else
        -- Party (optional)
        if ENF.numGroupsParty then setDB("numGroups", ENF.numGroupsParty) end
    end

    if changed then
        aura_env._enforcing = true
        UF:CreateAndUpdateHeaderGroup(headerKey) -- single rebuild when needed
        aura_env._enforcing = false
    end
end

-- (Optional) Normalize all managed headers once at login
aura_env._staticEnforced = false
aura_env.EnforceAllHeadersOnce = function()
    if aura_env._staticEnforced or InCombatLockdown() or not aura_env.EDRF.ENFORCE_ALL_ON_LOGIN then return end
    local units = UnitsDB(); if not units then return end
    local ENF = aura_env.EDRF.ENFORCE
    local changedKeys = {}

    for _, key in ipairs(aura_env.EDRF.HEADERS) do
        local cfg = units[key]
        if cfg then
            local ch = false
            if key ~= "party" then
                if cfg.raidWideSorting ~= (ENF.raidWideSorting and true or false) then
                    cfg.raidWideSorting = ENF.raidWideSorting; ch = true
                end
                if cfg.groupFilter ~= (ENF.groupFilter or "1,2,3,4,5,6,7,8") then
                    cfg.groupFilter = ENF.groupFilter or "1,2,3,4,5,6,7,8"; ch = true
                end
                if cfg.keepGroupsTogether ~= (ENF.keepGroupsTogether and true or false) then
                    cfg.keepGroupsTogether = ENF.keepGroupsTogether; ch = true
                end
                if ENF.numGroups and cfg.numGroups ~= ENF.numGroups then
                    cfg.numGroups = ENF.numGroups; ch = true
                end
            elseif ENF.numGroupsParty and cfg.numGroups ~= ENF.numGroupsParty then
                cfg.numGroups = ENF.numGroupsParty; ch = true
            end
            if ch then table.insert(changedKeys, key) end
        end
    end

    for _, key in ipairs(changedKeys) do
        UF:CreateAndUpdateHeaderGroup(key)
    end
    aura_env._staticEnforced = true
end

------------------------------------------------------------
-- Main apply: decide bucket, flip vis, enforce minimal knobs (OOC)
------------------------------------------------------------
aura_env.ApplyAll = function()
    if InCombatLockdown() then
        aura_env._pending = true
        return
    end

    local units = UnitsDB(); if not units then return end

    local size    = IsInRaid() and GetNumGroupMembers()
        or (IsInGroup() and (GetNumSubgroupMembers() + 1))
        or 1

    local bucket  = aura_env.GetBucket(size)
    local showKey = aura_env.EDRF.MAP[bucket] or bucket

    -- Flip visibility in DB if needed
    if SetHeaderVisibility(units, showKey, aura_env.EDRF.HEADERS) then
        for _, key in ipairs(aura_env.EDRF.HEADERS) do
            UF:CreateAndUpdateHeaderGroup(key)
        end
    end

    -- Enforce minimal knobs on the active header
    aura_env._currentHeaderKey = showKey
    C_Timer.After(aura_env.EDRF.DELAYS.enforce, function()
        if not InCombatLockdown() then
            aura_env.EnforceMinimal(showKey)
        else
            aura_env._needEnforce = showKey
        end
    end)
end

-- Re-enforce after ElvUI rebuilds the active header (guarded)
hooksecurefunc(UF, "CreateAndUpdateHeaderGroup", function(_, unit)
    if unit and unit == aura_env._currentHeaderKey then
        C_Timer.After(aura_env.EDRF.DELAYS.enforce, function()
            if not InCombatLockdown() then
                aura_env.EnforceMinimal(unit)
            else
                aura_env._needEnforce = unit
            end
        end)
    end
end)

------------------------------------------------------------
-- Flags + initial pass (+ optional normalize pass)
------------------------------------------------------------
aura_env._pending, aura_env._needEnforce = false, nil
aura_env._debounceT = aura_env._debounceT or nil

C_Timer.After(aura_env.EDRF.DELAYS.initial, function()
    if not InCombatLockdown() then
        if aura_env.EDRF.ENFORCE_ALL_ON_LOGIN then
            aura_env.EnforceAllHeadersOnce()
        end
        aura_env.ApplyAll()
    else
        aura_env._pending = true
    end
end)
