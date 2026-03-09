-- PRIMITIVE TYPES
type EntityId = string | number

-- CALLBACK-ASSOCIATED TYPES
type Disconnect = () -> ()

-- FUNCTION TYPES
type State<T> = (context: Context<T>) -> ()
type Interaction = (context: Context<unknown>, other_context: Context<unknown>) -> ()

-- TABLE TYPES
type Context<T> = {
	_entity: EntityId,
	_active: boolean,
	_data: T,
	content: { [string]: unknown },
}

type StateManagerInfo = {
	_runningThread: thread?,
	_currentStateName: string,
	_isRegistered: boolean,
	_availableStates: { [string]: true },
	_interactions: { [string]: true },
	_ls: {},
	_context: Context<unknown>?,
}

type StateManager = {
	-- METAMETHOD
	__index: StateManager,

	-- MAIN FUNCTIONS
	init: (ent: EntityId, content: { [string]: unknown }?) -> StateManager,
	registerStates: (states: { string }) -> (),
	recordInteraction: (
		self: StateManager,
		state_name: string,
		state_name2: string,
		special_callback: Interaction
	) -> (),
	transition: <T>(self: StateManager, state_name: string, state_callback: State<T>, new_data: T) -> (),
	update: (self: StateManager, new_data: { [string]: unknown }) -> (),
	destroy: (self: StateManager) -> (),

	-- EVENT/lISTENERS
}

local StateManager = {}
StateManager.__index = StateManager

--[=[
    @function init
    @within StateManager

    @param entity_id -- string or number for the entity this state machine is towards.
    @param content -- the context content that the states will access and modify (Health, MaxHealth, etc.)
	@return StateManager
]=]
function StateManager.init(entity_id: { EntityId }, content: { [string]: unknown }): StateManager
	local self = setmetatable({}, StateManager) :: StateManagerInfo
	self._runningThread = nil
	self._currentStateName = "nil"
	self._isRegistered = false
	self._availableStates = {}
	self._interactions = {}
	self._ls = {}

	self._context = { _entity = entity_id, _active = false, _data = {}, _content = content }
	return self
end

--[=[
    @function recordInteraction
    @within StateManager

    @return ()
]=]
function StateManager:recordInteraction(state_name: string, state_name2: string, special_callback: Interaction): ()
	if type(special_callback) ~= "function" then
		error("interaction callback must be of type function.")
	end
end

--[=[
    @function recordStates
    @within StateManager

    @param states -- array of state names to record; will be checked when transitioning for states if state exists.
	@return ()

	@note This is required for state-collision checking. This is a one-time function; you cannot record more states once done.
]=]
function StateManager:registerStates(states: { [string]: State<unknown> }): ()
	if self._isRegistered then
		return
	end
	for k, v in states do
		if type(k) ~= "function" then
			error("recorded state values must be of type function.")
		end
		self._availableStates[k] = v
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
function StateManager:transition<T>(state_name: string, target_data: T?): ()
	target_data = target_data or {}

	if not self._isRegistered then
		error("cannot transition to state before recording states.")
	end
	if not self._availableStates[state_name] then
		error("state is not recorded in finite state machine.")
	end

	local state_callback = self._availableStates[state_name] :: State<T>
	if self._runningThread then
		self._context._active = false
		pcall(task.cancel, self._runningThread)
	end

	self._currentStateName = state_name
	self._context._data = target_data
	self._context._active = true
	self._runningThread = task.spawn(state_callback, self._context)
end

--[=[
    @function update
    @within StateManager

    @param new_data -- dictionary of certain contents to modify
	@return ()
]=]
function StateManager:update(new_data: { [string]: unknown }): ()
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
