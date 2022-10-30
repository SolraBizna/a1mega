a1megas_enabled = {
  hardcore=true,
  navi=true,
  port=true,
  shld=true,
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
            if not Game._checkpointed_players[player.name].dead then
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
local PORT_TARGET_OVERLAY = 5

local PORT_AMPLITUDE_ADD = 30
local PORT_AMPLITUDE_THRESHOLD = 61
local PORT_AMPLITUDE_DECAY_PER_TICK = 1

local PORT_DAMAGE_COOLDOWN = 30 * 10
local PORT_RECHARGE_COOLDOWN = 30 * 5

function Triggers.init()
   for player in Players() do
      if not player._port_index or player._port_index >= #Players
      or player._port_index ~= player.index then
         player._port_index = (player.index + 1) % #Players
      end
   end
end

function Triggers.idle()
   if #Players == 1 then return end
   for player in Players() do
      if not player.dead and player.action_flags.microphone_button then
         if player.action_flags.cycle_weapons_backward then
            player.action_flags.cycle_weapons_backward = false
            local start_index = player._port_index
            repeat
               player._port_index = (player._port_index + 1) % #Players
            until (player._port_index ~= player.index
                      and (Game.type == "cooperative play"
                           or player.team == Players[player._port_index].team))
               or player._port_index == start_index
            if player._port_index == start_index then
               player:play_sound("cant toggle switch")
            else
               player:play_sound("computer page")
            end
         end
         if player.action_flags.cycle_weapons_forward then
            player.action_flags.cycle_weapons_forward = false
            local start_index = player._port_index
            repeat
               player._port_index = player._port_index - 1
               if player._port_index < 0 then
                  player._port_index = #Players-1
               end
            until (player._port_index ~= player.index
                      and (Game.type == "cooperative play"
                           or player.team == Players[player._port_index].team))
               or player._port_index == start_index
            if player._port_index == start_index then
               player:play_sound("cant toggle switch")
            else
               player:play_sound("computer page")
            end
         end
         if player._port_index ~= player.index then
            local target = Players[player._port_index]
            player.overlays[5].text = "TP to: "..target.name
            if player._port_cooldown
            or target._port_cooldown or target.dead then
               player.overlays[5].color = "red"
               if player.action_flags.toggle_map then
                  player.action_flags.toggle_map = false
                  player:play_sound("cant toggle switch")
               end
            else
               player.overlays[5].color = "white"
               if player.action_flags.toggle_map then
                  player.action_flags.toggle_map = false
                  player._port_amplitude = (player._port_amplitude or 0)
                                               + PORT_AMPLITUDE_ADD
                  if player._port_amplitude > PORT_AMPLITUDE_THRESHOLD then
                     player._port_amplitude = 0
                     player._port_cooldown = PORT_RECHARGE_COOLDOWN
                     player:teleport(target.polygon)
                  else
                     player:play_sound("computer login")
                  end
               end
            end
         else
            player.overlays[5].text = "TP not possible"
            player.overlays[5].color = "red"
         end
      else
         player.overlays[5]:clear()
      end
      if player._port_amplitude then
         player._port_amplitude = player._port_amplitude
            - PORT_AMPLITUDE_DECAY_PER_TICK
         if player._port_amplitude <= 0 then
            player._port_amplitude = nil
         end
      end
      if player._port_cooldown then
         player._port_cooldown = player._port_cooldown - 1
         if player._port_cooldown <= 0 then
            player._port_cooldown = nil
         end
      end
   end
end

function Triggers.player_damaged(victim, aggressor_player, aggressor_monster,
                                 damage_type, damage_amount, projectile)
   if damage_amount > 0 then
      if victim._port_cooldown == nil
      or victim._port_cooldown < PORT_DAMAGE_COOLDOWN then
         victim._port_cooldown = PORT_DAMAGE_COOLDOWN
      end
   end
end
]], "@port.lua")()
load([[
local LIFE_SENTINEL = 75
local BLEEDING_OVERLAY = 1
local OXYGEN_OVERLAY = 0
local WARNING_OXYGEN = 1 * 60 * 30
local OXYGEN_MAX = 6 * 60 * 30
local HEALTH_MAX = 75
local HEALTH_REGEN_INCREMENT = 25
local HEALTH_DISPLAY_FACTOR = OXYGEN_MAX / HEALTH_MAX
local SHIELD_LEVEL_ONE = 75
local SHIELD_LEVEL_TWO = 150
local SHIELD_LEVEL_THREE = 225
local LEVEL_ONE_ACQUIRE_TIME = 3 * 30
local LEVEL_TWO_ACQUIRE_TIME = 6 * 30
local LEVEL_THREE_ACQUIRE_TIME = 9 * 30
local SHIELD_DISPLAY_FACTOR = 450 / SHIELD_LEVEL_THREE
local HEALTH_REGEN_INTERVAL = 200
local BLEED_INTERVAL = 30
local DAMAGE_RECOVERY_INTERVAL = 300

-- 10 seconds of lung capacity
local LUNG_CAPACITY = 10 * 30
-- Lungs fill 3 times faster than they empty
local LUNG_FILL_RATE = 3
-- pressure calculations based on an O2 consumption rate of 0.7g/minute and
-- a tank capacity of 2L
local MAX_PRESSURE_KPA = 175
local MAX_DISPLAY_PRESSURE = 150
-- a heuristic multiplicative factor affecting the rate at which the O2 gauge
-- actually detects changes
local GAUGE_RATE = 1/150

local NULL_DAMAGE_TYPES = {}
for _,v in ipairs{"oxygen drain", "suffocation", "absorbed", "teleporter"} do
   NULL_DAMAGE_TYPES[assert(DamageTypes[v])] = true
end
local BLOODY_DAMAGE_TYPES = {}
for _,v in ipairs{"projectile", "claws", "yeti claws", "shotgun"} do
   BLOODY_DAMAGE_TYPES[assert(DamageTypes[v])] = true
end
local MELEE_DAMAGE_TYPES = {}
for _,v in ipairs{"crushing", "fists", "claws", "yeti claws", "hulk slap"} do
   MELEE_DAMAGE_TYPES[assert(DamageTypes[v])] = true
end
local ELECTRIC_DAMAGE_TYPES = {}
for _,v in ipairs{"compiler", "staff", "fusion", "defender"} do
   ELECTRIC_DAMAGE_TYPES[assert(DamageTypes[v])] = true
end
local BLACKLISTED_ITEMS = {}
for _,v in ipairs{} do
   BLACKLISTED_ITEMS[assert(ItemTypes[v])] = true
end

local function stop_player_from_refuelling(player)
   player._restore_z = player.z
   player:position(player.x, player.y, player.z + 1, player.polygon)
end

local function player_revived(player)
   if Level.rebellion then
      player._health = HEALTH_REGEN_INCREMENT
      player._max_shield = 0
      player._shield = 0
   else
      player._health = HEALTH_MAX
      player._max_shield = SHIELD_LEVEL_ONE
      player._shield = SHIELD_LEVEL_ONE
   end
   player._damage_timeout = 0
   player._oxygen = OXYGEN_MAX
   player._oxygen_tank = OXYGEN_MAX - LUNG_CAPACITY
   player._oxygen_gauge = nil
   player.oxygen = OXYGEN_MAX -- hack
   player._bleeding = false
   player._health_regen_timeout = HEALTH_REGEN_INTERVAL
end
Triggers.player_revived = player_revived

function Triggers.init(restoring_game)
   for item in pairs(BLACKLISTED_ITEMS) do
      item.initial_count = 0
      item.minimum_count = 0
      item.maximum_count = 0
      item.total_available = 0
      item.random_location = false
   end
   for item in Items() do
      if BLACKLISTED_ITEMS[item.type] then
         item:delete()
      end
   end
   if not restoring_game and Level.rebellion then
      for player in Players() do
         player_revived(player)
      end
   end
end

function Triggers.idle()
   for player in Players() do
      if player._health == nil then
         Triggers.player_revived(player)
      end
      if player._health >= 0 and not player.dead and player._virtual then
         player._virtual = false
         if player._upgrading_ticks then
            player._upgrading_ticks = player._upgrading_ticks - 1
            if player._upgrading_ticks == 0 then
               player:print("Installation complete!")
               player:fade_screen("bonus")
               player._max_shield = player._upgrading_target
               player._shield = player._max_shield
               player._upgrading_ticks = nil
               player._upgrading_target = nil
               player.monster:play_sound("got powerup")
               stop_player_from_refuelling(player)
            end
         end
         player.oxygen = player._oxygen
         if player._shield == 0 then
            player.life = LIFE_SENTINEL
         elseif player._max_shield >= SHIELD_LEVEL_THREE then
            player.life = 450
         elseif player._max_shield >= SHIELD_LEVEL_TWO then
            player.life = 300
         elseif player._max_shield >= SHIELD_LEVEL_ONE then
            player.life = 150
         else
            player.life = LIFE_SENTINEL
         end
      end
   end
end

local function handle_shield_recharge(player)
   if player._damage_timeout == 0 then
      if player._shield > 0 and player._shield < player._max_shield then
         player._shield = player._shield + 1
         player:play_sound("electric hum", player._shield/25+2)
      end
   else
      player._damage_timeout = player._damage_timeout - 1
      player._health_regen_timeout = HEALTH_REGEN_INTERVAL
   end
   if player._upgrading_ticks and player._upgrading_target
   and math.floor(math.sqrt(player._upgrading_ticks)) % 2 == 1 then
      player.life = player._upgrading_target * SHIELD_DISPLAY_FACTOR
   else
      player.life = player._shield * SHIELD_DISPLAY_FACTOR
   end
end

local function handle_health(player)
   if player._recharging_health then
      player._bleeding = false
      if player._health < HEALTH_MAX then
         player._health = player._health + 1
      else
         stop_player_from_refuelling(player)
      end
   elseif player._bleeding then
      if player._bleed_timeout == nil then
         player._bleed_timeout = BLEED_INTERVAL
      elseif player._bleed_timeout == 0 then
         player._bleed_timeout = BLEED_INTERVAL
         if player._health > 0 then
            player._health = player._health
               - math.ceil(player._health / HEALTH_REGEN_INCREMENT)
         end
      else
         player._bleed_timeout = player._bleed_timeout - 1
      end
   elseif player._health_regen_timeout == 0 then
      player._health_regen_timeout = HEALTH_REGEN_INTERVAL
      player._health = player._health + math.ceil((HEALTH_MAX - player._health) / HEALTH_REGEN_INCREMENT)
   else
      player._health_regen_timeout = player._health_regen_timeout - 1
   end
   if not player._bleeding then player._bleed_timeout = nil end
   if player._bleeding then
      player.overlays[BLEEDING_OVERLAY].text = "BLEEDING!"
      if Game.ticks % 10 < 5 then
         player.overlays[BLEEDING_OVERLAY].color = "white"
      else
         player.overlays[BLEEDING_OVERLAY].color = "red"
      end
   else
      player.overlays[BLEEDING_OVERLAY]:clear()
   end
end

local function handle_o2(player)
   local delta_o2 = player.oxygen - player._oxygen
   player._oxygen = player.oxygen
   if player._oxygen_tank == nil then
      player._oxygen_tank = math.max(player._oxygen - LUNG_CAPACITY, 0)
   elseif delta_o2 < 0 then
      -- using O2
      if player._oxygen_tank > player._oxygen then
         player._oxygen_tank = player._oxygen
      end
   else
      -- breathing
      if delta_o2 == 0 and player._oxygen < player._oxygen_tank + LUNG_CAPACITY then
         player._oxygen = math.min(player._oxygen + LUNG_FILL_RATE,
                                   player._oxygen_tank + LUNG_CAPACITY,
                                   OXYGEN_MAX)
      elseif player._oxygen_tank < player._oxygen - LUNG_CAPACITY then
         player._oxygen_tank = player._oxygen - LUNG_CAPACITY
      end
   end
   player.oxygen = player._health * HEALTH_DISPLAY_FACTOR
   if player._oxygen_gauge == nil then
      player._oxygen_gauge = MAX_PRESSURE_KPA
   else
      local kPa = math.floor(player._oxygen_tank * 175 / OXYGEN_MAX)
      local adjusted_gauge_rate
      -- make the gauge more precise at very low pressure, so the player isn't
      -- surprised by their own suffocation
      if kPa < 25 then adjusted_gauge_rate = 1-(1-GAUGE_RATE)*kPa/25
      else adjusted_gauge_rate = GAUGE_RATE
      end
      player._oxygen_gauge = player._oxygen_gauge
         + (kPa - player._oxygen_gauge) * adjusted_gauge_rate
   end
   if player._oxygen_gauge >= MAX_DISPLAY_PRESSURE and delta_o2 >= 0
   and player._oxygen >= player._oxygen_tank + LUNG_CAPACITY then
      player.overlays[OXYGEN_OVERLAY]:clear()
   else
      if player._oxygen_gauge >= MAX_DISPLAY_PRESSURE then
         player.overlays[OXYGEN_OVERLAY].text = "O2>150kPa XX%"
      else
         local percent = math.floor(player._oxygen_gauge * 100 / MAX_DISPLAY_PRESSURE)
         player.overlays[OXYGEN_OVERLAY].text
            = ("O2\xC5%03ikPa %02i%%"):format(player._oxygen_gauge, percent)
      end
      if player._oxygen_tank < WARNING_OXYGEN then
         if player._oxygen <= player._oxygen_tank then
            if Game.ticks % 10 < 5 then
               player.overlays[OXYGEN_OVERLAY].color = "red"
            else
               player.overlays[OXYGEN_OVERLAY].color = "white"
            end
         else
            player.overlays[OXYGEN_OVERLAY].color = "red"
         end
      elseif player._oxygen <= player._oxygen_tank then
         player.overlays[OXYGEN_OVERLAY].color = "cyan"
      else
         player.overlays[OXYGEN_OVERLAY].color = "blue"
      end
   end
end

function Triggers.postidle()
   for player in Players() do
      if player._restore_z then
         player:position(player.x, player.y, player._restore_z, player.polygon)
         player._restore_z = nil
      end
      if player._health >= 0 and not player.dead and not player._virtual then
         player._virtual = true
         handle_shield_recharge(player)
         handle_health(player)
         handle_o2(player)
      else
         player.oxygen = 0
         player.life = 0
         player.overlays[BLEEDING_OVERLAY]:clear()
         player.overlays[OXYGEN_OVERLAY]:clear()
      end
   end
end

function Triggers.start_refuel(class, player)
   -- oxygen rechargers behave as expected
   if class == "single shield recharger" then
      if player._max_shield < SHIELD_LEVEL_ONE then
         player._upgrading_ticks = LEVEL_ONE_ACQUIRE_TIME
         player._upgrading_target = math.max(player._upgrading_target or 0,
                                              SHIELD_LEVEL_ONE)
         player:print("Installing level 1 shield...")
      else
         stop_player_from_refuelling(player)
      end
      player._bleeding = false
      if player._max_shield ~= 0 then
         player._damage_timeout = 0
         if player._shield == 0 then
            player._shield = 1
            player:print("Shield re-activated.")
         end
      end
   elseif class == "double shield recharger" then
      if player._max_shield < SHIELD_LEVEL_TWO then
         player._upgrading_ticks = LEVEL_TWO_ACQUIRE_TIME
         player._upgrading_target = math.max(player._upgrading_target or 0,
                                              SHIELD_LEVEL_TWO)
         player:print("Installing level 2 shield...")
      else
         stop_player_from_refuelling(player)
      end
      player._bleeding = false
      if player._max_shield ~= 0 then
         player._damage_timeout = 0
         if player._shield == 0 then
            player._shield = 1
            player:print("Shield re-activated.")
         end
      end
   elseif class == "triple shield recharger" then
      if player._max_shield < SHIELD_LEVEL_THREE then
         player._upgrading_ticks = LEVEL_THREE_ACQUIRE_TIME
         player._upgrading_target = math.max(player._upgrading_target or 0,
                                              SHIELD_LEVEL_THREE)
         player:print("Installing level 3 shield...")
      else
         stop_player_from_refuelling(player)
      end
      player._bleeding = false
      if player._max_shield ~= 0 then
         player._damage_timeout = 0
         if player._shield == 0 then
            player._shield = 1
            player:print("Shield re-activated.")
         end
      end
   end
end

function Triggers.end_refuel(class, player)
   if class == "single shield recharger"
   and player._upgrading_target == SHIELD_LEVEL_ONE then
      player._upgrading_ticks = nil
      player._upgrading_target = nil
      player:print("Installation aborted.")
   elseif class == "double shield recharger"
   and player._upgrading_target == SHIELD_LEVEL_TWO then
      player._upgrading_ticks = nil
      player._upgrading_target = nil
      player:print("Installation aborted.")
   elseif class == "triple shield recharger"
   and player._upgrading_target == SHIELD_LEVEL_THREE then
      player._upgrading_ticks = nil
      player._upgrading_target = nil
      player:print("Installation aborted.")
   end
end

function Triggers.pattern_buffer(side, player)
   player._bleeding = false
end

function Triggers.player_damaged(victim, aggressor_player, aggressor_monster,
                                 damage_type, damage_amount, projectile)
   if NULL_DAMAGE_TYPES[damage_type] then return end
   victim._damage_timeout = DAMAGE_RECOVERY_INTERVAL
   if MELEE_DAMAGE_TYPES[damage_type] then
      -- melee attacks partially ignore shields
      if victim._shield > SHIELD_LEVEL_ONE then
         if damage_amount >= victim._shield - SHIELD_LEVEL_ONE then
            damage_amount = damage_amount - (victim._shield - SHIELD_LEVEL_ONE)
            victim._shield = SHIELD_LEVEL_ONE
         else
            victim.monster:play_sound("absorbed")
            victim._shield = victim._shield - damage_amount
            damage_amount = 0
         end
      end
      local half_damage = math.floor(damage_amount / 2)
      damage_amount = damage_amount - half_damage
      if half_damage > victim._shield then
         damage_amount = damage_amount + half_damage - victim._shield
         victim._shield = 0
      else
         victim._shield = victim._shield - half_damage
      end
   elseif ELECTRIC_DAMAGE_TYPES[damage_type] then
      -- even a non-damaging electric attack can eat shields
      if victim._max_shield >= SHIELD_LEVEL_THREE
      and victim._shield <= SHIELD_LEVEL_TWO then
         victim.monster:play_sound("destroy control panel")
         victim._max_shield = SHIELD_LEVEL_TWO
         victim:fade_screen("negative")
         victim:print("Level three shield lost!")
      elseif victim._max_shield >= SHIELD_LEVEL_TWO
      and victim._shield <= SHIELD_LEVEL_ONE then
         victim.monster:play_sound("destroy control panel")
         victim._max_shield = SHIELD_LEVEL_ONE
         victim:fade_screen("negative")
         victim:print("Level two shield lost!")
      elseif victim._max_shield >= SHIELD_LEVEL_ONE
      and victim._shield <= 0 then
         victim.monster:play_sound("cyborg death")
         victim:fade_screen("big negative")
         victim._max_shield = 0
         victim:print("Level one shield lost!")
      end
      if damage_amount > math.ceil(victim._shield / 2) then
         damage_amount = damage_amount - math.ceil(victim._shield / 2)
         victim._shield = 0
      else
         victim.monster:play_sound("absorbed")
         victim._shield = victim._shield - damage_amount * 2
         damage_amount = 0
      end
   else
      if damage_amount > victim._shield then
         damage_amount = damage_amount - victim._shield
         victim._shield = 0
      else
         victim.monster:play_sound("absorbed")
         victim._shield = victim._shield - damage_amount
         damage_amount = 0
      end
   end
   if damage_amount > 0 then
      if damage_amount > victim._health then
         victim._health = -1
      else
         victim._health = victim._health - damage_amount
         victim.monster:play_sound("bob hit")
         if BLOODY_DAMAGE_TYPES[damage_type] then
            victim._bleeding = true
         end
      end
   end
   if victim._health < 0 then
      victim.life = -1
   end
end

function Triggers.got_item(item, player)
   if item == "single health" then
      if player._max_shield < SHIELD_LEVEL_ONE then
         player._max_shield = SHIELD_LEVEL_ONE
         player:print("Level 1 shield installed.")
      end
      if player._shield < SHIELD_LEVEL_ONE then
         player._shield = SHIELD_LEVEL_ONE
      end
   elseif item == "double health" then
      if player._max_shield < SHIELD_LEVEL_TWO then
         player._max_shield = SHIELD_LEVEL_TWO
         player:print("Level 2 shield installed.")
      end
      if player._shield < SHIELD_LEVEL_TWO then
         player._shield = SHIELD_LEVEL_TWO
      end
   elseif item == "triple health" then
      if player._max_shield < SHIELD_LEVEL_THREE then
         player._max_shield = SHIELD_LEVEL_THREE
         player:print("Level 3 shield installed.")
      end
      if player._shield < SHIELD_LEVEL_THREE then
         player._shield = SHIELD_LEVEL_THREE
      end
   end
end
]], "@shld.lua")()
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
