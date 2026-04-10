-- CALLBACK-ASSOCIATED TYPES
type Disconnect = () -> ()
type OnTransitionListener = (v: Context<unknown>) -> ()

-- FUNCTION TYPES
type State<T = unknown> = (contextData: T) -> ()

-- TABLE TYPES
type Context<T> = {
	data: T,
	_active: boolean,
}

type StateManagerConfig<T> = {
	states: { [string]: State<T> },
	initialState: string,
	initialData: { T },
}

type StateManagerInfo = {
	_runningThread: thread?,
	_availableStates: { [string]: true },
	_currentStateName: string,
	_context: Context<unknown>?,
	_on_trans_ls: { OnTransitionListener },
}

type StateManager = StateManagerInfo & {
	-- METAMETHOD
	__index: StateManager,

	-- CONSTRUCTOR
	init: (StateManagerConfig: StateManagerConfig<unknown>) -> StateManager,

	-- MAIN FUNCTIONS
	transition: <T>(self: StateManager, state_name: string) -> (),
	update: (self: StateManager, new_data: { [string]: unknown }) -> (),
	destroy: (self: StateManager) -> (),

	-- EVENT/lISTENERS
	onTransition: <T>(self: StateManager, callback: (new_state_context: Context<T>) -> ()) -> Disconnect,
}

local StateManager = {}
StateManager.__index = StateManager

-- LISTENER FUNCS
local function FireListener(listeners: { OnTransitionListener }, context: Context<unknown>): ()
	for i = 1, #listeners do
		listeners[i](context)
	end
end

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

local function verifyInitial(initial: string, states: { [string]: State<> }): ()
	if type(initial) ~= "string" or not states[initial] then
		error("initial state must be a string and recorded in states.")
	end
	return initial
end

--[=[
    @function init
    @within StateManager

    @param StateManagerConfig -- a dictionary that contains the necessary information to initialize the StateManager, including states, initialState, and initialData.
	@return StateManager
]=]
function StateManager.init(StateConfig: StateManagerConfig<unknown>): StateManager
	local self = setmetatable({}, StateManager) :: StateManagerInfo
	self._runningThread = nil
	self._availableStates = verifyInputStates(StateConfig.states)
	self._currentStateName = verifyInitial(StateConfig.initialState, StateConfig.states)
	self._context = {
		data = StateConfig.initialData or {},
		_active = true,
	}

	self._on_trans_ls = {}
	return self
end

--[=[
    @function transition
    @within StateManager

    @param state_name -- target state_name to change to
	@param target_data? -- main data to modify (Position, Rotation, etc.), could be nil.
	@return ()
]=]
function StateManager:transition<T>(state_name: string): ()
	if not self._context._active then
		error("cannot transition to new state: concurrency control.")
	end

	if not self._availableStates[state_name] then
		error(`target state ({state_name}) is not recorded in finite state machine.`)
	end

	if self._runningThread then
		self._context._active = true
		task.cancel(self._runningThread)
	end

	local state_callback = self._availableStates[state_name] :: State<T>
	self._currentStateName = state_name
	self._context._active = true
	self._runningThread = task.spawn(state_callback, self._context.data)

	FireListener(self._on_trans_ls, self._context)
end

--[=[
    @function update
    @within StateManager

    @param new_data -- dictionary of certain contents to modify
	@return ()

	@note this function adds new data, if the inputted data is already existent, it will overwrite it.
]=]
function StateManager:update(new_data: { [string]: unknown }): ()
	if not self._context._active then
		error("cannot update new_data: concurrency control.")
	end
	for k, v in new_data do
		self._context.data[k] = v
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

--[=[
    @function onTransition
    @within StateManager

	@param callback -- callback function that runs when a transition to a new state happens. takes in the new_state_context as a parameter.

	@return ()
]=]
function StateManager:onTransition<T>(fn: (new_state_context: Context<T>) -> ()): Disconnect
	local ls: { OnTransitionListener } = self._on_trans_ls
	ls[#ls + 1] = fn
	local running: boolean = true
	return function()
		if not running then
			return
		end
		running = false
		for i = #ls, 1, -1 do
			if ls[i] == fn then
				ls[i] = ls[#ls]
				ls[#ls] = nil
				break
			end
		end
	end
end

return StateManager :: StateManager
