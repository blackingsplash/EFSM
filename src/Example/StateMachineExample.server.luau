local StateMachine = require("./StateMachine")
local EFSM = StateMachine.init({
	states = {
		foo = function(data)
			print(data)
		end,
		bar = function(data)
			data.hi -= 10
			print(data)
		end,
	},
	initialState = "foo",
	initialData = { hi = 50 },
})

EFSM:transition("bar")
EFSM:update({ hi = 100, new = 200 })
