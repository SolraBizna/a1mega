local lfs = require "lfs"

local components = {}

for s in lfs.dir("src") do
   if s ~= "footer.lua" and s ~= "header.lua" and s:sub(-4,-1) == ".lua" then
      components[#components+1] = s:sub(1,-5)
   end
end

table.sort(components)

local enabled = {true}
while not enabled[#components+1] do
   local t = {}
   for n=1,#components do
      if enabled[n] then
         t[#t+1] = components[n]
      end
   end
   local outname = "out/a1mega."..table.concat(t,"+")..".lua"
   io.write(outname.."\r")
   io.flush()
   io.write((" "):rep(#outname).."\r")
   for n=1,#t do
      t[n] = "src/"..t[n]..".lua"
   end
   if not os.execute("lua util/compile.lua "..outname.." src/header.lua "..table.concat(t," ").." src/footer.lua") then
      error("a compile failed!")
   end
   local n = 1
   while enabled[n] do
      enabled[n] = false
      n = n + 1
   end
   enabled[n] = true
end
print("All compiles successful, "..os.date("%c"))
