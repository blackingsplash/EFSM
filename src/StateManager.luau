type EntityId = string | number

type Context<T> = {
	_entity: EntityId,
	_active: boolean,
	_data: T,
	content: { [string]: unknown },
}

type State<T> = (context: Context<T>) -> ()
type Disconnect = () -> ()

type StateManagerInfo = {
	_runningThread: thread?,
	_currentStateName: string,
	_availableStates: { [string]: true },
	_ls: {},
	_isRegistered: boolean,
	_context: Context<unknown>?,
}

type StateManager = {
	init: (ent: EntityId, content: { [string]: unknown }?) -> StateManager,
	recordStates: (states: { string }) -> (),
	transition: <T>(self: StateManager, state_name: string, state_callback: State<T>, new_data: T) -> (),
	onStateCollision: (
		self: StateManager,
		callback: (target: EntityId, c1: Context<unknown>, c2: Context<unknown>) -> ()
	) -> Disconnect,
	destroy: (self: StateManager) -> (),
}

local StateRegistry: { [string]: string } = {}
local StateManager = {}
StateManager.__index = StateManager

--[=[
    @function init
    @within StateManager

    @param entity_id -- string or number for the entity this state machine is towards.
    @param content -- the context content that the states will access and modify (Health, MaxHealth, etc.)
	@return StateManager
]=]
function StateManager.init(entity_id: EntityId, content: { [string]: unknown }): StateManager
	local self = setmetatable({}, StateManager) :: StateManagerInfo
	self._runningThread = nil
	self._currentStateName = "nil"
	self._availableStates = {}
	self._ls = {}
	self._isRegistered = false

	self._context = { _entity = entity_id, _active = false, _content = content, _data = {}, _manager = self }

	StateRegistry[entity_id] = self
	return self
end

--[=[
    @function recordStates
    @within StateManager

    @param states -- array of state names to record; will be checked when transitioning for states if state exists.
	@return ()
]=]
function StateManager:recordStates(states: { string }): ()
	if self._isRegistered then
		return
	end
	if #states < 1 then
		error("states array must have at least one element.")
	end
	for _, v in states do
		self._availableStates[v] = true
	end
	self._isRegistered = true
end

--[=[
    @function transition
    @within StateManager

    @param state_name -- target state_name to change to
    @param state_callback -- basically the function that the state will run to modify. takes in a target_data and a context parameters.
	@param target_data? -- main data to modify (Position, Rotation, etc.), could be nil.
	@return ()
]=]
function StateManager:transition<T>(state_name: string, state_callback: State<T>, target_data: T?): ()
	target_data = target_data or {}

	if self._isRegistered and not self._availableStates then
		error("state is not recorded in finite state machine.")
	end
	if self._runningThread then
		self._context._active = false
		task.cancel(self._runningThread)
	end

	self._currentStateName = state_name
	self._context._data = target_data
	self._context._active = true
	self._runningThread = task.spawn(state_callback, self._context)

	StateRegistry[self._context._entity] = state_name
end

--[=[
    @function update
    @within StateManager

    @param new_data -- table of certain contents to modify
	@return ()
]=]
function StateManager:update<T>(new_data: T): ()
	if not self._context._active then
		error("cannot update new_data")
	end
	for k, v in new_data do
		self._context._data[k] = v
	end
end

--[=[
    @function destroy
    @within StateManager

	@return ()
]=]
function StateManager:destroy(): ()
	if self._runningThread then
		task.cancel(self._runningThread)
	end
	self._runningThread = nil
	self._currentStateName = nil
	self._context = nil
end

return StateManager :: StateManager
