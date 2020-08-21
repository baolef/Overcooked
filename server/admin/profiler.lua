local mtime = CUtils.microsecond

function string.split(str, sep)
	local sep, fields = sep or "\t", {}
	
	local pattern = string.format("([^%s]+)", sep)
	
	string.gsub(str, pattern, function(c) fields[#fields+1] = c end)

	return fields
end


return function()
	local t = {}
	local _REPORTS_BY_TITLE = {}
	local _REPORTS = {}
	
	local function _func_title(funcinfo)
		-- check
		assert(funcinfo)

		-- the function name
		local name = funcinfo.name or '**'

		-- the function line
		local line = string.format("%d", funcinfo.linedefined or 0)

		-- the function source
		local source = funcinfo.short_src or 'C_FUNC'

		local sp = string.split(source,"/")
		if sp then
			source=sp[#sp]
		end
		local b,e = string.find(source, "return ")
		if b then
			source = "table.fromstring"
		end
		-- make title
		return string.format("%20s:%4d", source .."(".. name ..")", line)
	end

	-- get the function report
	local function _func_report(funcinfo)
		-- get the function title
		local _title = _func_title(funcinfo)
		-- get the function report
		local report = _REPORTS_BY_TITLE[_title]
		if not report then
			-- init report
			report = {	title = _title, callcount = 0, totaltime = 0	}
			-- save it
			_REPORTS_BY_TITLE[_title] = report
			table.insert(_REPORTS, report)
		end
		return report
	end

	-- profiling call
	local function _profiling_call(funcinfo)
		-- get the function report
		local report = _func_report(funcinfo)
		assert(report)
		-- save the call time
		
		report.starttime = mtime()
		-- update the call count
		report.callcount   = report.callcount + 1
	end

	-- profiling return
	local function _profiling_return(funcinfo)
		-- get the function report
		local report = _func_report(funcinfo)
		assert(report)
		-- update the total time
		if report.starttime then
			report.totaltime = report.totaltime + mtime() - report.starttime
		end
	end

	-- the profiling handler
	local function _profiling_handler(hooktype)

		-- the function info
		local funcinfo = debug.getinfo(2, 'lnS')
		-- dispatch it
		if hooktype == "call" then
			_profiling_call(funcinfo)
		elseif hooktype == "return" then
			_profiling_return(funcinfo)
		end
	end


	-- the tracing handler
	local function _tracing_handler(hooktype)
		-- the function info
		local funcinfo = debug.getinfo(2, 'lnS')
		-- is call?
		if hooktype == "call" then
			local name = funcinfo.name 
			local source = funcinfo.short_src or 'C_FUNC'
			local sp = string.split(source,"/")
			if sp then
				source=sp[#sp]
			end
			print(string.format("%-30s: %s: %s", name, source, sp[1])) -- line
		end
	end

	-- start profiling
	function t.start(mode)
		print("start")
		-- trace?
		if mode and mode == "trace" then
			debug.sethook(_tracing_handler, 'cr', 0)
		else
			-- init reports
			_REPORTS           = {}
			_REPORTS_BY_TITLE  = {}
			-- start to hook
			debug.sethook(_profiling_handler, 'cr', 0)
		end
	end


	-- stop profiling
	function t.stop(mode)
		-- trace?
		if mode and mode == "trace" then
			-- stop to hook
			debug.sethook()
		else
			-- stop to hook
			debug.sethook()
			-- calculate the total time 
			local totaltime = 0
			-- sort reports
			table.sort(_REPORTS, function(a, b)
				return a.totaltime > b.totaltime
			end)
			for _, report in ipairs(_REPORTS) do
				totaltime = totaltime + report.totaltime
			end
			print("=========== file(function) line ===========", "=== time(ns) ===", "= percent =", "= callcount =","== pertime(ns) ==")
			-- show reports
			for _, report in ipairs(_REPORTS) do
				-- calculate percent
				if report.callcount > 1 then
					local percent = (report.totaltime / totaltime) * 100
					-- trace
					print( string.format("%40s%20d %10.2f%% %10d %20.2f",report.title, report.totaltime, percent, report.callcount, report.totaltime/report.callcount ) )
				end
			end
	   end
	end

	return t
end
