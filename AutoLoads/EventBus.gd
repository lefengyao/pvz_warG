
extends Node



var _listeners: Dictionary = {}





func listen(event_name: String, callback: Callable) -> void :
	if not _listeners.has(event_name):
		_listeners[event_name] = []

	for item in _listeners[event_name]:
		if item[0] == callback:
			return
	_listeners[event_name].append([callback, 0])



func unlisten(event_name: String, callback: Callable) -> void :
	if not _listeners.has(event_name):
		return
	var arr = _listeners[event_name]
	for i in range(arr.size() - 1, -1, -1):
		if arr[i][0] == callback:
			arr.remove_at(i)
	if arr.is_empty():
		_listeners.erase(event_name)





func emit(event_name: String, args = null) -> void :
	if not _listeners.has(event_name):
		return

	var listeners = _listeners[event_name].duplicate()
	for item in listeners:
		var callback: Callable = item[0]
		if args == null:
			callback.call()
		else:

			if typeof(args) != TYPE_ARRAY:
				callback.call(args)
			else:
				callback.callv(args)



func clear() -> void :
	_listeners.clear()
