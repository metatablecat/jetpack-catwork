-- This script builds to the Roblox XML format such that we can quickly
-- assemble a deployable package

const fs = require("@lute/fs")

const DEFAULT_SERVICE = [[const Catwork = require(script.Parent.Parent.References.Catwork.Value)

export const Service = Catwork.Service(function()
	print("Hello Catwork!")
end)
]]

const function readAllBytes(path: string): string
	const handle = fs.open(path, "r")
	const content = fs.read(handle)
	fs.close(handle)
	return content
end
const pkg = readAllBytes("builder/package.rbxmx")

const function submatches(src: string, matches: {[string]: string})
	for match, replace in matches do
		src = string.gsub(src, `\{{match}}`, replace)
	end

	return src
end

const function buildLoader(isClient: boolean)
	const lines = {"const ReplicatedFirst = game:GetService(\"ReplicatedFirst\")"}
	if isClient then
		table.insert(lines, "const Players = game:GetService(\"Players\")")
		table.insert(lines, "require(ReplicatedFirst.Catwork).__CATWORK_INTERNAL_INIT(script.Parent.Packages, ReplicatedFirst:FindFirstChild(\"CATWORK_Interfaces\"), Players.LocalPlayer)")
	else
		table.insert(lines, "require(ReplicatedFirst.Catwork).__CATWORK_INTERNAL_INIT(script.Parent.Packages, ReplicatedFirst:FindFirstChild(\"CATWORK_Interfaces\"))")
	end

	return table.concat(lines, "\n")
end

const matches = {
	launcherSrc = readAllBytes("src/jetpack.luau"),
	runtime = readAllBytes("src/Catwork.luau"),
	serverLoader = buildLoader(false),
	clientLoader = buildLoader(true),
	defaultservice = DEFAULT_SERVICE
}
const file = fs.open("Catwork.rbxmx", "w")
fs.write(file, submatches(pkg, matches))
fs.close(file)