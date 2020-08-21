CTimer = {}
require("admin.class")
require("admin.util")
require("admin.cocontext")
require("luatimer")
JScodec = require("cjson")
JScodec.encode_sparse_array(true)

require("scene")
require("player")
require("components.equips")
require("components.money")

PlayerManager = require("player_manager")
UdpServer = require("server")

function OnStart()
    UdpServer.start(9090)
    PlayerManager.start(UdpServer)
    -- Player.UnitTest()
end

function OnStop()
    UdpServer.close()
    PlayerManager.stop()
    CTimer.stop()
end
