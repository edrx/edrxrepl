-- This file: edrxrepl.lua - a REPL for Lua.
--   https://github.com/edrx/edrxrepl/
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
-- Version: 20210824
-- License: GPL3 at this moment.
-- If you need another license, get in touch!
--
-- Some eev-isms:
-- (defun o () (interactive) (find-angg "edrxrepl/README.org"))
-- (defun r () (interactive) (find-angg "edrxrepl/edrxrepl.lua"))
-- (defun x () (interactive) (find-angg "edrxrepl/edrxpcall.lua"))


-- This file is being rewritten.



-- The class EdrxRepl uses
-- the class EdrxPcall,
--  that is defined here:
require "edrxpcall"   -- (find-angg "edrxrepl/edrxpcall.lua")



-- «.EdrxRepl»			(to "EdrxRepl")
-- «.EdrxRepl-emacs»		(to "EdrxRepl-emacs")
-- «.EdrxRepl-tests»		(to "EdrxRepl-tests")



--  ____            _ 
-- |  _ \ ___ _ __ | |
-- | |_) / _ \ '_ \| |
-- |  _ <  __/ |_) | |
-- |_| \_\___| .__/|_|
--           |_|      
--
-- «EdrxRepl»  (to ".EdrxRepl")
-- Also in: (find-angg "LUA/lua50init.lua" "Repl")
-- A simple REPL for Lua that handles errors well enough.
-- It uses EdrxPcall to run code.
-- Usage:
--
--   REPL = EdrxRepl:new(); REPL:repl()
--
-- To exit the REPL set REPL.stop to true.
--
-- NOTE ON '='s: The EdrxRepl class implements a trick that is found in
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


EdrxRepl = Class {
  type = "EdrxRepl",
  new  = function () return EdrxRepl({}) end,
  __index = {
    bigstr = function (r) return table.concat(r.lines, "\n") end,
    code = function (r) return r:bigstr():gsub("^=", "return ") end,
    --
    -- incompletep = function (r) return r:incompletep0(r:code()) end,
    -- incompletep0 = function (r, bigstr)
    --     local f, err = loadstring(bigstr)
    --     return (f == nil) and r:incompleteerrp(err)
    --   end,
    --
    read00 = function (r, prompt) io.write(prompt); return io.read() end,
    read0 = function (r, prompt) table.insert(r.lines, r:read00(prompt)) end,
    read1 = function (r) return r:read0 ">>> "  end,
    read2 = function (r) return r:read0 "... " end,
    read = function (r)
        r.lines = {}
        r:read1()
        while r:trapincomplete() do r:read2() end
        return r
      end,
    --
    incompleteerrp = function (r, err)
        return err:find(" near '?<eof>'?$")
      end,
    trapincomplete = function (r)
        r.f, r.err = loadstring(r:code())
        return (r.err and r:incompleteerrp(r.err)) and "[incomplete]"
      end,
    trapcomperror = function (r)
        r.f, r.err = loadstring(r:code())
        return r.err and "[comp error]"
      end,
    trapexecerror = function (r)
        r.xpc = EdrxPcall.new():call(r.f)
	if not r.xpc:success() then
          r.err = r.xpc.err_msg
          r.tb  = r.xpc:tbshorter()
	  return "[exec error]"
        end
      end,
    readevalprint = function (r)
        r:read()
        if r:trapcomperror() then return r:printcomperror() end
        if r:trapexecerror() then return r:printexecerror() end
        if r:bigstr():match("^=")
	then print(r.xpc:outsuccess())
        end
      end,
    --
    -- The standard interface:
    repl = function (r) while not r.stop do r:readevalprint() end end,
    --
    -- «EdrxRepl-emacs»  (to ".EdrxRepl-emacs")
    -- The emacs interface:
    erepltest = function (r)
        while not r.stop do
	  print(r:esend(r:read00(r:eprompt())))
	end
      end,
    --
    e0 = function (r) r.lines = {}; return r end,      -- clear .lines
    eprompt = function (r)
        r.lines = r.lines or {}
        if #r.lines == 0 then return ">>> " else return "... " end
      end,
    etrapexecerror = function (r)
        r.xpc = EdrxPcall.new():prcall(r.f)
	if not r.xpc:success() then
          r.err = r.xpc.err_msg
          r.tb  = r.xpc:tbshorter()
	  return "[exec error]"
        end
      end,
    esend = function (r, line)
        table.insert(r.lines, line)
        if r: trapincomplete() then return r:eretincomplete() end
        if r: trapcomperror()  then return r:e0():eretcomperror() end
        if r:etrapexecerror()  then return r:e0():eretexecerror() end
        if r:bigstr():match("^=")
        then return r:e0():eretsuccessprint()
        else return r:e0():eretsuccessnonprint()
        end
      end,
    eretincomplete = function (r) return "(incomplete)" end,
    eretcomperror  = function (r) return "(comp error)", r.err end,
    eretexecerror  = function (r) return "(exec error)", r.xpc:prout(nil, "\n") end,
    eretsuccessprint = function (r) return "(success: =)", r.xpc:prout("=", "\n") end,
    eretsuccessnonprint = function (r) return "(success)", r.xpc:prout() end,
  },
}


-- «EdrxRepl-tests»  (to ".EdrxRepl-tests")
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
REPL = EdrxRepl.new()
-- REPL:repl()
REPL:repl()

print(
  1+2
)
= 1+2
= 1, 2, 3
= 20, 30, nil, 40, nil
REPL.stop = 1

 (eepitch-lua51)
 (eepitch-kill)
 (eepitch-lua51)
dofile "edrxrepl.lua"
REPL = EdrxRepl.new()
REPL:erepltest()
print(
  1+2
)
= 1+2
= 1, 2, 3
= 20, 30, nil, 40, nil
a = 22
a = a + 33
a = a +
    200
= a
= a +
  2 +
  3
= a +
  2 +
  nil
REPL.stop = 1

REPL.stop = 1


 (eepitch-lua51)
 (eepitch-kill)
 (eepitch-lua51)
dofile "edrxrepl.lua"
EdrxPcall.__index.tb_e = 10
EdrxPcall.__index.tb_e = 5
EdrxPcall.__index.tb_e = 6
REPL = EdrxRepl.new()
REPL:erepltest()
= a + 2 + nil


--]]
