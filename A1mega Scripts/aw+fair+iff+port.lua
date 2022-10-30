a1megas_enabled = {
  aw=true,
  fair=true,
  iff=true,
  port=true,
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

a1mega = a1mega or {}
a1mega.SHARED_ITEMS = SHARED_ITEMS

function a1mega.shallow_clone(i)
   local o = {}
   for key,value in pairs(i) do o[key]=value end
   return o
end

local function force_inventory_sync()
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
a1mega.force_inventory_sync = force_inventory_sync

function Triggers.init(restoring_game)
   if not restoring_game and Level.rebellion then
      Game._global_inventory = {}
      for _,item in ipairs(SHARED_ITEMS) do
         Game._global_inventory[item] = 0
      end
   elseif not restoring_game and a1megas_enabled.hardcore and Game._checkpointed_global_inventory and a1mega.forcing_restart() then
      Game._global_inventory = a1mega.shallow_clone(Game._checkpointed_global_inventory)
      force_inventory_sync()
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
      force_inventory_sync()
   end
end

function Triggers.idle()
   local old_got_item = Triggers.got_item
   Triggers.got_item = nil
   local lost_items = {}
   for player in Players() do
      if not player.dead then
         if player.items["knife"] < 2 then
            player.items["knife"] = 2
         end
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
