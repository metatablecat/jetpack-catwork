This documentation contains usage of both Jetpack and CatworkRedux.

# Jetpack

Jetpack is a packaging provider, it is simple, and the deploy logic is
hardcoded.

A Jetpack package follows this structure:

```
Jetpack
  .jpki
    [Internal Jetpack Items]
  Packages
    [PackageName]
      Shared - ReplicatedStorage
      SharedFirst - ReplicatedFirst
      Server - ServerScriptService
  Interfaces
    Catwork ObjectValue reference
    [Catwork Interfaces]
```

Each context in a Package can contain a Services folder, which Catwork will load
and link up interfaces to.

Server installs in ServerScriptService, and runs on the server, while
SharedFirst installs to ReplicatedFirst, and Shared replicates to
ReplicatedStorage, both of which will have services running on the client.

The exact way the package is generated is not relevent here, as you should be
creating references with ObjectValues.

# CatworkRedux

Catwork loads modules and uses interface bindings to create hookable objects
inside a service module.

A generic Service module will usually look like this:

```luau
const Jetpack = require(path.to.jetpackreference)

export const Service = Jetpack.Service(function()
  print("Hello World!")
end)
```

> Services must use the Luau export syntax, this is because several assumptions have been made that the module is using this syntax.

Each interface binding returns an `ObjectHandle`, which can be used to provide
objects out of the interface that can be used by other hooks and parts of your
code. Due to the loading order being undefined, these can be waited upon with
`ObjectHandle:Wait()`, which yields the running thread until a value is
available. Interfaces run asynchronously.

## Interfaces

Interfaces act as hookable logic that can be run against when a Service is loaded. This allows you to define more logic declaratively at the top-level rather than using `Catwork.Service`.

Here is the definition for Catwork's Service interface

```luau
export const Service = RegisterInterfaceBinding<<boolean>>(function(serviceFn: (...unknown) -> ())
	assert(type(serviceFn) == "function", "serviceFn must be a function")
	return nil, function(module, objectResolve, ...)
		serviceFn(...)
		objectResolve(true)
	end
end)
```

There are a few things to point out here
* `<<boolean>>`
  * This is a turbofish, used to force the object handle to be of type `boolean`, you dont need to define this, but Luau typing might not infer what you want otherwise.
* `return function(...)`
  * This your function that runs when hooking the object to the handle. This is assumed to be runtime code, when needed, you then call `objectResolve` to push the value to the `ObjectHandle`.

Interfaces are loaded if they are placed into the `Interfaces` folder in the Jetpack package.