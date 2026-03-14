---@type KernelApi
local apollon = APOLLON_API

local processes = apollon.GetProcesses()

print(string.format("%-6s %-8s %-20s", "PID", "USER", "PROGRAM"))

for _,v in ipairs(processes) do
  print(string.format("%-6d %-8s %-20s", v.pid, v.user, v.location))
end
