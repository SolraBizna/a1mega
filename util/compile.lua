if #arg < 2 then
   print("usage: compile scripts output.lua")
   os.exit(1)
end

local outf = assert(io.open(arg[2], "wb"))

local function add_script(path, condition)
   local inf = assert(io.open(path, "rb"))
   local a = inf:read("*a")
   inf:close()
   local s,e = load(a, "@"..path)
   if not s then
      error(e)
   end
   if condition then
      local eq_count = 0
      while a:match("%]"..("="):rep(eq_count).."%]") do
         eq_count = eq_count + 1
      end
      local eq = ("="):rep(eq_count)
      if type(condition) == "string" then
         outf:write("if ",condition," then\n")
      end
      outf:write(("load([%s[\n%s]%s], %q)()\n"):format(eq, a, eq, "@"..assert(path:match("[^/\\]+$"))))
      if type(condition) == "string" then
         outf:write("end\n")
      end
   else
      outf:write(a)
   end
end

add_script("src/header.lua", false)

for script in arg[1]:gmatch("[^+]+") do
   add_script("src/"..script..".lua", "a1megas_enabled."..script)
end

add_script("src/footer.lua", true)
