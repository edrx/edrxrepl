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
-- Version: 20210820
-- License: GPL3 at this moment.
-- If you need another license, get in touch!
--
-- (defun l () (interactive) (find-angg "edrxrepl/edrxrepl.lua"))



-- «.Class»			(to "Class")
-- «.MyXpcall»			(to "MyXpcall")
-- «.MyXpcall-class»		(to "MyXpcall-class")
-- «.MyXpcall-tests»		(to "MyXpcall-tests")
-- «.Repl»			(to "Repl")
--  «.Repl-emacs-lua»		(to "Repl-emacs-lua")
-- «.Repl-tests»		(to "Repl-tests")
-- «.Repl-emacs-lua-tests»	(to "Repl-emacs-lua-tests")


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
--   myx.tb_string:  the string returned by debug.traceback()
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
-- Note that we always use these abbreviations:
--   tb  for  traceback,
--   eh  for  errhandler,
--   xp  for  xpcall.
--
-- Fields with "_"s are variables, and
-- fields without "_"s are methods.
--
MyXpcall = Class {
  type = "MyXpcall",
  new  = function (T) return MyXpcall(T or {tb_lvl = 3}) end,
  __index = {
    call = function (myx, f, ...)
        return myx:call0(f, ...):ret()
      end,
    call0 = function (myx, f, ...)
        local f_args = pack(...)
        local g = function ()
            myx.f_results = pack(f(unpack(f_args)))
          end
        myx.xp_results = pack(xpcall(g, myx:eh()))
        return myx
      end,
    --
    tb = function (myx)
        myx.tb_string  = debug.traceback(myx:tbargs())
        local lines    = splitlines(myx.tb_string)
	myx.tb_shorter = table.concat(lines, "\n", 1, #lines - 6)
	return myx.tb_shorter
      end,
    eh = function (myx)
        return function (...)
            myx.eh_args = pack(...)
            myx:tb()
	    if not myx.quiet then print(myx.tbshorter) end
            return "(eh returns this)"
          end
      end,
    --
    setquiet = function (myx,q) myx.quiet = q; return myx end,
    --
    success = function (myx) return myx.xp_results[1] end,
    errmsg  = function (myx) return myx.eh_args[1] end,
    tbargs  = function (myx) return myx:errmsg(), myx.tb_lvl end,
    results = function (myx) return unpack(myx.f_results) end,
    ret     = function (myx) if myx:success() then return myx:results() end end,
  },
}

-- «MyXpcall-tests»  (to ".MyXpcall-tests")
--[[
 (eepitch-lua51)
 (eepitch-kill)
 (eepitch-lua51)
dofile "edrxrepl.lua"

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

                           F20 (2, 3, 4)
myx = MyXpcall.new():call0(F20, 2, 3, 4)
PP(myx:ret())        -->
PP(myx:success())    --> <false>
PP(myx:errmsg())     --> "stdin:1: Errrr!"
PP(myx.xp_results)   --> {1=<false>, 2="(eh returns this)", "n"=2}
PP(myx.eh_args)      --> {1="stdin:1: Errrr!", "n"=1}
PPV(sorted(keys(myx)))

-- Test calling a function
-- that succeeds
--
F0 = function (...) PP(...); return 22,33 end

                           F20 (2, 3, 4)
myx = MyXpcall.new():call0(F20, 2, 3, 4)
PP(myx:success())      --> <true>
PP(myx:ret())          --> 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 22 33
PP(myx.xp_results)     --> {1=<true>, "n"=1}
PPV(sorted(keys(myx)))

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
    setquiet = function (r, q) r.quiet = q; return r; end,
    evalprint = function (r)
        r.f, r.err = loadstring(r:code())
        if not r.f then print(r.err); return r end
        r.myx = MyXpcall.new():setquiet(r.quiet):call0(r.f)
        if r.myx:success() and r:bigstr():match("^=") then r:print() end
        return r
      end,
    print = function (r) print(unpack(r.myx.f_results)) end,
    --
    -- The standard interface:
    repl = function (r) while not r.stop do r:read():evalprint() end end,
    --
    --
    -- «Repl-emacs-lua»  (to ".Repl-emacs-lua")
    -- See: (find-es "lua5" "Repl-emacs-lua")
    --        http://angg.twu.net/emacs-lua/
    -- An interface for using this inside emacs-lua.
    e0 = function (r) r.lines = {}; return r end, -- clear .lines
    eprompt = function (r)
        r.lines = r.lines or {}
	if #r.lines == 0 then return ">>> " else return "... " end
      end,
    esend = function (r, line)
        table.insert(r.lines, line)
	if r:etrapincomplete() then return r:eretincomplete() end
	if r:etrapcomperror()  then return r:e0():eretcomperror() end
	if r:etrapexecerror()  then return r:e0():eretexecerror() end
        if r:bigstr():match("^=")
	then return r:e0():eretsuccessprint()
        else return r:e0():eretsuccessnonprint()
        end
      end,
    --
    etrapincomplete = function (r)
        return r:incompletep0(r:code())
      end,
    etrapcomperror  = function (r)
	r.f, r.err = loadstring(r:code())
	if not r.f then r:e0(); return "comp error" end
      end,
    etrapexecerror = function (r)
	r.myx = MyXpcall.new():setquiet(r.quiet):call0(r.f)
	return not r.myx:success()
      end,
    --
    eretincomplete      = function (r) return "(incomplete)" end,
    eretcomperror       = function (r) return "(comp error)", r.err end,
    eretexecerror       = function (r) return "(exec error)", r.err end,
    eretsuccessnonprint = function (r) return "(success)" end,
    eretsuccessprint    = function (r) return "(success: =)", tos_packed(r.myx.f_results) end,
    --
    eprint           = function (r) r:print() end,
    esuccessprint0   = function (r) return "(success: =)", r:eprint0() end,
    eprint0          = function (r)
        return mytostring_arg(r.myx.f_results)
      end,
    --
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
dofile "edrxrepl.lua"
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
print(REPL.myx.tb_string)
REPL.stop = 1

print(eval)

--]]


-- «Repl-emacs-lua-tests»  (to ".Repl-emacs-lua-tests")
--[[
 (eepitch-lua51)
 (eepitch-kill)
 (eepitch-lua51)
dofile "edrxrepl.lua"
REPL = Repl.new()
REPL:repl()

--]]


