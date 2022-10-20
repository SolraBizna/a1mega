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
local SHARED_ITEMS = {}
for _,v in ipairs{"pistol","fusion pistol","assault rifle","missile launcher",
                  --[["alien weapon",]]"flamethrower","shotgun","smg",
                  "pistol ammo","fusion pistol ammo","assault rifle ammo",
                  "assault rifle grenades","missile launcher ammo",
                  --[["alien weapon ammo",]]"flamethrower ammo","shotgun ammo",
                  "smg ammo"} do
   local item = assert(ItemTypes[v], v)
   SHARED_ITEMS[item] = #SHARED_ITEMS+1
   SHARED_ITEMS[#SHARED_ITEMS+1] = item
end
local DEFAULT_ITEMS = {
   [ItemTypes["pistol"]] = 1,
   [ItemTypes["pistol ammo"]] = 3,
}

function Triggers.init(restoring_game)
   if not restoring_game and Level.rebellion then
      Game._global_inventory = {}
      for _,item in ipairs(SHARED_ITEMS) do
         Game._global_inventory[item] = 0
      end
   elseif Game._global_inventory == nil or not Game._gi_ticks
   or Game._gi_ticks < Game.ticks - 5 then
      Game._global_inventory = {}
      for _,item in ipairs(SHARED_ITEMS) do
         Game._global_inventory[item] = 0
      end
      -- only bit of nondeterminism
      for k,v in pairs(DEFAULT_ITEMS) do
         Game._global_inventory[k] = v
      end      
      for player in Players() do
         for _,item in ipairs(SHARED_ITEMS) do
            if player.items[item] > (DEFAULT_ITEMS[item] or 0) then
               Game._global_inventory[item] = Game._global_inventory[item]
                  + (player.items[item] - (DEFAULT_ITEMS[item] or 0))
            end
         end
      end
      local old_got_item = Triggers.got_item
      Triggers.got_item = nil
      for player in Players() do
         for _,item in ipairs(SHARED_ITEMS) do
            if player.items[item] ~= Game._global_inventory[item] then
               player.items[item] = Game._global_inventory[item]
            end
         end
      end
      Triggers.got_item = old_got_item
   end
end

function Triggers.idle()
   local old_got_item = Triggers.got_item
   Triggers.got_item = nil
   local lost_items = {}
   for player in Players() do
      if not player.dead then
         for _,item in ipairs(SHARED_ITEMS) do
            if player.items[item] < Game._global_inventory[item] then
               lost_items[item] = (lost_items[item] or 0)
                  + (Game._global_inventory[item] - player.items[item])
            elseif (player.items[item] or 0) > Game._global_inventory[item]
            then
               Players.print("Shenanigans! "..player.name.." had too many "..item.mnemonic.."!")
               player.items[item] = Game._global_inventory[item]
            end
         end
      end
   end
   for _,item in ipairs(SHARED_ITEMS) do
      local count = lost_items[item]
      if count then
         if Game._global_inventory[item] < count then
            Players.print("Got a freebie "..item.mnemonic.."!")
            Game._global_inventory[item] = 0
         else
            Game._global_inventory[item] = Game._global_inventory[item] - 1
         end
      end
   end
   for player in Players() do
      if not player.dead then
         for _,item in ipairs(SHARED_ITEMS) do
            local count = lost_items[item]
            if count then
               player.items[item] = Game._global_inventory[item]
            end
         end
      end
   end
   Triggers.got_item = old_got_item
   Game._gi_ticks = Game.ticks
end

function Triggers.got_item(item, player)
   if not SHARED_ITEMS[item] then return end
   local old_got_item = Triggers.got_item
   Triggers.got_item = nil
   Game._global_inventory[item] = (Game._global_inventory[item] or 0) + 1
   for other in Players() do
      if other ~= player and not other.dead then
         other.items[item] = Game._global_inventory[item]
      end
   end
   Triggers.got_item = old_got_item
end

function Triggers.player_revived(player)
   local old_got_item = Triggers.got_item
   Triggers.got_item = nil
   for item,amount in pairs(Game._global_inventory) do
      if player.items[item] ~= amount then
         player.items[item] = amount
      end
   end
   Triggers.got_item = old_got_item
   player.weapons.active = true
end

function Triggers.player_killed(player)
   for _,item in ipairs(SHARED_ITEMS) do
      player.items[item] = 0
   end
   player.weapons.active = false
end
]=], "@fair.lua")()
load([[
function Triggers.player_damaged(victim, aggressor_player, aggressor_monster,
                                 damage_type, damage_amount, projectile)
   if aggressor_player and aggressor_player ~= victim
      and (Game.type == "cooperative play"
           or aggressor_player.team == victim.team) then
      -- this will either take effect, or...
      victim.life = victim.life + damage_amount
      -- this will prevent shield from noticing the damage
      return false
   end
end
]], "@iff.lua")()
load([=[
--[[
Here's the deal.

- Players have separate health and shield.
- Health can absorb 75 damage. Each layer of shield can also absorb 75. (This
means that 1x shield plus health = vanilla 1x shield, and 3x shield plus health
   = vanilla 2x shield)
- Players will slowly regenerate health.
- Players who are not damaged for a while will regenerate shields, but only if
the shield is not fully depleted.
- Outside Rebellion, players start with a 1x shield.
- 1x, 2x, 3x rechargers enable 1x, 2x, 3x shield and stop bleeding.
- Activating a pattern buffer will stop bleeding.
# BLOODY DAMAGE #
- Bloody damage types: projectile, claws, yeti claws, shotgun
- Players who take "bloody" damage to health start bleeding.
- Bleeding players slowly lose health and will eventually end up at 0 health.
- Bleeding can be stopped by recharging health or accessing any refuelling
panel (other than oxygen) or accessing a pattern buffer
# MELEE DAMAGE #
- Melee damage types: crushing, fists, claws, yeti claws, hulk slap
- Melee damage can penetrate a level 1 shield by 50%.
# ELECTRIC DAMAGE #
- Electric damage types: compiler, staff, fusion, defender
- Electric damage types do double damage to shields.
- Electric damage can disable any one "overwhelmed" layer of shield.
- e.g. if you have temporarily gone down to 0.8x shield, and you take a hit
from a compiler bolt, you lose your 3x. If you take a second hit, you lose your
2x. If you are hit with shields down, your shield is disabled (until you can
find a terminal)!
- It does NOT disable a layer of shield that it overwhelmed *itself*... if you
are at 1.01x and get hit, you do not lose your 2x
]]

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
]=], "@shld.lua")()
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
