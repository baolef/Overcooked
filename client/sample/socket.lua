local love = love or {}

local socket = require("socket")
------- paramsters --------
local params = {...}
local sendChan = love.thread.getChannel(params[1])
local recvChan = love.thread.getChannel(params[2])
local address = params[3]
local port= params[4]
------- udp ------
local udp = socket.udp()
udp:settimeout(0.01)
udp:setpeername(address, port)
local running = true

print("Local UDP address:", udp:getsockname())
local n = 1
while running do
    if n > 1000 then
        udp:send("--->Ping")
        -- udp:send("--->Close")
        n = 0
    end
    n = n + 1
    -- receive from remote
    local data, err = udp:receive()

    if data then
        if data ~= "<---Pong" then
            recvChan:push(data)
        end
    elseif err ~= 'timeout' then
        error("Unknown network error: "..tostring(err))
    end
    -- send data to remote
    while true do
        local pkg = sendChan:pop()
        if pkg then
            udp:send(pkg)
        else
            break
        end
    end
end
