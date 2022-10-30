function Triggers.idle()
   for player in Players() do
      if not player.dead and player.motion_sensor_active then
         local q = {}
         for monster in Monsters() do
            if not monster.player and monster.valid
            and monster.type.enemies.player then
               local a = math.atan2(monster.y-player.y, monster.x-player.x) - (player.yaw * math.pi / 180)
               while a < 0 do a = a + math.pi * 2 end
               while a >= math.pi * 2 do a = a - math.pi * 2 end
               if a < math.pi * 0.625 or a > math.pi * 1.875 then
                  q.ne = true
                  if q.ne and q.nw and q.se and q.sw then break end
	       end
	       if a < math.pi * 1.125 and a > math.pi * 0.375 then
		  q.se = true
		  if q.ne and q.nw and q.se and q.sw then break end
	       end
	       if a < math.pi * 1.625 and a > math.pi * 0.875 then
		  q.sw = true
		  if q.ne and q.nw and q.se and q.sw then break end
	       end
	       if a < math.pi * 0.125 or a > math.pi * 1.375 then
		  q.nw = true
		  if q.ne and q.nw and q.se and q.sw then break end
	       end
	    end
	 end
	 player.compass.lua = true
	 player.compass.nw = not not q.nw
	 player.compass.ne = not not q.ne
	 player.compass.sw = not not q.sw
	 player.compass.se = not not q.se
      else
         player.compass.lua = false
      end
   end
end
