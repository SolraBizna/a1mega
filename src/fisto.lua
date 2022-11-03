local BLACKLISTED_ITEMS = {}
for _,v in ipairs{"pistol","fusion pistol","assault rifle","missile launcher",
                  "alien weapon","flamethrower","shotgun","smg",
                  "pistol ammo","fusion pistol ammo","assault rifle ammo",
                  "assault rifle grenades","missile launcher ammo",
                  "alien weapon ammo","flamethrower ammo","shotgun ammo",
                  "smg ammo"} do
   BLACKLISTED_ITEMS[ItemTypes[v]] = true
end

local function should_toggle(panel)
   if panel.uses_item then return false end
   if panel.can_be_destroyed and panel.status then return false end
   return true
end

function Triggers.init()
   for item in pairs(BLACKLISTED_ITEMS) do
      item.minimum_count = 0
      item.maximum_count = 0
      item.initial_count = 0
      item.total_available = 0
   end
end

function Triggers.idle()
   for item in Items() do
      if BLACKLISTED_ITEMS[item.type] then
         item:delete()
      end
   end
   for player in Players() do
      for k in pairs(BLACKLISTED_ITEMS) do
         if player.items[k] > 0 then
            player.items[k] = 0
         end
      end
      if not player.dead and player.weapons.current ~= "fist" then
         player.action_flags.cycle_weapons_backward = true
         player.action_flags.cycle_weapons_forward = false
      end
      if not player.dead and player.action_flags.action_trigger and player:find_action_key_target() == nil then
         local target,x,y,z,polygon = player:find_target(true)
         if is_side(target) and target.control_panel and should_toggle(target.control_panel) then
            local proj = Projectiles.new(x, y, z, polygon, "grenade")
            if proj then
               proj.owner = player
               proj.yaw = player.yaw
            end
         end
      end
   end
end
