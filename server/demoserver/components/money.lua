Money = Class()
--- Class common value ----
Money.Type = {
    Unknown = 0,
    Silver = 1,
    Gold = 2,
}
-- auto reverse defined ---
Money.TypeName = {}
for name, idx in pairs(Money.Type) do
    Money.TypeName[idx] = name
end
-- const of the class --
Money.MAX = 100 * 1000
Money.MIN = 0
-- ------------ Money Class ---------- --
function Money:ctor(owner, data)
    self.m_owner = owner
    self.m_data = data
end
-- init and load the data
function Money:init()
    local value = self.m_data[Money.Type.Gold] or Money.MIN
    self:set(Money.Type.Gold, value, "init")

    value = self.m_data[Money.Type.Silver] or Money.MIN
    self:set(Money.Type.Silver, value, "init")
end
-- =
function Money:set(moneyType, value, reason)
    if not reason then
        G_logger:error(string.format("set Money.%s reason is nil",Money.TypeName[moneyType]))
        return false
    end

    if value >=  Money.MIN and value <= Money.MAX then
        self.m_data[moneyType] = value

        local str = string.format("%q Money.%s = %d, reason is %q",
            self.m_owner:role_name() or "[System]",
            Money.TypeName[moneyType],
            value,
            reason
        )
        G_logger:info(str)
        return true
    end
    return false
end
-- +
function Money:add(moneyType, value, reason)
    if not reason then
        G_logger:error(string.format("add Money.%s reason is nil",Money.TypeName[moneyType]))
        return false
    end

    if value > 0 then
        local old = self.m_data[moneyType]
        local total = old + value
        self.m_data[moneyType] = (total > Money.MAX) and Money.MAX or total  -- 三目运算

        local str = string.format("%q Money.%s +%d, current %d, reason is %q",
            self.m_owner:role_name() or "[System]",
            Money.TypeName[moneyType],
            value,
            self:value(moneyType),
            reason
        )
        G_logger:info(str)
        return true
    end
    return false
end
-- - 
function Money:consume(moneyType, value, reason)
    if not reason then
        G_logger:error(string.format("consume Money.%s reason is nil",Money.TypeName[moneyType]))
        return false
    end

    if value > 0 then
        local old = self.m_data[moneyType]
        local total = old - value
        self.m_data[moneyType] = (total < Money.MIN) and Money.MIN or total -- 三目运算

        G_logger:info(string.format("%q Money.%s -%d, current %d  reason is %q",
            self.m_owner:role_name() or "[System]",
            Money.TypeName[moneyType],
            value,
            self:value(moneyType),
            reason)
        )
        return true
    end
    return false
end
-- judge
function Money:is_enought(moneyType, value)
    local current = self.m_data[moneyType]
    if current then
        return current >= value
    end
    return false
end

function Money:value(moneyType)
    return self.m_data[moneyType]
end

function Money:net_package()
    local info= {
        cmd = "get_moneys",
        params = self.m_data
    }
    return JScodec.encode(info)
end