---@type KernelApi
local apollon = APOLLON_API

local args = ...

if not args then
  print("Usage: sudo <command>")
  return
end

local sudoModule = apollon.GetKernelModule("apollon.sudo")
local authFor = apollon.GetCurrentUser()

if authFor == "root" then
  print("You are already the superuser")
  return
end

if not sudoModule.UserCanUse(authFor) then
  authFor = "root"
end

write("Password for "..authFor..": ")
local password = read("*")

local res = sudoModule.Execute(authFor, password, ...)

if not res then
  print("Authentication failed")
  return
end

local pid

repeat
  _, pid = os.pullEventRaw("APOLLON_PROCESS_EXIT")
until pid == res
