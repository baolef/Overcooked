-- last 2019-09-15
local TIMER_WHEEL_SCALE = 100 -- 进制：每个轮子上刻度的个数
local TIMER_WHEEL_COUNT	= 4 -- 轮子数:  100^4 次,如果最小精度是100ms,则最长定时时间10,000,000秒 7.6年
local PERSECOND_SCHEDULE_COUNT = 10 -- 每秒最多触发十个事件，防止处理周期过长
local unpack = unpack or table.unpack
-- ------------------------------------------------------------------------- --

local Print = Print or function(...)
    local info = debug.getinfo( 2, "nSl")
    local str = ""
    if info then
        local source = info.source or ""
        local last = source
        local pattern = string.format("([^%s]+)", "/")
        source:gsub(pattern, function(c) last = c end)
        str = string.format(" [%s:%d]",last, info.currentline)
    end
    print("===lua=== " .. os.date("%H:%M:%S", os.time()) .. str,...)
end

-- -------------------------------------------------------------------------------------- --
local _wheel=Class()
function _wheel:ctor(scale)
    self.m_slots = {}
    self.m_pointer = 0      -- (0 ~ 99)
    self.m_scale = scale    -- (1,100, 10000, 1000000)
end
-- 转动一个刻度，剔除本轮子超时的一个列表
function _wheel:_turn()
    local n = self.m_pointer
    n =  (n+1) % TIMER_WHEEL_SCALE

    local result = self.m_slots[n]
    self.m_slots[n] = nil
    self.m_pointer = n
    return result, (0 == n) -- 是否需要进制
end

-- ------------------------------------------------------------------------- --

local _tooth = Class()
function _tooth:ctor(idx, intervalTick, cb, repeat_exec, ...)
        self.m_handler_idx = idx
        self.m_remain_tick = intervalTick
        self.m_raw_interval = intervalTick  -- 原参数
        self.m_call_back = cb
        self.m_repeat = repeat_exec
        self.m_args = {...}
end

local function __get_next(self)
    return self.m_next
end

local function __set_next(self, next)
    self.m_next = next
end

local function __operator(self)
    if self.m_call_back then
        local again = self.m_call_back(self.m_handler_idx, self, unpack(self.m_args)) -- callback(idx, this)
        if not self.m_repeat then
            return false
        end

        return again or again == nil
    end

    return false
end

function _tooth:HandlerIdx()
    return self.m_handler_idx
end

-- public
function _tooth:Cancel()
    self.m_call_back = nil
    self.m_args = nil
end

-- ------------------------------------------------------------------------- --

local _clock = Class()
local _handler_idx = 100


local function __add_tooth(self, mc, node)

    local max = self.m_scale * TIMER_WHEEL_SCALE
    if mc >= max then -- 时间没落在本轮子上
        return false
    end
  
    local up = math.floor(mc / self.m_scale)
    local place = up % TIMER_WHEEL_SCALE -- 放入的位置
    local remain = mc % self.m_scale

    node.m_remain_tick = remain  -- 剩余时间(ms)
-- Print(mc,"*(100ms) node push to", self.m_scale," wheel, place:", place,'remain:', remain, "pointer:", self.m_pointer)
    __set_next(node, self.m_slots[place])
    self.m_slots[place] = node
    return true
end


-- 以原设定的时间，重新加入到时间轮中
local function __append(self, node)
    local mc = node.m_raw_interval
    if mc > 0 then
        local relative= 0
        for i = 1, TIMER_WHEEL_COUNT do
            local wheel= self.m_scalewheels[i]
            relative = relative + wheel.m_pointer * wheel.m_scale
            if __add_tooth(wheel, mc+relative, node) then
                return true
            end
        end
    end
    return false
end

-- timeout,弹出一个事件
local function __provide(self, node)
    if __operator(node) then -- again
        __append(self, node) -- 重新加入
        return true
    end
    return false
end

-- 到点的齿轮上的事件，重新分布到轮子上
local function __carry(self, head)
    while (head) do
        local next = __get_next(head)
        local mc = head.m_remain_tick
        if mc <= 0 then
            if not __provide(self, head) then
                head = nil
            end
        else
            local relative= 0
            for i = 1, TIMER_WHEEL_COUNT do
                local wheel= self.m_scalewheels[i]
                relative = relative + wheel.m_pointer * wheel.m_scale
                if __add_tooth(wheel, mc+relative, head) then
                    break
                end
            end
        end
        head = next
    end
end
-- 外部时钟更新
local function __update(self)
    if self.m_pause then
        return
    end
    self.m_loop_count = self.m_loop_count + 1

    for i = 1, TIMER_WHEEL_COUNT do -- 转动时间轮
        local head, over = self.m_scalewheels[i]:_turn()
        __carry(self, head)
        if not over then
            break
        end
    end
end

function _clock:ctor(delay)
    self.m_scalewheels  = {}
    self.m_head = nil
    self.m_tail = nil
    self.m_delay = delay or 1
    self.m_pause = false
    self.m_loop_count = 0
    local scale = 1
    for _ = 1,TIMER_WHEEL_COUNT do
        table.insert(self.m_scalewheels, _wheel.new(scale))
        scale = scale * TIMER_WHEEL_SCALE
    end

    self.m_schedules = {}
end

local function __is_repeat_schedule(expect)
    return expect and not (expect.year and expect.month and expect.day and expect.hour and expect.minute and expect.second)
end

local function __makeSchedule(expect, callback)
    local now = os.date("*t")
    local year = expect.year or now.year
    local month = expect.month or now.month
    local day = expect.day or now.day
    local hour = expect.hour or now.hour
    local minute = expect.minute or now.min
    local second = expect.second or now.sec
    local intime = os.time({year=year,month=month, day= day,hour=hour,min=minute,sec=second, isdst=false})
    local schedule = {
        expect = expect,
        callback = callback,
        intime = intime,
    }
    if __is_repeat_schedule(expect) and intime <= os.time() then
        if not expect.second then
            schedule.intime = intime + 1

        elseif not expect.minute then
            schedule.intime = intime + 60

        elseif not expect.hour then
            schedule.intime = intime + 3600

        elseif not  expect.day then
            schedule.intime = intime + 86400

        elseif not  expect.month then
            schedule.intime = os.time({year=year,month=month+1, day= day,hour=hour,min=minute,sec=second, isdst=false})

        elseif not expect.year then
            schedule.intime = os.time({year=year+1,month=month, day= day,hour=hour,min=minute,sec=second, isdst=false})
        end
    end
    return schedule
end

local function __checkSchedule(self)
    if not self.m_schedule_timer then
        self.m_schedule_timer = self:NewTicker(1000, function(idx, this)
            local tiggers = {}
            local nowtime = os.time()
            for i=1,PERSECOND_SCHEDULE_COUNT do -- 每秒最多十个事件
                local idx, schedule = next(self.m_schedules)
                if not idx then
                    break
                end

                if schedule and nowtime >= schedule.intime then
                    table.remove(self.m_schedules, 1)
                    table.insert(tiggers, schedule)
                end
            end

            for _, schedule in ipairs(tiggers) do
                schedule.callback()
                if __is_repeat_schedule(schedule.expect) then
                    local expect = schedule.expect
                    self:AddSchedule(expect.year, expect.month, expect.day,expect.hour,expect.minute,expect.second, schedule.callback)
                end
            end
        end)
    end
end


--[[
    Examples:
    Clock:AddSchedule(nil, nil, nil, nil, nil, nil, function() print("every second", os.date("%H:%M:%S")) end)
    Clock:AddSchedule(nil, nil, nil, nil, nil, 5, function() print("every minute", os.date("%H:%M:%S")) end)
    Clock:AddSchedule(nil, nil, nil, nil, 30, 0, function() print("every hour", os.date("%H:%M:%S")) end)
]]
function _clock:AddSchedule(year, month, day,hour,minute,second, callback)
    if not self.m_schedule_timer then
        __checkSchedule(self)
    end
    local expect = {year = year, month = month, day = day, hour = hour, minute = minute,second=second}
    local schedule = __makeSchedule(expect, callback)

    for k,v in ipairs(self.m_schedules) do
        if schedule.intime < v.intime then
            table.insert(self.m_schedules, k, schedule)
            return
        end
    end
    table.insert(self.m_schedules, schedule)
end

-- published
function _clock:AddTimer(ms, cb, repeat_exec, ...)
    if  type(cb) ~= "function" then
        Print("callback error")
        return nil, -1
    end
    if ms < 0 then ms = 1 end

    if not self.timer then -- 因为 CTimer有补偿，不能建造时创建
        -- self.timer = CTimer.on_timeout(self.m_delay, function() __update(self) return self.m_delay end)
        self.timer = CTimer.new(self.m_delay, 0, function() __update(self) return true end)
    end

    _handler_idx = _handler_idx + 1 -- timer id,为了兼容和日志
    local tooth = _tooth.new(_handler_idx, math.ceil(ms / self.m_delay), cb, repeat_exec, ...) -- 新建一个节点

    if __append(self, tooth) then
        return tooth, _handler_idx
    else
        return nil, -1
    end
end

function _clock:SetPause(bool)
    self.m_pause = bool
end

-- published
function _clock:NewTicker(ms, cb, ...)
    return self:AddTimer(ms, cb, true, ...)
end

-- published
function _clock:After(ms, cb, ...)
    return self:AddTimer(ms, cb, false, ...)
end

-- return millisecond
function _clock:GetTime()
   return self.m_loop_count * self.m_delay
end

-- 构建
function CreateTimeWheel(delay)
    return _clock.new(delay)
end
