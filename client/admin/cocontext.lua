
if not CreateTimeWheel then
    require("admin.timewheel") -- 时间轮定时器
end
local cotimer = CreateTimeWheel(10)

local STATUS_TYPE = {
    WAIT_PACKAGE = 1,
    HANDLE_PACKAGE = 2,
}

local table_insert = table.insert
local coroutine_create = coroutine.create
local coroutine_resume = coroutine.resume
local coroutine_yield = coroutine.yield
local coroutine_status = coroutine.status
local coroutine_running = coroutine.running

--[[
local function coroutine_resume(co, ...)
    local success, result = coroutine.resume(co, ...)
    if true ~= success then
        local info = debug.getinfo( 2, "nSl")
        local str = ""
        if info then
            local source = info.source or ""
            local last = source
            local pattern = string.format("([^%s]+)", "/")
            source:gsub(pattern, function(c) last = c end)
            str = string.format("[%s:%d]",last, info.currentline)     
        end   
        Print(str, result)        
    end
end
]]

-- function owner:handler(pkg, current_coroutine)
-- function handler(pkg, current_coroutine)

function CreateChannel(handler, owner, ...)
    local _queue = {}
    local _M = {}
    local _status = STATUS_TYPE.HANDLE_PACKAGE
    local _co
    local _count = 0

    local function __pop()
        if not _co then
            return nil
        end

        local k,v = next(_queue)
        if k ~= nil then
            _queue[k] = nil
        else
            _status = STATUS_TYPE.WAIT_PACKAGE
            _count = 0
            v = coroutine_yield()
        end
        _status = STATUS_TYPE.HANDLE_PACKAGE
        _count = _count + 1
        if _count > 10 then -- max_loop
            CoSleep(1, _co)
            _count = 0
        end
        return v
    end

    local function __loop(self, ...)
        while _co do
            local pkg = __pop()
            if not pkg then
                break
            end
            local success,err
            if not self then
                success, err =Try(handler, pkg, _co, ...)
            else
                success, err = Try(handler, self, pkg, _co, ...)
            end
            if not success then
                Print("handler failed", err)
            end
        end
        _co = nil
    end

    -- 给工作线程投递消息
    function _M:Push(pkg)
        if _co then
            if _status == STATUS_TYPE.WAIT_PACKAGE then
                coroutine_resume(_co, pkg)
            else
                table_insert(_queue, pkg)
            end
        else
            Print("coroutine is closed", _status)
        end
    end
    -- 关闭
    function _M:Close()
        if _co and coroutine_status(_co) == "suspended" then
            coroutine_resume(_co)
        end
        _queue = {}
        _co = nil
    end

    _co = coroutine_create(__loop)
    coroutine_resume(_co, owner, ...)
    return _M
end

local function __safe_handler(handler, co, ...)
    local success, err_msg = Try(handler, co, ...)
    if not success then
        Print(err_msg)
    end
end

function CreateCoProcess(handler, ...)
    local co = coroutine_create(__safe_handler)
    coroutine_resume(co, handler,co, ...)
    return co
end

function GetCurrentCoroutine()
    local co, is_main = coroutine_running() -- lua 5.1、luajit 失败
    assert(not is_main, "this operation cannot be performed on the main thread")
    return co
end

function __CurrentCoroutine()
    local co, is_main = coroutine_running()
    if is_main then
        return nil
    else
        return co
    end
end

function CoSleep(ms, cuco)
    if not cuco then
        local co, is_main = coroutine_running() -- lua 5.1、luajit 失败
        assert(not is_main, "can not run on the main thread")
        cuco = co
    end
    if not ms or ms < 1 then
        return false
    end
    cotimer:After(ms, function (i, t)
        if coroutine.status(cuco) == "suspended" then
            coroutine_resume(cuco, true)
        end
    end)
    return coroutine_yield()
end
