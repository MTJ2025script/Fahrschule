# Crash/Respawn Freeze Fix - Testing Guide

## Problem Fixed
**German:** "bei crash wärend praxis prüfung gibt es fehler beim zurück spawnen ab da freeze"  
**English:** When crash during practical exam there are errors when respawning, then freeze

## Root Cause
The watchdog in `client/main.lua` detected crashes/deaths and triggered `:client:AbortPractice` event, but there was no handler for this event in `client/practice.lua`. This caused:
- Practice loop to continue running
- Vehicle/NPC entities not cleaned up
- Player frozen during respawn
- UI timers continuing to run

## Changes Made

### 1. Added `:client:AbortPractice` Event Handler (client/practice.lua)
- Properly handles watchdog-triggered aborts
- Cleans up ideal line, UI timers, guidance
- Deletes vehicle/NPC if practice already ended
- Calls `FinishPractice(false)` to properly end practice
- Adds error with proper reason to error list

### 2. Improved `respawnToAbortPoint()` Function
- Updates ped reference after potential respawn/death
- Ensures player exits vehicle before teleport
- Always unfreezes player even if ped entity changed
- Checks entity existence before unfreezing

## How to Test

### Test Case 1: Player Death During Practice

1. **Start a practice exam** (any category)
2. **Get into the practice vehicle**
3. **Kill the player** (use admin command or weapon)
   ```
   /kill
   ```
4. **Expected Result:**
   - ✅ Practice should abort immediately
   - ✅ Error message: "Prüfung abgebrochen: Crash / Notausstieg"
   - ✅ Player respawns at booking point
   - ✅ Player is NOT frozen
   - ✅ Vehicle and NPC are deleted
   - ✅ UI timers stop
   - ✅ Practice result screen shows (failed)

### Test Case 2: Heavy Collision During Practice

1. **Start a practice exam** (car/truck category)
2. **Get into the practice vehicle**
3. **Drive at high speed into a wall** (>50 km/h)
4. **Crash hard enough** to trigger collision detection
5. **Expected Result:**
   - ✅ Practice should abort
   - ✅ Error message: "Prüfung abgebrochen: Kollision / Rammen"
   - ✅ Player respawns at booking point
   - ✅ Player is NOT frozen
   - ✅ Vehicle and NPC are deleted
   - ✅ Practice result screen shows (failed)

### Test Case 3: Vehicle Exit During Practice (Non-Bike)

1. **Start a practice exam** (car/truck/plane/heli)
2. **Get into the practice vehicle**
3. **Exit the vehicle** (press F)
4. **Expected Result:**
   - ✅ Practice should abort
   - ✅ Error message: "Prüfung abgebrochen: left_vehicle"
   - ✅ Player respawns at booking point
   - ✅ Player is NOT frozen
   - ✅ Vehicle and NPC are deleted
   - ✅ Practice result screen shows (failed)

### Test Case 4: Bike Ragdoll

1. **Start a bike practice exam**
2. **Get on the practice bike**
3. **Crash to trigger ragdoll** (fall off bike)
4. **Expected Result:**
   - ✅ Practice should abort
   - ✅ Error message: "Prüfung abgebrochen: bike_ragdoll"
   - ✅ Player respawns at booking point
   - ✅ Player is NOT frozen
   - ✅ Bike and NPC are deleted
   - ✅ Practice result screen shows (failed)

### Test Case 5: Normal Practice Completion (Regression Test)

1. **Start a practice exam**
2. **Complete the route normally** without crashes
3. **Expected Result:**
   - ✅ Practice completes normally
   - ✅ Result screen shows (passed or failed based on errors)
   - ✅ No respawn issues
   - ✅ Everything works as before

## Debug Commands

To help with testing, you can use these commands:

```lua
-- Check practice status
/mtj_practice_debug

-- Manually abort practice (should work now)
TriggerEvent('mtj_fahrschule:client:AbortPractice', 'test_abort')

-- Check if player is frozen
-- In F8 console:
IsFrozen = IsPedFrozen or FreezeEntityPosition
IsFrozen(PlayerPedId())
```

## Config Requirements

Ensure `Config.Practice.AbortRespawn` is enabled in `config/config.lua`:

```lua
Config.Practice = {
  AbortRespawn = {
    enabled = true,  -- Must be true
    position = vector3(x, y, z),  -- Or leave nil to use booking point
    fade = true,
    freezeSeconds = 0.0  -- Set to 0 to avoid freeze during testing
  }
}
```

## Known Behavior

- **Death during practice:** Player will respawn and teleport to booking point
- **Collision detection:** Has 2-second cooldown between detections
- **Vehicle health drops:** Triggers at >10 points drop at >10 km/h
- **Off-route:** Triggers after 8 seconds being >120m from checkpoint

## Success Criteria

✅ **Fix is successful when:**
1. Player can die/crash during practice without freezing
2. Player respawns correctly at booking point
3. All practice entities are cleaned up (vehicle, NPC, blips)
4. Practice result screen displays properly
5. Player can start a new practice immediately after
6. No console errors in F8 or server log

## Rollback Plan

If issues occur, revert with:
```bash
git revert 014ad3f
git push
```

Then restart the resource:
```
restart mtj_fahrschule
```

## Additional Notes

- The fix ensures `FreezeEntityPosition(ped, false)` is always called
- The ped reference is updated multiple times to handle respawns
- Vehicle exit is forced before teleport to prevent stuck-in-vehicle issues
- All cleanup functions are called in the correct order
