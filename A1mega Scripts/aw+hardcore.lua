a1megas_enabled = {
  aw=true,
  hardcore=true,
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
local COUNTDOWN_OVERLAY = 3

local RESTART_COUNTDOWN = 15 * 30

a1mega = a1mega or {}
a1mega.SHARED_ITEMS = a1mega.SHARED_ITEMS or {}

local function get_level_id()
   return Level.map_checksum .. "_" .. Level.index
end

function a1mega.forcing_restart()
   return Game._forcing_restart == get_level_id()
end

local keys_to_backup = {}
if a1megas_enabled.aw then
   for weapon in WeaponTypes() do
      keys_to_backup["_weapon"..weapon.index.."_firemode"] = true
   end
   for _,v in ipairs{"_auto_spread","_burst_decay"} do keys_to_backup[v] = true end
end
if a1megas_enabled.shld then
   for _,v in ipairs{"_health","_max_shield","_shield","_damage_timeout","_health_regen_timeout","_recharging_health","_bleeding","_bleed_timeout","_oxygen_tank","_oxygen_gauge","_virtual"} do keys_to_backup[v] = true end
else
   for _,v in ipairs{"life","oxygen"} do keys_to_backup[v] = true end
end
for _,v in ipairs{"extravision_duration","infravision_duration","invincibility_duration","invisibility_duration"} do keys_to_backup[v] = true end

local function restore_player(player)
   local src = assert(Game._checkpointed_players[player.name])
   Game._marked_for_delayed_restore = nil
   for key in pairs(keys_to_backup) do
      player[key] = src[key]
   end
   local old_got_item = Triggers.got_item
   Triggers.got_item = nil
   for type in ItemTypes() do
      player.items["knife"] = 2
      if not a1mega.SHARED_ITEMS[type.mnemonic] and type.mnemonic ~= "knife" then
         -- this will refill weapons
         player.items[type] = 0
         player.items[type] = src.items[type.index]
      end
   end
   Triggers.got_item = old_got_item
end

local go

function Triggers.init(restoring_game)
   go = Game.type.index == 0 or Game.type.index == 1
   if not go then return end
   if not restoring_game then
      for player in Players() do
         if player.dead then player._marked_for_revival = true end
      end
   end
   if restoring_game then
      -- do nothing
   elseif Game._checkpointed_players and a1mega.forcing_restart() then
      for player in Players() do
         local src = Game._checkpointed_players[player.name]
         if player.dead then
            player._marked_for_revival = true
            player._marked_for_delayed_restore = true
            goto continue
         end
         if not src then goto continue end
         restore_player(player)
         ::continue::
      end
      Game._forcing_restart = nil
   else
      Game._checkpointed_players = {}
      for player in Players() do
         if player.dead then
            player._marked_for_revival = true
         else
            local tab = {}
            for key in pairs(keys_to_backup) do
               tab[key] = player[key]
            end
            tab.dead = player.dead
            tab.items = {}
            for itemtype in ItemTypes() do
               tab.items[itemtype.index] = player.items[itemtype]
            end
            Game._checkpointed_players[player.name] = tab
         end
      end
      if a1megas_enabled.fair then
         Game._checkpointed_global_inventory = a1mega.shallow_clone(Game._global_inventory)
      end
      Game._checkpointed_level = get_level_id() -- TODO: unused?
   end
end

local did_disappoint = false
function Triggers.idle()
   if not go then return end
   local any_left_alive = false
   for player in Players() do
      if player._marked_for_revival then
         -- they are supposed to be alive, it's not their fault if their
         -- teammates all died before they could finish respawning
         any_left_alive = true
         if player.totally_dead then
            player:revive()
            player._marked_for_revival = false
            if player._marked_for_delayed_restore then
               restore_player(player)
            end
         end
      elseif player.dead then
         -- ded
         player.action_flags.action_trigger = false
      else
         -- aleve
         any_left_alive = true
      end
   end
   if any_left_alive then
      for player in Players() do
         player.overlays[COUNTDOWN_OVERLAY]:clear()
      end
   else
      if RESTART_COUNTDOWN == nil then
         for player in Players() do
            player:fade_screen("long bright")
         end
         -- nothing to do
      elseif RESTART_COUNTDOWN > 0 then
         RESTART_COUNTDOWN = RESTART_COUNTDOWN - 1
         for player in Players() do
            player.overlays[COUNTDOWN_OVERLAY].text = ("Restart in %is..."):format(math.ceil(RESTART_COUNTDOWN/30))
            player.overlays[COUNTDOWN_OVERLAY].color = "cyan"
            if not did_disappoint then
               player:play_sound("you are it", 0.25)
            end
         end
         did_disappoint = true
      else
         for player in Players() do
            player.overlays[COUNTDOWN_OVERLAY].text = "Waiting to restart..."
            if not player.totally_dead then
               return
            end
         end
         for player in Players() do
            player:fade_screen("long bright")
            player.overlays[COUNTDOWN_OVERLAY].text = "Restarting..."
            if not Game._checkpointed_players or not Game._checkpointed_players[player.name] or not Game._checkpointed_players[player.name].dead then
               player:revive()
            end
         end
         RESTART_COUNTDOWN = nil
         Game._forcing_restart = get_level_id()
         Players[0]:teleport_to_level(Level.index)
      end
   end
end
]], "@hardcore.lua")()
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
