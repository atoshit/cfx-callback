local IS_SERVER <const> = IsDuplicityVersion()
local TABLE_UNPACK <const> = table.unpack
local DEBUG <const> = debug
local DEBUG_GETINFO <const> = DEBUG.getinfo
local MSGPACK <const> = msgpack
local MSGPACK_PACK <const> = MSGPACK.pack
local MSGPACK_UNPACK <const> = MSGPACK.unpack
local MSGPACK_PACK_ARGS <const> = MSGPACK.pack_args
local AWAIT <const> = Citizen.Await
local PENDING <const> = 0
local RESOLVING <const> = 1
local REJECTING <const> = 2
local RESOLVED <const> = 3
local REJECTED <const> = 4

---@param obj any
---@param typeof string
---@param opt_typeof string?
---@param errMessage string?
local function ensure(obj, typeof, opt_typeof, errMessage)
	local objtype = type(obj)
	local di = DEBUG_GETINFO(2)
	local errMessage = errMessage or (opt_typeof == nil and (di.name .. ' expected %s, but got %s') or (di.name .. ' expected %s or %s, but got %s'))
	if typeof ~= 'function' then
		if objtype ~= typeof and objtype ~= opt_typeof then
			error((errMessage):format(typeof, (opt_typeof == nil and objtype or opt_typeof), objtype))
		end
	else
		if objtype == 'table' and not rawget(obj, '__cfx_functionReference') then
			error((errMessage):format(typeof, (opt_typeof == nil and objtype or opt_typeof), objtype))
		end
	end
end

local PREFIX <const> = 'cfx_admin_callback'

if IS_SERVER then
    local callbacks = {}
    
    ---@param args table
    ---@param args.eventName string
    ---@param args.eventCallback function
	local function registerServerCallback(args)
		ensure(args, 'table'); ensure(args.eventName, 'string'); ensure(args.eventCallback, 'function')
		
		local eventName = args.eventName
		local eventCallback = args.eventCallback
		
		callbacks[eventName] = eventCallback
		
		if not callbacks.__initialized then
			RegisterNetEvent(PREFIX..':server:request', function(name, requestId, source, data)
				local cb = callbacks[name]
				if cb then
					local result = {cb(source, table.unpack(data or {}))}
					TriggerClientEvent(PREFIX..':client:response', source, requestId, result)
				end
			end)
			callbacks.__initialized = true
		end
		
		return eventName
	end

    _ENV.registerServerCallback = registerServerCallback

	local function unregisterServerCallback(eventName)
		callbacks[eventName] = nil
	end

    _ENV.unregisterServerCallback = unregisterServerCallback

    ---@param args table
    ---@param args.source number|string
    ---@param args.eventName string
    ---@param args.args table?
    ---@param args.timeout number?
    ---@param args.timedout function?
    ---@param args.callback function?
	local function triggerClientCallback(args)
		ensure(args, 'table'); ensure(args.source, 'string', 'number'); ensure(args.eventName, 'string'); ensure(args.args, 'table', 'nil'); ensure(args.timeout, 'number', 'nil'); ensure(args.timedout, 'function', 'nil'); ensure(args.callback, 'function', 'nil')

		local source = tonumber(args.source)
		if not source or source < 0 then
			error('source doit être égal ou supérieur à 0')
			return
		end

		local requestId = PREFIX .. ':' .. args.eventName .. ':' .. os.time() .. ':' .. math.random(100000, 999999)
		local prom = promise.new()
		local eventCallback = args.callback
		
		local eventHandler
		eventHandler = RegisterNetEvent(PREFIX..':server:response', function(id, data, src)
			if src ~= source or id ~= requestId then return end
			
			if eventCallback and prom.state == PENDING then 
				eventCallback(table.unpack(data or {})) 
			end
			
			prom:resolve(table.unpack(data or {}))
			RemoveEventHandler(eventHandler)
		end)

		TriggerClientEvent(PREFIX..':client:request', source, args.eventName, requestId, args.args or {})

		if args.timeout and args.timeout > 0 then
			SetTimeout(args.timeout * 1000, function()
				if prom.state == PENDING then
					if args.timedout then args.timedout() end
					prom:reject('timeout')
					RemoveEventHandler(eventHandler)
				end
			end)
		end

		if not eventCallback then
			local result = AWAIT(prom)
			return result
		end
	end

    _ENV.triggerClientCallback = triggerClientCallback

    ---@param args table
    ---@param args.eventName string
    ---@param args.args table?
    ---@param args.timeout number?
    ---@param args.timedout function?
    ---@param args.callback function?
	local function triggerServerCallback(args)
		ensure(args, 'table'); ensure(args.eventName, 'string'); ensure(args.args, 'table', 'nil'); ensure(args.timeout, 'number', 'nil'); ensure(args.timedout, 'function', 'nil'); ensure(args.callback, 'function', 'nil')

		local cb = callbacks[args.eventName]
		if not cb then
			error('Callback serveur non enregistré: ' .. args.eventName)
			return
		end
		
		local prom = promise.new()
		local result = {cb(args.source or -1, table.unpack(args.args or {}))}
		
		if args.callback then
			args.callback(table.unpack(result))
		else
			prom:resolve(table.unpack(result))
			return AWAIT(prom)
		end
	end

    _ENV.triggerServerCallback = triggerServerCallback
end

if not IS_SERVER then
	local SERVER_ID = GetPlayerServerId(PlayerId())
	local callbacks = {}
	local requestsAwaitingResponse = {}

    ---@param args table
    ---@param args.eventName string
    ---@param args.eventCallback function
	local function registerClientCallback(args)
		ensure(args, 'table'); ensure(args.eventName, 'string'); ensure(args.eventCallback, 'function')
		
		local eventName = args.eventName
		local eventCallback = args.eventCallback
		
		callbacks[eventName] = eventCallback
		
		if not callbacks.__initialized then
			RegisterNetEvent(PREFIX..':client:request', function(name, requestId, data)
				local cb = callbacks[name]
				if cb then
					local result = {cb(table.unpack(data or {}))}
					TriggerServerEvent(PREFIX..':server:response', requestId, result, SERVER_ID)
				end
			end)
			callbacks.__initialized = true
		end
		
		return eventName
	end

    _ENV.registerClientCallback = registerClientCallback

	local function unregisterClientCallback(eventName)
		callbacks[eventName] = nil
	end

    _ENV.unregisterClientCallback = unregisterClientCallback

    ---@param args table
    ---@param args.eventName string
    ---@param args.args table?
    ---@param args.timeout number?
    ---@param args.timedout function?
    ---@param args.callback function?
	local function triggerServerCallback(args)
		ensure(args, 'table'); ensure(args.eventName, 'string'); ensure(args.args, 'table', 'nil'); ensure(args.timeout, 'number', 'nil'); ensure(args.timedout, 'function', 'nil'); ensure(args.callback, 'function', 'nil')
		
		local requestId = PREFIX .. ':' .. args.eventName .. ':' .. GetGameTimer() .. ':' .. math.random(100000, 999999)
		local prom = promise.new()
		local eventCallback = args.callback
		
		if not requestsAwaitingResponse.__initialized then
			RegisterNetEvent(PREFIX..':client:response', function(id, data)
				local request = requestsAwaitingResponse[id]
				if not request then return end
				
				if request.callback and request.promise.state == PENDING then 
					request.callback(table.unpack(data or {})) 
				end
				
				request.promise:resolve(table.unpack(data or {}))
				requestsAwaitingResponse[id] = nil
			end)
			requestsAwaitingResponse.__initialized = true
		end
		
		requestsAwaitingResponse[requestId] = {
			promise = prom,
			callback = eventCallback,
			time = GetGameTimer()
		}

		TriggerServerEvent(PREFIX..':server:request', args.eventName, requestId, SERVER_ID, args.args or {})

		if args.timeout and args.timeout > 0 then
			SetTimeout(args.timeout * 1000, function()
				local request = requestsAwaitingResponse[requestId]
				if request and request.promise.state == PENDING then
					if args.timedout then args.timedout() end
					request.promise:reject('timeout')
					requestsAwaitingResponse[requestId] = nil
				end
			end)
		end

		if not eventCallback then
			local result = AWAIT(prom)
			return result
		end
	end

    _ENV.triggerServerCallback = triggerServerCallback

    ---@param args table
    ---@param args.eventName string
    ---@param args.args table?
    ---@param args.timeout number?
    ---@param args.timedout function?
    ---@param args.callback function?
	local function triggerClientCallback(args)
		ensure(args, 'table'); ensure(args.eventName, 'string'); ensure(args.args, 'table', 'nil'); ensure(args.timeout, 'number', 'nil'); ensure(args.timedout, 'function', 'nil'); ensure(args.callback, 'function', 'nil')

		local cb = callbacks[args.eventName]
		if not cb then
			error('Callback client non enregistré: ' .. args.eventName)
			return
		end
		
		local prom = promise.new()
		local result = {cb(table.unpack(args.args or {}))}
		
		if args.callback then
			args.callback(table.unpack(result))
		else
			prom:resolve(table.unpack(result))
			return AWAIT(prom)
		end
	end

    _ENV.triggerClientCallback = triggerClientCallback
	
	CreateThread(function()
		while true do
			Wait(30000) 
			local currentTime = GetGameTimer()
			for id, request in pairs(requestsAwaitingResponse) do
				if id ~= "__initialized" and currentTime - request.time > 60000 then 
					if request.promise.state == PENDING then
						request.promise:reject('timeout')
					end
					requestsAwaitingResponse[id] = nil
				end
			end
		end
	end)
end
