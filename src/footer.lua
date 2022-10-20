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
