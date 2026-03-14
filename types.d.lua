---@meta

---@class Program
---@field location string
---@field user string
---@field thread thread
---@field filter string?
Program = {
}

---@class APIProgram: Program
---@field pid number
---@field thread nil
APIProgram = {}

---@class KernelApi
KernelApi = {}

--- Starts a program at the given location
--- Specifying runAs requires root
---@param location string
---@param runAs string?
---@param ... string? The arguments to pass to the process
---@return number?,string?
KernelApi.RunProgram = function (location, runAs, ...) end

--- Starts a program at the given location, merging env into the program's env (on top of the basic env)
--- Specifying runAs requires root
---@param location string
---@param runAs string?
---@param env table
---@param ... string?
KernelApi.RunProgramMergeEnv = function (location, runAs, env, ...) end

--- Check if the username and password set are valid
---@param username string
---@param password string
---@return boolean Whether or not they are valid
KernelApi.TryAuthenticate = function (username, password) end

--- Creates a new user, requires root
---@param username string
---@param password string
---@return boolean, string? Whether or not the operation succeded
KernelApi.CreateUser = function (username, password) end

--- Remove a user
---@param username string
KernelApi.RemoveUser = function (username) end

---@param username string
---@param group string
KernelApi.AddGroupToUser = function (username, group) end

--- Get the API exposed by a kernel module
--- If the kernel module is loaded, but does not expose an API, true is returned instead
---@param identifier string
---@return unknown
KernelApi.GetKernelModule = function (identifier) end

---@return string
KernelApi.GetCurrentUser = function () end

--- Get the location of the home directory of the user, and creates it if it doesn't exist
---@return string The home directory of the current user
KernelApi.GetHomeDir = function () end

---@return boolean
KernelApi.IsPrivileged = function () end

---@param t table
KernelApi.SetShellApi = function (t) end

---@return APIProgram[]
KernelApi.GetProcesses = function () end

---@class User
---@field username string
---@field password string SHA256 of the users' password
---@field groups string[]
User = {}
