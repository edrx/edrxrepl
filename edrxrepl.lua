-- This file: edrxrepl.lua - a REPL for Lua.
--    http://angg.twu.net/edrxrepl/edrxrepl.lua.html
--    http://angg.twu.net/edrxrepl/edrxrepl.lua
--     (find-angg        "edrxrepl/edrxrepl.lua")
--         https://github.com/edrx/edrxrepl
--         https://github.com/edrx/edrxrepl#Introduction
--
-- In the HTML version the sexp hyperlinks work.
-- See: (find-eev-quick-intro "3. Elisp hyperlinks")
--      (find-eepitch-intro "3. Test blocks")
--
-- Author:  Eduardo Ochs <eduardoochs@gmail.com>
-- Version: 2021jan11
-- License: GPL3 at this moment.
-- If you need another license, get in touch!


-- «.Class»		(to "Class")
-- «.MyXpcall»		(to "MyXpcall")
-- «.MyXpcall-class»	(to "MyXpcall-class")
-- «.MyXpcall-tests»	(to "MyXpcall-tests")
-- «.Repl»		(to "Repl")
-- «.Repl-tests»	(to "Repl-tests")


-- Some functions from my initfile. See:
-- (find-angg "LUA/lua50init.lua" "pack-and-unpack")
-- (find-angg "LUA/lua50init.lua" "splitlines-5.3")
-- (find-angg "LUA/lua50init.lua" "split")
-- (find-es "lua5" "loadstring")
loadstring = loadstring or load
pack   = table.pack or function (...) return {n=select("#", ...), ...} end
unpack = unpack or table.unpack
split = function (str, pat)
    local arr = {}
    string.gsub(str, pat or "([^%s]+)", function (word)
        table.insert(arr, word)
      end)
    return arr
  end
splitlines = function (bigstr)
    local arr = split(bigstr, "([^\n]*)\n?")
    if _VERSION:sub(5) < "5.3" then
      table.remove(arr)
    end
    return arr
  end



-- «Class»  (to ".Class")
-- Commented version:
-- (find-angg "dednat6/dednat6/eoo.lua" "Class")
Class = {
    type   = "Class",
    __call = function (class, o) return setmetatable(o, class) end,
  }
setmetatable(Class, Class)



--  __  __      __  __                _ _ 
-- |  \/  |_   _\ \/ /_ __   ___ __ _| | |
-- | |\/| | | | |\  /| '_ \ / __/ _` | | |
-- | |  | | |_| |/  \| |_) | (_| (_| | | |
-- |_|  |_|\__, /_/\_\ .__/ \___\__,_|_|_|
--         |___/     |_|                  
--
-- «MyXpcall»  (to ".MyXpcall")
-- See: (find-lua51manual "#pdf-xpcall" "xpcall (f, err)")
--      (find-lua52manual "#pdf-xpcall" "xpcall (f, msgh [, arg1, ...])")
--      (find-lua51manual "#pdf-debug.traceback")
--      (find-lua51manual "#pdf-error")
--      (find-es "lua5" "xpcall-2020")
--
-- If a Lua REPL calls F2, which calls F1, which calls F0, which
-- yields an error, we have this call diagram:
--
--   REPL
--   : \-> F2
--   :     \-> F1
--   :         \-> F0
--   :             \-> error
--   :                 |-> print(debug.traceback())
--   v <---------------/
--   
-- Lua's "xpcall" lets us do something similar to that outside the Lua
-- REPL, but in a way that I found very difficult to decypher and
-- quite difficult to use. My MyXpcall class is a wrapper around
-- xpcall that lets me use xpcall in a way that 1) has good defaults,
-- 2) is super-easy to hack, 3) lets me change the defaults easily, 4)
-- saves all the intermediate results. If I do
--
--   myx = MyXpcall:new()
--
-- then the call diagram of myx:call(F2) on errors is:
--
--   myx:call(F2)
--   : \-> F2
--   :     \-> F1
--   :         \-> F0
--   :             \-> myx.errhandler
--   :                 |-> debug.traceback
--   :                 |-> print(myx:shortertraceback())
--   : <---------------/
--   v
--
-- and these fields get set:
--
--   myx.xp_results: the results of xpcall(wrapper_around_F2)
--   myx.eh_args:    the arguments given to myx.errhandler
--   myx.tb:         the string returned by debug.traceback()
--
-- when F2 succeeds these fields get set:
--
--   myx.f_results:  the results of F2(...)
--   myx.xp_results: the results of xpcall(wrapper_around_F2)
--
-- For more details see
-- the code and the tests.



-- «MyXpcall-class»  (to ".MyXpcall-class")
-- Also in: (find-angg "LUA/lua50init.lua" "MyXpcall")
--
MyXpcall = Class {
  type = "MyXpcall",
  new  = function (T) return MyXpcall(T or {lvl = 3}) end;
  __index = {
    call = function (myx, f, ...)
        return myx:call0(f, ...):ret()
      end,
    call0 = function (myx, f, ...)
        local f_args = pack(...)
        local g = function () myx.f_results = pack(f(unpack(f_args))) end
        myx.xp_results = pack(xpcall(g, myx:errhandler()))
        return myx
      end,
    success = function (myx) return myx.xp_results[1] end,
    ret = function (myx)
        if myx:success() then return unpack(myx.f_results) end
      end,
    errhandler = function (myx)
        return function (...)
            myx.eh_args = pack(...)
	    myx.tb = debug.traceback(myx:tbargs())
	    print(myx:shortertraceback())
            return "eh22", "eh33", "eh44"   -- only the first is used
          end
      end,
    tbargs = function (myx)
        return myx.eh_args[1], myx.lvl
      end,
    shortertraceback = function (myx)
        local lines = splitlines(myx.tb)
	return table.concat(lines, "\n", 1, #lines - 6)
      end,
  },
}

-- «MyXpcall-tests»  (to ".MyXpcall-tests")
--[[
 (eepitch-lua51)
 (eepitch-kill)
 (eepitch-lua51)
dofile "edrxrepl2020.lua"

fcode = function (n)
    return format("F%d = function (...) return 0,F%d(...) end", n+1, n)
  end


-- Test calling a function
-- that yields an error
--
F0 = function (...) PP(...); error("Errrr!") end
for i=0,20 do print(fcode(i)) end
for i=0,20 do  eval(fcode(i)) end
F20(2, 3, 4)

myx = MyXpcall.new():call0(F20, 2, 3, 4)
PP(myx:ret())
PPV(keys(myx))


-- Test calling a function
-- that succeeds
--
F0 = function (...) PP(...); return 22,33 end
myx = MyXpcall.new():call0(F20, 2, 3, 4)
PP(myx:ret())
PPV(keys(myx))

--]]




--  ____            _ 
-- |  _ \ ___ _ __ | |
-- | |_) / _ \ '_ \| |
-- |  _ <  __/ |_) | |
-- |_| \_\___| .__/|_|
--           |_|      
--
-- «Repl»  (to ".Repl")
-- Also in: (find-angg "LUA/lua50init.lua" "Repl")
-- A simple REPL for Lua that handles errors well enough.
-- It uses MyXpcall to run code.
-- Usage:
--
--   REPL = Repl:new(); REPL:repl()
--
-- To exit the REPL set REPL.stop to true.
--
-- NOTE ON '='s: The Repl class implements a trick that is found in
-- the REPLs of Lua5.1 and Lua5.2 but was dropped from Lua5.3 onwards.
-- It is explained in the manpages for lua5.1 and lua5.2 as:
-- 
--   If a line starts with '=', then lua displays the values of all
--   the expressions in the remainder of the line. The expressions
--   must be separated by commas.
-- 
-- In Lua5.3 they changed that to this (also copied from the manpage):
-- 
--   If the line contains an expression or list of expressions, then
--   the line is evaluated and the results are printed.
-- 
-- See for example this thread:
-- http://lua-users.org/lists/lua-l/2020-10/msg00209.html


Repl = Class {
  type = "Repl",
  new  = function () return Repl({}) end,
  __index = {
    bigstr = function (r)
        return table.concat(r.lines, "\n")
      end,
    errincomplete = function (r, err)
        return err:find(" near '?<eof>'?$")
      end,
    incompletep0 = function (r, bigstr)
        local f, err = loadstring(bigstr)
        return (f == nil) and r:errincomplete(err)
      end,
    code = function (r) return r:bigstr():gsub("^=", "return ") end,
    incompletep = function (r) return r:incompletep0(r:code()) end,
    read00 = function (r, prompt) io.write(prompt); return io.read() end,
    read0 = function (r, prompt) table.insert(r.lines, r:read00(prompt)) end,
    read1 = function (r) return r:read0 ">>> "  end,
    read2 = function (r) return r:read0 "... " end,
    read = function (r)
        r.lines = {}
        r:read1()
        while r:incompletep() do r:read2() end
        return r
      end,
    evalprint = function (r)
        r.f, r.err = loadstring(r:code())
        if not r.f then print(r.err); return r end
        r.myx = MyXpcall.new():call0(r.f)
        if r.myx:success() and r:bigstr():match("^=") then r:print() end
        return r
      end,
    print = function (r) print(unpack(r.myx.f_results)) end,
    repl = function (r) while not r.stop do r:read():evalprint() end end,
  },
}


-- «Repl-tests»  (to ".Repl-tests")
-- (find-elisp-intro "5. Variables" "If you execute lines 1, 3, and 4")
-- (find-angg "LUA/lua50init.lua")
--[[
 (eepitch-shell)
 (eepitch-kill)
 (eepitch-shell)
export LUA_INIT=""
export LUA_INIT=@$HOME/LUA/lua50init.lua
lua5.1
lua5.2
lua5.3
lua5.4
PP()

 (eepitch-lua51)
 (eepitch-kill)
 (eepitch-lua51)
dofile "edrxrepl2020.lua"
REPL = Repl.new()
REPL:repl()

print(
  1+2
)
= 1+2
= 1, 2, 3
= nil, 22
=

fcode = function (n)
    return format("F%d = function (...) return 0,F%d(...) end", n+1, n)
  end
F0 = function (...) PP(...); error("Errrr!") end
for i=0,20 do print(fcode(i)) end
for i=0,20 do  eval(fcode(i)) end
F20(2, 3, 4)
print(REPL.myx.tb)
REPL.stop = 1

print(eval)

--]]
