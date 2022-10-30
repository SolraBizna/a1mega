a1megas_enabled = {
  aw=true,
  navi=true,
}

load([[
Triggers = {}
TriggerHandlers = {}

local function newindex(t,k,v)
   assert(type(v) == "function")
   local th = TriggerHandlers[k]
   if not th then
      th = {}
      TriggerHandlers[k] = th
   end
   th[#th+1] = v
end

setmetatable(Triggers, {__newindex=newindex})

function Triggers.init(restoring_game)
   Game.proper_item_accounting = true
   if restoring_game then
      Game.restore_saved()
   else
      Game.restore_passed()
   end
end
]], "@header.lua")()
load([=[
local AUTOMATIC_PROJECTILES = {}
for _,v in ipairs{"rifle bullet", "smg bullet"} do
   AUTOMATIC_PROJECTILES[assert(ProjectileTypes[v])] = true
end
local WEAPON_MODE_SELECTIONS = {
   [WeaponTypes["assault rifle"]]={single=true,auto=true,burst=4},
   [WeaponTypes["smg"]]={single=false,auto=true,burst=1},
}
local WEAPON_MODE_OVERLAY = 2
local WEAPON_MODE_ORDER = {auto="single",single="burst",burst="auto"}

local AUTO_SPREAD_DECAY = 1/16
local AUTO_SPREAD_INCREASE = 1/4
local AUTO_SPREAD_MAX_EFFECTIVE = 1.5
local AUTO_SPREAD_MAX_ACCUM = 2

local function alerp(a,b,i)
   if math.abs(a-b) > 180 then
      if math.abs((a+360)-b) < math.abs(a-(b+360)) then
         a = a + 360
      else
         b = b + 360
      end
   end
   return a+(b-a)*i
end

local function firemode_for_weapon(weapon)
   return "_weapon"..weapon.index.."_firemode"
end

function Triggers.idle()
   for player in Players() do
      if not player._auto_spread then
         player._auto_spread = 0
      else
         player._auto_spread = player._auto_spread - AUTO_SPREAD_DECAY
         if player._auto_spread < 0 then
            player._auto_spread = 0
         end
      end
      for weapon in pairs(WEAPON_MODE_SELECTIONS) do
         if not player[firemode_for_weapon(weapon)] then
            player[firemode_for_weapon(weapon)] = "auto"
         end
      end
   end
end

function Triggers.idle()
   for player in Players() do
      if not player.dead
      and player.weapons.active
      and player.weapons.current
      and player.weapons.current.index == player.weapons.desired.index
      and WEAPON_MODE_SELECTIONS[player.weapons.current.type] then
         local firemode_key = firemode_for_weapon(player.weapons.current)
         if player.action_flags.microphone_button
         and not player._burst_decay then
            if player.action_flags.left_trigger then
               player.action_flags.left_trigger = false
               if not player._firemodeswitch_held then
                  player._firemodeswitch_held = true
                  player:play_sound("computer page")
                  repeat
                     player[firemode_key] = WEAPON_MODE_ORDER[player[firemode_key]]
                  until WEAPON_MODE_SELECTIONS[player.weapons.current.type][player[firemode_key]]
               end
            else
               player._firemodeswitch_held = nil
            end
         end
         player.overlays[WEAPON_MODE_OVERLAY].color = "green"
         if player[firemode_key] == "auto" then
            player.overlays[WEAPON_MODE_OVERLAY].text = "Mode: Auto"
            player._burst_decay = nil
         elseif player[firemode_key] == "single" then
            player.overlays[WEAPON_MODE_OVERLAY].text = "Mode: Single"
            if player.action_flags.left_trigger then
               if player._burst_decay == nil then
                  player._burst_decay = 0
               elseif player._burst_decay > 0 then
                  player._burst_decay = player._burst_decay - 1
               else
                  player.action_flags.left_trigger = false
               end
            else
               player._burst_decay = nil
            end
         else
            player.overlays[WEAPON_MODE_OVERLAY].text = "Mode: Burst"
            if player.action_flags.left_trigger then
               if player._burst_decay == nil then
                  player._burst_decay = WEAPON_MODE_SELECTIONS[player.weapons.current.type].burst - 1
               elseif player.weapons.current.primary.rounds == 0 then
                  player._burst_decay = 0
                  player.action_flags.left_trigger = false
               elseif player._burst_decay > 0 then
                  player._burst_decay = player._burst_decay - 1
               else
                  player.action_flags.left_trigger = false
               end
            elseif player._burst_decay and player._burst_decay > 0 then
               if player.weapons.current.primary.rounds > 0 then
                  player._burst_decay = player._burst_decay - 1
                  player.action_flags.left_trigger = true
               end
            else
               player._burst_decay = nil
            end
         end
      else
         player.overlays[WEAPON_MODE_OVERLAY]:clear()
      end
      if not player.action_flags.microphone_button then
         player._firemodeswitch_held = nil
      end
   end
end

function Triggers.projectile_created(projectile)
   if projectile.owner == nil then return end
   if not AUTOMATIC_PROJECTILES[projectile.type] then return end
   local owner_player
   for player in Players() do
      if projectile.owner == player.monster then
         owner_player = player
         break
      end
   end
   if not owner_player then return end
   local spread = owner_player._auto_spread
   if spread > AUTO_SPREAD_MAX_EFFECTIVE then
      spread = AUTO_SPREAD_MAX_EFFECTIVE
   end
   owner_player._auto_spread = owner_player._auto_spread + AUTO_SPREAD_INCREASE
   if owner_player._auto_spread > AUTO_SPREAD_MAX_ACCUM then
      owner_player._auto_spread = AUTO_SPREAD_MAX_ACCUM
   end
   projectile.pitch = alerp(owner_player.pitch, projectile.pitch, spread)
   projectile.yaw = alerp(owner_player.yaw, projectile.yaw, spread)
end
]=], "@aw.lua")()
load([[
local completion_status

local fanfare = {
   1.1224846163807,
   1.0033587084638,
   0.68461715641451,
   0.1912042150039,
   0.12434705970034,
   0.78478970534567,
   1.2486941194007,
   1.8331770558077
}
local fanfare_n, fanfare_tick
local FANFARE_TICKRATE = 4

function Triggers.init()
   completion_status = Level.calculate_completion_state()
end

function Triggers.idle()
   if completion_status == "unfinished" then
      completion_status = Level.calculate_completion_state()
      if completion_status == "finished" then
         Players.print("Mission complete!")
         fanfare_tick = 1
         fanfare_n = 1
      elseif completion_status == "failed" then
         Players.print("Mission failed!")
      end
   end
   if fanfare_tick then
      fanfare_tick = fanfare_tick - 1
      if fanfare_tick <= 0 then
         for player in Players() do
            player:play_sound("adjust volume", fanfare[fanfare_n])
         end
         fanfare_n = fanfare_n + 1
         if fanfare[fanfare_n] then
            fanfare_tick = FANFARE_TICKRATE
         else
            fanfare_tick = nil
         end
      end
   end
end
]], "@navi.lua")()
load([[
function Triggers.idle()
   for player in Players() do
      if player.action_flags.microphone_button then
         player.action_flags.microphone_button = false
      end
   end
end

Triggers = TriggerHandlers
for k,v in pairs(Triggers) do
   if #v == 1 then
      Triggers[k] = v[1]
   else
      local t = v
      Triggers[k] = function(...)
         local errors = {}
         for n=1,#t do
            local s,e = pcall(t[n], ...)
            if not s then
               errors[#errors+1] = e
            elseif e == false then
               break
            end
         end
         if #errors > 0 then
            for _,e in ipairs(errors) do
               Players.print(e)
            end
         end
      end
   end
end
]], "@footer.lua")()
