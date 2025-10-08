-- ElvUI Dynamic Raid Frames (EDRF) - Custom Trigger (Event)
-- Events (one per line): 
--   GROUP_ROSTER_UPDATE
--   PLAYER_ENTERING_WORLD
--   PLAYER_REGEN_ENABLED
-- Function signature: function(event)

function(event)
  -- After combat: apply any queued work
  if event == "PLAYER_REGEN_ENABLED" then
    if aura_env._pending then
      aura_env._pending = false
      aura_env.ApplyAll()
    end
    if aura_env._needEnforce then
      local k = aura_env._needEnforce
      aura_env._needEnforce = nil
      aura_env.EnforceMinimal(k)
    end
    return true
  end

  -- Defer while in combat
  if InCombatLockdown() then
    aura_env._pending = true
    return true
  end

  -- Debounce roster storms
  if aura_env._debounceT then aura_env._debounceT:Cancel() end
  aura_env._debounceT = C_Timer.NewTimer(aura_env.EDRF.DELAYS.debounce, aura_env.ApplyAll)

  return true
end
