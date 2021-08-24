-- This file:
--   https://github.com/edrx/edrxrepl/
--       http://angg.twu.net/edrxrepl/edrxpcall.lua.html
--       http://angg.twu.net/edrxrepl/edrxpcall.lua
--        (find-angg        "edrxrepl/edrxpcall.lua")
-- Author: Eduardo Ochs <eduardoochs@gmail.com>
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



-- Introduction
-- ============
-- When we do things like this in Lua,
--
--   status, error = pcall(f)
--   status, error = xpcall(f, errorhandler)
--
-- the function f is called in "protected mode", and any errors are
-- handled by pcall and xpcall. The argument "errorhandler" to xpcall
-- is a function that is run after the error occurs and before the
-- stack is unwinded, and it can be used to produce a traceback or
-- save it into a variable. See:
--
--   (find-lua51manual "#pdf-pcall"  "pcall (f, arg1, ...)")
--   (find-lua51manual "#pdf-xpcall" "xpcall (f, err)")
--   (find-lua52manual "#pdf-xpcall" "xpcall (f, msgh [, arg1, ...])")
--   (find-lua51manual "#pdf-debug.traceback")
--   (find-lua51manual "#pdf-error")
--   (find-pil3page (+ 19 77) "8.4 Errors")
--   (find-pil3page (+ 19 79) "8.5 Error Handling and Exceptions")
--   (find-pil3page (+ 19 79) "8.6 Error Messages and Tracebacks")
--
-- I always found xpcall too hard to use, so I wrote the class
-- EdrxPcall below, that feels more hacker-friendly (to me)... it uses
-- eoo.lua, it saves all the intermediate values, and all its methods
-- can be overridden.
--
-- The four high-level ways of calling function with EdrxPcall are
-- these ones:
--
--   EdrxPcall.new():  call(F2, 3, 4):  out()
--   EdrxPcall.new():  call(F2, 3, 4):  out("=")
--   EdrxPcall.new():prcall(F2, 3, 4):prout()
--   EdrxPcall.new():prcall(F2, 3, 4):prout("=")
--
-- The option "=" behaves like an initial "=" in the REPLs of Lua5.1
-- and Lua5.2, in the sense that it makes the results of F2(3, 4) be
-- printed in case of success. The alternatives with "pr" redirect the
-- outputs of the "print"s called by F2(3, 4) to a string before
-- printing them, and used by emacs-lua. To understand how all this
-- works try the tests at the end of this file.



-- «.from-init»		(to "from-init")
-- «.Class»		(to "Class")
-- «.EdrxPcall»		(to "EdrxPcall")
-- «.EdrxPcall-tests»	(to "EdrxPcall-tests")


-- «from-init»  (to ".from-init")
-- Some functions from my initfile. See:
-- (find-angg "LUA/lua50init.lua" "pack-and-unpack")
-- (find-angg "LUA/lua50init.lua" "splitlines-5.3")
-- (find-angg "LUA/lua50init.lua" "split")
-- (find-es "lua5" "loadstring")
loadstring = loadstring or load
pack   = table.pack or function (...) return {n=select("#", ...), ...} end
unpack = unpack or table.unpack
myunpack = function (arg) return unpack(arg, 1, arg.n) end
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

map = function (f, arr, n)
    local brr = {}
    for i=1,(n or #arr) do table.insert(brr, (f(arr[i]))) end
    return brr
  end
mapconcat = function (f, arr, sep, n)
    return table.concat(map(f, arr, n), sep)
  end
mapconcatpacked = function (f, arr, sep)
    return mapconcat(f or tostring, arr, sep or "  ", arr.n)
  end
print_to_string = function (...)
    return mapconcatpacked(tostring, pack(...), "\t")
  end

-- «Class»  (to ".Class")
-- Commented version:
-- (find-angg "dednat6/dednat6/eoo.lua" "Class")
Class = {
    type   = "Class",
    __call = function (class, o) return setmetatable(o, class) end,
  }
setmetatable(Class, Class)



-- «EdrxPcall»  (to ".EdrxPcall")
--
EdrxPcall = Class {
  type = "EdrxPcall",
  new  = function (T) return EdrxPcall(T or {}) end,
  __tostring = tos_VTable,
  __index = {
    call = function (xpc, f, ...)
        return xpc:callprep(f, ...):callrun()
      end,
    callprep = function (xpc, f, ...)
        xpc.f = f
        xpc.f_args = pack(...)
        xpc.g = function ()
            xpc.f_results = pack(xpc.f(myunpack(xpc.f_args)))
          end
        xpc.eh = xpc:eh0()
	return xpc
      end,
    callrun = function (xpc)
        xpc.xp_results = pack(xpcall(xpc.g, xpc.eh))
        return xpc
      end,
    --
    eh0 = function (xpc)
        return function (errmsg)
	    xpc.err_msg = errmsg
            xpc:tb()
          end
      end,
    tb = function (xpc)
        xpc.tb_string  = debug.traceback("", xpc.tb_lvl)
      end,
    tb_lvl = 3,
    tb_e   = 6,
    --
    success = function (xpc) return xpc.xp_results[1] end,
    results = function (xpc) return myunpack(xpc.f_results) end,
    tbshorter = function (xpc)
        local lines = splitlines(xpc.tb_string)
	return table.concat(lines, "\n", 1, #lines - (xpc.tb_e or 6))
      end,
    outsuccess = function (xpc)
        return print_to_string(xpc:results())
      end,
    outerror = function (xpc)
        return xpc.err_msg .. xpc:tbshorter()
      end,
    out = function (xpc, printresults)
        if xpc:success()
        then return (printresults and xpc:outsuccess()) or ""
        else return xpc:outerror()
        end
      end,
    --
    pr0 = function (xpc)
        xpc.pr_list = {}
        xpc.pr_oldprint = print
        print = function (...)
            table.insert(xpc.pr_list, print_to_string(...).."\n")
          end
        return xpc
      end,
    pr1 = function (xpc)
        print = xpc.pr_oldprint
        xpc.pr_out = table.concat(xpc.pr_list, "")
        return xpc
      end,
    prcall = function (xpc, ...)
        return xpc:pr0():call(...):pr1()
      end,
    prout = function (xpc, printresults)
        return xpc.pr_out .. xpc:out(printresults)
      end,
  },
}


-- «EdrxPcall-tests»  (to ".EdrxPcall-tests")
--[[
 (eepitch-lua51)
 (eepitch-kill)
 (eepitch-lua51)
dofile "edrxpcall.lua"

F2  = function (a, b) print("F2",  a, b); return F1(2, 3), 4 end
F1  = function (a, b) print("F1",  a, b); return F0(1, 2), 3 end
F01 = function (a, b) print("F01", a, b); return 0, 1 end
F00 = function (a, b) print("F00", a, b); error("F00 ERROR!!!") end

F0 = F01
  F2(3, 4)   --> prints F2/F1/F01
= F2(3, 4)   --> prints F2/F1/F01, 04

F0 = F00
  F2(3, 4)   --> prints F2/F1/F00, error, traceback
= F2(3, 4)   --> prints F2/F1/F00, error, traceback

F0 = F01
xpc = EdrxPcall.new():  call(F2, 3, 4)  --> prints F2/F1/F01
= xpc:out()                             --> prints ""
= xpc:out("=")                          --> prints "0  4"

xpc = EdrxPcall.new():prcall(F2, 3, 4)  --> prints nothing
= xpc:prout()                           --> prints F2/F1/F01
= xpc:prout("=")                        --> prints F2/F1/F01, 04

= xpc

F0 = F00
xpc = EdrxPcall.new():  call(F2, 3, 4)  --> prints F2/F1/F01
= xpc:out()                             --> prints error, traceback
= xpc:out("=")                          --> prints error, traceback

xpc = EdrxPcall.new():prcall(F2, 3, 4)  --> prints nothing
= xpc:prout()                           --> prints F2/F1/F01, error, traceback
= xpc:prout("=")                        --> prints F2/F1/F01, error, traceback

= xpc

--]]


