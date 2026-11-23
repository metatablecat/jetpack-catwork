--[[
                     $$\                                   $$\       
                     $$ |                                  $$ |      
      $$\  $$$$$$\ $$$$$$\    $$$$$$\   $$$$$$\   $$$$$$$\ $$ |  $$\ 
      \__|$$  __$$\\_$$  _|  $$  __$$\  \____$$\ $$  _____|$$ | $$  |
      $$\ $$$$$$$$ | $$ |    $$ /  $$ | $$$$$$$ |$$ /      $$$$$$  / 
      $$ |$$   ____| $$ |$$\ $$ |  $$ |$$  __$$ |$$ |      $$  _$$<  
      $$ |\$$$$$$$\  \$$$$  |$$$$$$$  |\$$$$$$$ |\$$$$$$$\ $$ | \$$\ 
      $$ | \_______|  \____/ $$  ____/  \_______| \_______|\__|  \__|
$$\   $$ |                   $$ |                                    
\$$$$$$  |                   $$ |                                    
 \______/                    \__|                                    
 
JETPACK PACKAGE DEPLOYER - CATWORK DEPLOYER
VERSION 1.0.0

metatablecatgames 2026

LICENSED UNDER AN APACHE 2.0 LICENSE
--]]

const ReplicatedFirst = game:GetService("ReplicatedFirst")
const ReplicatedStorage = game:GetService("ReplicatedStorage")
const ServerScriptService = game:GetService("ServerScriptService")
const JPKI = script.Parent
const Package = JPKI.Parent
const Packages = Package.Packages
const launcher = script:GetAttribute("Runtime"):Wait()
const clientBooter = script:GetAttribute("ClientLoader"):Wait()
const serverBooter = script:GetAttribute("ServerLoader"):Wait()

if Package.Parent ~= ServerScriptService then
	warn("Package is not parented to ServerScriptService. This may cause issues with code security.")
end

type PackageContext = {
	Name: string,
	Instance: Instance,
	Context: "SharedFirst" | "Shared" | "Server",
	
	ConsumerCounters: {
		SharedFirst: number,
		Shared: number,
		Server: number,
	},
	
	ContainsServices: false,
	References: {[ObjectValue]: PackageContext}
}

const contexts: {[Instance]: PackageContext} = {}

const function makeContext(folder: Instance, forceContext: string?)
	return {
		Name = folder.Parent.Name,
		Instance = folder,
		Context = forceContext or folder.Name,
		ConsumerCounters = {
			SharedFirst = 0,
			Shared = 0,
			Server = 0,
		},
		ContainsServices = folder:FindFirstChild("Services") ~= nil,
		References = {}
	}
end

for _, contextFolder in Packages:QueryDescendants(">Instance>#Server, >Instance>#Shared, >Instance>#SharedFirst") do
	contexts[contextFolder] = makeContext(contextFolder)
end

const function findContext(obj): PackageContext?
	local la1, la2

	while true do
		la1 = obj and obj.Parent
		la2 = la1 and la1.Parent
		if not (obj or la1 or la2) then return nil end
		if la2 == Packages then return contexts[obj] end
		obj = obj.Parent
	end
end

const function INVALID_SERVERCLIENT_LINK(ref: PackageContext, context: PackageContext, ov: ObjectValue)
	warn(`Reference {ov:GetFullName()} is trying to link {context.Context} package {context.Name} to Server package {ref.Name}, which would be inaccessible to client code.`)
end

for folder, context in contexts do
	for _, refov in context.Instance:QueryDescendants(">#References>ObjectValue") do
		const refi = refov.Value
		if not refi then continue end
		if refi == launcher then continue end
		
		const refcontext = findContext(refi)
		if not refcontext then continue end
		
		if refcontext.Context == "Server" and context.Context ~= "Server" then
			INVALID_SERVERCLIENT_LINK(refcontext, context, refov)
			continue
		end
		
		context.References[refov] = refcontext
		refcontext.ConsumerCounters[context.Context] += 1
	end
end

-- now, we can build the destination folders for contexts based on their consumer counters
const serverStoragePackages = {}
const replicatedStoragePackages = {}
const replicatedFirstPackages = {}

for _, context in contexts do
	if context.Context == "Server" then
		-- can only be linked to by other server obejects
		assert(context.ConsumerCounters.SharedFirst == 0, "Server packages cannot have SharedFirst consumers")
		assert(context.ConsumerCounters.Shared == 0, "Server packages cannot have Shared consumers")
		
		table.insert(serverStoragePackages, context)
	else
		if context.ConsumerCounters.SharedFirst > 0 then
			table.insert(replicatedFirstPackages, context)
		else
			table.insert(if context.Context == "SharedFirst" then replicatedFirstPackages else replicatedStoragePackages, context)
		end
	end
end

const function installContexts(parent, contexts: {PackageContext}, useScript)
	const folder = Instance.new("Folder")
	folder.Name = `JETPACK_{parent.Name}`
	
	const packages = Instance.new("Folder")
	packages.Name = "Packages"
	
	for _, context in contexts do
		const i = context.Instance
		i.Name = context.Name
		i.Parent = packages
	end
	
	packages.Parent = folder
	
	const scrip = useScript:Clone()
	scrip.Parent = folder
	scrip.Enabled = true
	
	folder.Parent = parent
end

const InterfaceFolder = Package:FindFirstChild("Interfaces")
if InterfaceFolder then
	InterfaceFolder.Name = "CATWORK_Interfaces"
	InterfaceFolder.Parent = ReplicatedFirst
end
launcher.Parent = ReplicatedFirst
installContexts(ServerScriptService, serverStoragePackages, serverBooter)
installContexts(ReplicatedStorage, replicatedStoragePackages, clientBooter)
installContexts(ReplicatedFirst, replicatedFirstPackages, clientBooter)
Package:Destroy()