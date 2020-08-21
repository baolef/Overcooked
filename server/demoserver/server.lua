
local _M = {}
local _UdpServer

local function __safe_execute(session, ip, port, msg)
    local player = PlayerManager.find_player(ip, port)

    if not player then
        player = PlayerManager.new_player(session, ip, port)
        _M.on_connect(player)                   -- 新用户
    end

    if msg == "--->Ping" then
        session:send(ip, port, "<---Pong")      -- 心跳
        player:online()
    elseif msg == "--->Close" or msg == "" then              -- 主动关闭
        _M.on_close(player)
    else
        -- player:receive(msg)
        _M.on_message(player, msg)              -- 接收信息
    end
end

local function __udp_recv(session, ip, port, msg)
    local succ, err = Try(__safe_execute, session, ip, port, msg) -- 安全地执行
    if not succ then
        Print("process client message error\n", err)
    end
end

function _M.on_connect(player)
    Print(player:get_idx(), player:remote_address(), "connected")
end

function _M.on_close(player)
    Print(player:get_idx(), player:remote_address(), "close")
    PlayerManager.remove_player(player:get_idx())
    player:close()
end

function _M.on_message(player, msg)
    player:receive(msg)
end

function _M.close()
    if _UdpServer then
        _UdpServer:close()
        _UdpServer = nil
    end
    PlayerManager.stop()
end

function _M.start(listen_port)
    _UdpServer = CNet.UdpSocket.new(listen_port, __udp_recv)
end


return _M