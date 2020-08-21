-- 装备组件
Equips = Class()

function Equips:ctor(owner, data)
    self.m_owner = owner
    self.m_data = data
end

function Equips:init()
    for k, v in pairs(self.m_data) do
    end
end

function Equips:net_package()
    local info= {
        cmd = "get_equips",
        params = self.m_data
    }
    return JScodec.encode(info)
end
