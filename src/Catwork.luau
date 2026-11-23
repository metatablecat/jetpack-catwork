--[[
CATWORK LAUNCHER
VERSION 2.0.0

metatablecatgames 2024, 2026-

LICENSED UNDER AN APACHE 2.0 LICENSE
--]]

const BoundObjects: {[ObjectHandle<unknown>]: InitFn<unknown>} = {}
const HandleState: setmetatable<{[ObjectHandle<unknown>]: {
	captured: unknown,
	waiting: {thread}
}}, {__mode: "k"}> = setmetatable({}, {__mode = "k"})
const ObjectHandle = {}; ObjectHandle.__index = ObjectHandle

type InitFn<T> = (
	module: ModuleScript,
	sethandle: (T) -> (),
	...unknown
) -> ()

export type ObjectHandle<T> = {
	Get: (ObjectHandle<T>) -> T,
	Wait: (ObjectHandle<T>) -> T
}

const function checkReferenceHealth(packageRoot: Instance)
	for _, ref in packageRoot:QueryDescendants(">#Packages>Instance>>#References>ObjectValue") do
		if ref:GetAttribute("IgnoreReference") == true then continue end
		const val = ref.Value :: Instance

		if not val then warn(`Module reference {ref:GetFullName()} is unlinked. Check that the reference is set and is valid.`) end
	end
end

const function shallowGetModules(root: Instance)
	const modules = {}
	for _, obj in root:QueryDescendants(">Instance>#Services>Instance") do
		if obj:IsA("ModuleScript") then
			table.insert(modules, obj)
		else
			for _, shallow in obj:QueryDescendants(">ModuleScript") do
				table.insert(modules, shallow)
			end
		end
	end
	
	return modules
end

const function loadUserModule(module: ModuleScript)
	local ok, export: {[string]: any} = coroutine.resume(coroutine.create(require), module)
	if not ok then
		warn(`Module {module} experienced error while loading.`)
		return false	
	end
	
	if not export then
		warn(`{module} cannot yield on require.`)
		return false	
	end
	
	if type(export) ~= "table" or not table.isfrozen(export) then
		warn(`Module {module} appears to not be using the Luau export system`)
		return false	
	end
	
	return true, export
end

const function loadModules(modules): {[ModuleScript]: {[string]: unknown}}
	const loaded = {}
	for _, module in modules do
		const ok, export = loadUserModule(module)
		if not ok then continue end
		loaded[module] = export
	end
	return loaded
end

const function objectResolver<T>(linker: ObjectHandle<T>): (T) -> ()
	const capture = HandleState[linker]
	return function(T)
		const oldCapture = capture.captured
		capture.captured = T
		if oldCapture then return end
		
		for _, thread in capture.waiting do
			task.defer(thread, T)
		end
		capture.waiting = nil
	end
end

const function loadModuleState(
	export: unknown,
	module: ModuleScript,
	...
)
	for symbol, linker in export do
		const linkfn = BoundObjects[linker]
		if linkfn then
			BoundObjects[linker] = nil
			task.defer(linkfn, module, objectResolver(linker), ...)
		end
	end
end

export function __CATWORK_INTERNAL_INIT(
	packageRoot: Instance,
	interfaceRoot: Instance?,
	...
)
	checkReferenceHealth(packageRoot)
	if interfaceRoot then
		for _, interface in interfaceRoot:QueryDescendants(">ModuleScript") do require(interface) end
	end
	
	-- we need to load the modules first to ensure we've got handles loaded for every module
	const modules = loadModules(shallowGetModules(packageRoot))
	for module, export in modules do loadModuleState(export, module, ...) end
end

const function newObjectHandle(object)
	const handle = setmetatable({}, ObjectHandle)
	table.freeze(handle)
	
	HandleState[handle] = {
		captured = nil,
		waiting = {}
	}
	
	return handle
end

function ObjectHandle.Wait<T>(self: ObjectHandle<T>): T
	local captureInfo = HandleState[self]
	if not captureInfo.captured then
		local thread = coroutine.running()
		table.insert(captureInfo.waiting, thread)
		return coroutine.yield()
	end
	return captureInfo.captured
end

function ObjectHandle.Get<T>(self: ObjectHandle<T>): T
	return HandleState[self].captured
end

export function RegisterInterfaceBinding<U, T...>(
	fn: (T...) -> (U, InitFn<U>) -> ()
): (T...) -> ObjectHandle<U>
	return function(...)
		const object, ifn = fn(...)
		const handle = newObjectHandle(object)
		BoundObjects[handle] = ifn
		return handle
	end
end

export const Service = RegisterInterfaceBinding<<boolean>>(function(serviceFn: (...unknown) -> ())
	assert(type(serviceFn) == "function", "serviceFn must be a function")
	return nil, function(module, objectResolve, ...)
		serviceFn(...)
		objectResolve(true)
	end
end)