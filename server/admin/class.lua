local _class = {}

--[[
	使用方式
	Derived = class(Base or nil)
	.
	.
	-- 定义构造方法
    function Derived:ctor(...)
        -- 自动调用父类的构造方法，不需要显式调用
    end

    -- 定义析构方法
    function Derived:dtor(...)
        -- 自动调用父类的析构方法，不需要显式调用
	end

	-- 定义其他方法
	function Derived:Func()
		-- 调用父类的方法 self.super.Func(self)
		self.super("Func", ...)
	end

	创建类
	local d = Derived.new(...)
	d:Func()
--]]

-- Internal register
local _class={}
 
function Class(base)
    local class_type={}
 
    class_type.__type   = 'class'
    class_type.ctor     = false
    class_type.dtor     = false
    
    local vtbl = {}
    _class[class_type] = vtbl
    setmetatable(class_type,{__newindex = vtbl, __index = vtbl})
 
    if base then
        setmetatable(vtbl,{__index=
            function(t,k)
                local ret=_class[base][k]
                vtbl[k]=ret
                return ret
            end
        })
    end
    
    class_type.__base   = base
    class_type.new      = function(...)
        --create a object, dependent on .__createFunc
        local obj= {}
        obj.__base  = class_type
        obj.__type  = 'object'
        setmetatable(obj,{ __index = _class[class_type],
        __gc = function(t) 
                local destroy
                destroy = function(c)
                    if c.dtor then
                        c.dtor(obj)
                    end
                    if c.__base then
                        destroy(c.__base)
                    end
                end
                destroy(t)
            end })

		do
            local create
            create = function(c, ...)
                if c.__base then
                    create(c.__base, ...)
                end
                if c.ctor then
                    c.ctor(obj, ...)
                end
            end
 
            create(class_type,...)
        end
 
        return obj
    end

    class_type.super = function(self, f, ...)
        assert(self and self.__type == 'object', string.format("'self' must be a object when call super(self, '%s', ...)", tostring(f)))
 
        local originBase = self.__base
        --find the first f function that differ from self[f] in the inheritance chain
        local s     = originBase
        local base  = s.__base
        while base and s[f] == base[f] do
            s = base
            base = base.__base
        end
        
        assert(base and base[f], string.format("base class or function cannot be found when call .super(self, '%s', ...)", tostring(f)))
        --now base[f] is differ from self[f], but f in base also maybe inherited from base's baseClass
        while base.__base and base[f] == base.__base[f] do
            base = base.__base
        end
 
        -- If the base also has a baseclass, temporarily set :super to call that baseClass' methods
        -- this is to avoid stack overflow
        if base.__base then
            self.__base = base
        end
 
        --now, call the super function
        local result = base[f](self, ...)
 
        --set back
        if base.__base then
            self.__base = originBase
        end
 
        return result
    end
 
    return class_type
end
