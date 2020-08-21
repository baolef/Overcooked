local _M = {}
vector_ = {}
local count_ = 0        -- 在线玩家数
local _server

local function __key_of(ip, port)
    local idx = port
    local n = 16
    for b in string.gmatch(ip, "%d+") do
        idx = idx + (tonumber(b) << n)
        n = n + 4
    end
    return "p" .. tostring(idx) -- player id
end

local function __del(key)
    local player = vector_[key]
    if player then
        vector_[key] = nil
        count_ = count_ - 1
        return player
    end
    return nil
end

local function __add(key, player)
    if not vector_[key] then
        vector_[key] = player
        count_ = count_ + 1
    else
        Print(key,"duplicated")
    end
end


function _M.start(m)
    _server = m
end
function _M.stop()
    _server = nil
end

function _M.count()
    return count_
end
-- 查找
function _M.find_player(ip, port)
    local key = __key_of(ip, port)
    return vector_[key]
end
-- 创建
function _M.new_player(session, ip, port)
    local key = __key_of(ip, port)
    local player = vector_[key]
    if not player then
        player = Player.new(session, ip, port, key)
        __add(key, player)
        player:init()
    end
    return player
end
-- 删除
function _M.remove_player(key)
    __del(key)
end
-- 广播
function _M.broadcast(msg)
    for _, player in pairs(vector_) do
        player:send(msg)
    end
end
-- 心跳检测
local current_count
_M._timer = CTimer.new(1000, 1000, function()
    if current_count ~= count_ then
        current_count = count_
        print("Online:", current_count)
    end
    local now_tick = os.clock()
    for key, player in pairs(vector_) do
        if player:idle_timeout(now_tick) then
            _server.on_close(player)
        end
    end
    return _server ~= nil
end)

return _M