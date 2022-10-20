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
