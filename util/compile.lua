if #arg < 2 then
   print("usage: compile output.lua input1.lua [input2.lua ...]")
   os.exit(1)
end

local outf = assert(io.open(arg[2], "wb"))

outf:write("a1megas_enabled = {\n")
for script in arg[1]:gmatch("[^+]+") do
   outf:write("  "..script.."=true,\n")
end
outf:write("}\n\n")

for n=3,#arg do
   local inf = assert(io.open(arg[n], "rb"))
   local a = inf:read("*a")
   inf:close()
   local s,e = load(a, "@"..arg[n])
   if not s then
      error(e)
   end
   local eq_count = 0
   while a:match("%]"..("="):rep(eq_count).."%]") do
      eq_count = eq_count + 1
   end
   local eq = ("="):rep(eq_count)
   outf:write(("load([%s[\n%s]%s], %q)()\n"):format(eq, a, eq, "@"..assert(arg[n]:match("[^/\\]+$"))))
end
