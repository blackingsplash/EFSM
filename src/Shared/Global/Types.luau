export type EllieContext<T> = {
	_entity: string,
	_active: boolean,
	_availableStates: { string },
	_isRegistered: boolean,
	content: { [string]: unknown },
}

export type EllieState<T> = (target: T, context: EllieContext<T>) -> ()

return {}
