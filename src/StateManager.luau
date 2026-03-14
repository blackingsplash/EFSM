-- PRIMITIVE TYPES
type EntityId = string | number

-- CALLBACK-ASSOCIATED TYPES
type Disconnect = () -> ()

-- FUNCTION TYPES
type State<T = unknown> = (context: Context<T>) -> ()
type Interaction<T = unknown, K = unknown> = (context: Context<T>, other_context: Context<K>) -> ()

-- TABLE TYPES
type Context<T> = {
	_entity: EntityId,
	_active: boolean,
	_data: T,
	content: { [string]: unknown },
}

type StateManagerConfig = {
	entity_id: EntityId,
	content: { [string]: unknown },
	states: { [string]: State<unknown> },
	initial: string,
}

type StateManagerInfo = {
	_runningThread: thread?,
	_availableStates: { [string]: true },
	_currentStateName: string,
	_context: Context<unknown>?,
	_ls: {},
}

type StateManager = {
	-- METAMETHOD
	__index: StateManager,

	-- NEW
	init: (ent: EntityId, content: { [string]: unknown }?) -> StateManager,

	-- INTERACTION FUNCTIONS
	registerNewInteraction: (stateA: string, stateB: string, interaction_callback: Interaction<>) -> Disconnect,

	-- MAIN FUNCTIONS
	transition: <T>(self: StateManager, state_name: string, state_callback: State<T>, new_data: T) -> (),
	update: (self: StateManager, new_data: { [string]: unknown }) -> (),
	destroy: (self: StateManager) -> (),

	-- EVENT/lISTENERS
}

local StateManager = {}
StateManager.__index = StateManager

-- VERIFICATION FUNCS
local function verifyInputStates(states: { [string]: State<> }): ()
	if type(states) ~= "table" then
		error(`{states} must of type table and not nil.`)
	end
	for k, v in states do
		if type(k) ~= "string" or type(v) ~= "function" then
			error("recorded state values must be of type function.")
		end
	end
	return states
end

--[[local function verifyInputInteractions(interactions: { [string]: Interaction }): ()
	if type(interactions) ~= "table" then
		error(`{interactions} must of type table and not nil.`)
	end
	for k, v in interactions do
		if type(k) ~= "string" or type(v) ~= "function" then
			error(`{k} must be of type string and {v} must be of type function.`)
		end
	end
	return interactions
end]]

local function verifyInitial(initial: string, states: { [string]: State<> }): ()
	if type(initial) ~= "string" or not states[initial] then
		error("initial state must be a string and recorded in states.")
	end
	return initial
end

--[=[
    @function init
    @within StateManager

    @param entity_id -- string or number for the entity this state machine is towards.
    @param content -- the context content that the states will access and modify (Health, MaxHealth, etc.)
	@return StateManager
]=]
function StateManager.init(StateConfig: StateManagerConfig): StateManager
	local self = setmetatable({}, StateManager) :: StateManagerInfo
	self._runningThread = nil
	self._availableStates = verifyInputStates(StateConfig.states)
	self._currentStateName = verifyInitial(StateConfig.initial, StateConfig.states)
	self._context = { _entity = StateConfig.entity_id, _active = false, _data = {}, _content = StateConfig.content }
	self._ls = {}

	return self
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
