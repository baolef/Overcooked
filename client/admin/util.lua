
_Monitors = {} -- 全局变量，避免冲突
local __use_conlog__ = true
---------- Try function ----------
function Try(func, ...)
    local __DEBUG = function(msg)
        return debug.traceback(msg, 3)
    end

    if _VERSION == "Lua 5.1" then
        local params = {...}
        local function foo()
            return func(unpack(params))
        end
        return xpcall(foo, __DEBUG)
    else
        return xpcall(func, __DEBUG, ...)
    end
end

---------- Print function ----------
do
    Print = function(...)
        local info = debug.getinfo( 2, "nSl")
        local str = ""
        if info then
            local source = info.source or ""
            local last = source
            local pattern = string.format("([^%s]+)", "/")
            source:gsub(pattern, function(c) last = c end)
            str = string.format("[%s:%d]",last, info.currentline)
        end
        print("===lua=== " .. os.date("%H:%M:%S", os.time()) .. str,...)
        for who, foo in pairs(_Monitors) do -- 发给所有的监控对象
            foo(who, str, ...)
        end
    end
end
---------- Switch function ----------
--[[ Switch example:
    local TStatus = {
        A = 1,
        B = 2,
        C = 3,
    }
    local options =  {
        [TStatus.A] = function(...) Print(1,...) end,
        [TStatus.B] = function(...) Print(2,...) end,
        default = function(...) Print("Default", ...) end,
        }

    local selected = TStatus.C
    Switch(selected, options, 999,766,"SWWsAzz",3,4,2,22)

]]
function Switch(pattern, options, ...)
    local func = options[pattern] or options.default
    if func then
        return func(...)
    end

    local info = debug.getinfo( 2, "nSl")
    local str = "error of `Switch`"
    if info then
        local source = info.source or ""
        local last = source
        local pn = string.format("([^%s]+)", "/")
        source:gsub(pn, function(c) last = c end)
        str = string.format("%s:%d expression error, option is %s, but no `default` option",last, info.currentline, pattern)
    end
    Print(str)

    return false
end
---------- 带计数的无序 table CHashMap ----------
CHashMap = {}

function CHashMap.new()
    local map = {}
    local _count = 0
    local _data = {}
    function map.Count()
        return _count
    end

    setmetatable(map,{__index=_data,
            __newindex=function(t,k, v)
                if k == nil then
                    return
                end
                local old_value = rawget(_data, k)
                if old_value and v == nil then
                    _count = _count - 1
                elseif not old_value and v ~= nil then
                    _count = _count + 1
                end
                rawset(_data, k, v)
            end,
            __call = function(t,k,v)
                return _data
            end
        })
    return map
end

---------- sort pairs of table ----------
function opairs(t)
	local a = {}
    for n in pairs(t) do
		a[#a+1] = n
	end 
	table.sort(a)

	local i = 0
	return function() 
        i = i + 1 
		return a[i], t[a[i]]
	end 
end

---------- sort pairs of table/attempt string and number ----------
function Opairs(t)
	local a = {}
    for n in pairs(t) do
		a[#a+1] = tostring(n)
	end 
	table.sort(a)

	local i = 0
	return function() 
        i = i + 1 
        local key = a[i]
        if t[key] == nil then
            return key, t[tonumber(key)]
        end
		return key, t[key]
	end 
end

---------- defer function ----------
-- defer function
--[[  Example:
    local file1 = io.open("./9.stop_all.bat", "r")
    if file1 ~= nil then
        local _ <close> = defer({}, function(t)
                                        file1:close()
                                        Print("file closed") 
                                    end)

        for one_line in file1:lines() do
            Print("file context:",one_line)
        end
        Print("read file eof")
    end
-- output:
file context:   @taskkill /f /im glua.exe /t
read file eof
file closed

]]
---------- table extend ----------
function table.print(t, printfunc)
    local _visit = {}
    local print = printfunc or print
    local function __serialise_value(value)
        if type(value) == "string" then
            return ("%q"):format(value)
        elseif type(value) == "nil" or type(value) == "number" or
               type(value) == "boolean" then
            return tostring(value)
        else
            return "\"<" .. type(value) .. ">\""
        end
    end
    local function __serialise_key(key)
        return "[".. __serialise_value(key) .. "]"
    end
    local function __print_table(tt, tiers, key)
        
		tiers = tiers or 0
		
		local sPrefix = string.rep("\t", tiers)
		local skeyPrefix = sPrefix .. "  "
		tiers = tiers + 1
			
		if type(tt) ~= "table" then
			print(sPrefix .. __serialise_value(tt))
			return
		end
        local keyname = _visit[tt]
        if keyname then
            print(skeyPrefix .. "{ --[[quoted the '".. tostring(keyname) .. "' ]]  },")
            return
        end
        _visit[tt] = key

		print(sPrefix .. "{")

		for k,v in pairs(tt) do
            if type(v) == "table" then
				print(skeyPrefix ..__serialise_key(k) .. "\t=\t")
				__print_table(v, tiers, key .."." .. k)
			else
				print(skeyPrefix .. __serialise_key(k) .. "\t=\t" .. __serialise_value(v)..",")
			end
        end
        
        print(sPrefix .. "} --[[end of " .. tostring(key) .. "]]")
	end

    __print_table(t, 0, "ROOT")
end

function table.tostring(obj)
    local _visit = {}
    local function __serialize(value, keyname)
        local lua = ""
        local t = type(value)
        if t == "number" then
            return tostring(value)
        elseif t == "boolean" then
            return tostring(value)
        elseif t == "string" then
            return string.format("%q", value)
        elseif t == "table" then
            local kname = _visit[value]
            if kname then
                return  "{--[[quoted the '".. kname .. "']]}"
            end
            _visit[value] = keyname
            lua = "{\n"
            for k, v in pairs(value) do
                lua = lua .. "[" .. __serialize(k) .. "]=" .. __serialize(v, keyname .. "."..k) .. ",\n"
            end
            lua = lua .. "} --[[end of " .. keyname .."]]"
        elseif t == "nil" then
            return nil
        else
            return "'<" .. t ..">'"
--            error("can not __serialize a " .. t .. " type.")
        end
        return lua
    end
    return __serialize(obj, "Root")
end

function table.fromstring(lua)
    local Load = loadstring or load
    -- if _VERSION ~= "Lua 5.1" then
    --     Load = load
    -- end
    local t = type(lua)
    if t == "nil" or lua == "" then
        return nil
    elseif t == "number" or t == "string" or t == "boolean" then
        lua = tostring(lua)
    else
        error("can not un__serialize a " .. t .. " type.")
    end
    lua = "return " .. lua
    local func = Load(lua)
    if func == nil then
        return nil
    end
    return func()
end
---------- string extend ----------
function string:split(sep)
    local sep, fields = sep or "\t", {}
    local pattern = string.format("([^%s]+)", sep)
    self:gsub(pattern, function(c) fields[#fields+1] = c end)
    return fields
end
---------- DeepCopy function ----------
function DeepCopy(orig)
    local orig_type = type(orig)
    local copy
    if orig_type == 'table' then
        copy = {}
        for orig_key, orig_value in next, orig, nil do
            copy[DeepCopy(orig_key)] = DeepCopy(orig_value)
        end
        setmetatable(copy, DeepCopy(getmetatable(orig)))
    else -- number, string, boolean, etc
        copy = orig
    end
    return copy
end

-- Http Request/Responese codec
function URLEncode(s)  
    s = string.gsub(s, "([^%w%.%- ])", function(c) return string.format("%%%02X", string.byte(c)) end)
   return string.gsub(s, " ", "+")
end

function URLDecode(s)  
   s = string.gsub(s, '%%(%x%x)', function(h) return string.char(tonumber(h, 16)) end)
   return s
end

function ReadOnly(tab)
    local mt = {
        __index=tab,
        __newindex = function (t,i) error("cannot redefine readonly variable `"..i.."'", 2) end
    }
    local _m={}
    setmetatable(_m,mt)
    return _m
end


--[[ 
]]
-- desc: Setting a table as struct does not add or remove fields
-- params: noCopy == true, Returns a "proxy" table and all changes fall to the original table
function Struct(base, noCopy)
    if base == nil or type(base) ~= "table" then
        assert("parameter type error")
        return
    end
    if next(base) == nil then
        assert("table is empty")
        return
    end

    local src = {}
    if noCopy then  -- don`t copied the original table
        src = base
    else
        src = DeepCopy(base)
    end

    local m = {}
    local mt = {}
    setmetatable(m, mt)

    mt.__newindex = function (t, k, v)
        if v == nil then
            local env = debug.getinfo(2)
            error("can`t assign to nil variable '"..k.."' in source(".. env.source .."), line:" .. env.currentline)
            return
        else
            if rawget(src, k) == nil then
                local env = debug.getinfo(2)
                error("assign to undeclared variable '"..k.."' in source(".. env.source .."), line:" .. env.currentline)
                return
            else
                rawset(src, k, v)
                return
            end
        end
    end

    mt.__index = function(t,k)
        return rawget(src, k)
    end

-- some c function with rawget(), so return the original table
-- example: protoc:encode(tab) doesn't work properly, so change it to protoc:encode(tab())
    mt.__call = function()
        return src
    end

    return m
end


--[[ Example:

    local base = {fieldA = 123, fieldB = "string"}  -- original table
    local tab = Struct(base)

    tab.fieldA = 100         -- does not affect the original table "base"
    tab.newField = 100       -- error
    tab.fieldA = nil         -- error

    local tab2 = Struct(base, true)  -- Operate "tab2" will affect the "base"
    tab2.fieldA = 999        -- base.fieldA will be to 999
    tab2.newField = 100      -- error
    tab2.fieldB = nil        -- error

-- protobuf

function protobuf_struct(protoname)
    local base = G_pbcodec:get_message(protoname)
    if next(base) ~= nil then
        return Struct(base, true)
    end
    return nil
end

]]


--[[ continue

for i = 10, 1, -1 do
    repeat
        if i == 5 then
            print(i, "continue code here")
            break -- continue
        end

        if i % 3 == 0 then
            print(i, "mod 3 == 0, continue")
            break -- continue
        end

        print(i, "loop code here")
    until true
end


]]
