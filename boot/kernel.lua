local sha256 = require("/lib/sha256")

---@class Kernel
---@field programs (Program|false)[]
---@field baseEnv table
---@field nonRootEnvOverwrites table
local kernel = {
  programs = {},
  baseEnv = {},
  kernelModules = {}
}

local function createApi(user, programId)
  local function isPrivileged()
    return user == "root"
  end

  return {
    RunProgram = function (location, runAs, ...)
      if runAs and (not isPrivileged()) then
        return false, "ACCESS_DENIED"
      end

      if not runAs then
        runAs = user
      end

      return kernel.AddProgram(location, runAs, table.pack(...))
    end,
    RunProgramMergeEnv = function (location, runAs, env, ...)
      if runAs and (not isPrivileged()) then
        return false, "ACCESS_DENIED"
      end

      if not runAs then
        runAs = user
      end

      return kernel.AddProgram(location, runAs, table.pack(...), env, "merge")
    end,
    TryAuthenticate = function (username, password)
      return kernel.TryAuthenticate(username, password)
    end,
    CreateUser = function (username, password)
      if not isPrivileged() then
        return false, "ACCESS_DENIED"
      end

      return kernel.AddUser(username, password)
    end,
    GetUser = function (username)
      if not isPrivileged() then
        return false, "ACCESS_DENIED"
      end

      return kernel.GetUser(username)
    end,
    RemoveUser = function (username)
      if not isPrivileged() then
        return false, "ACCESS_DENIED"
      end

      return kernel.RemoveUser(username)
    end,
    AddGroupToUser = function (username, group)
      if not isPrivileged() then
        return false, "ACCESS_DENIED"
      end

      local users, err = kernel.GetUsers()

      if not users then
        return false, err
      end

      if not users[username] then
        return false, "User does not exist"
      end

      local user2 = users[username]

      table.insert(user2.groups, group)

      users[username] = user2

      return kernel.WriteUsers(users)
    end,
    IsPrivileged = function ()
      return isPrivileged()
    end,
    GetKernelModule = function (identifier)
      return kernel.kernelModules[identifier]
    end,
    GetCurrentUser = function ()
      return user
    end,
    GetHomeDir = function ()
      local path = "/home/"..user

      if not fs.exists(path) then
        fs.makeDir(path)
      end

      return path
    end,
    GetProcesses = function ()
      local processes = {}

      for i,v in ipairs(kernel.programs) do
        if v then
          local new = {
            location = v.location,
            user = v.user,
            pid = i
          }

          table.insert(processes, new)
        end
      end
      
      return processes
    end
  }
end

local function printInColor(text, color)
  local old = term.getTextColor()
  term.setTextColor(colors[color])
  print(text)
  term.setTextColor(old)
end

---@return nil
function kernel.Start()
  -- Load kernel modules
  ---@type string[]
  local modules = fs.list("/boot/modules")

  for _,v in ipairs(modules) do
    local module = dofile(fs.combine("/boot/modules", v))
    local identifier = module.GetIdentifier()
    local api = module.Load(kernel)
    kernel.kernelModules[identifier] = api
  end

  kernel.AddProgram("/boot/init.lua", "root")

  -- Main loop
  local event = { n = 0 }

  while true do
    for i, program in ipairs(kernel.programs) do
      if program and (program.filter == nil or program.filter == event[1] or event[1] == "terminate") then
        local ok, param = coroutine.resume(
          program.thread,
          table.unpack(event, 1, event.n)
        )

        if ok then
          program.filter = param
        end

        if not ok then
          error(param, 0)
        end

        if coroutine.status(program.thread) == "dead" then
          kernel.programs[i] = false
        end
      end
    end

    event = table.pack(os.pullEventRaw())
  end
end

function kernel.MakeEnv(user, programId)
  local env = {}

  for k,v in pairs(kernel.baseEnv) do
    env[k] = v
  end

  env.require = require

  return env;
end

---comment
---@param location string
---@param user string
---@param args string[]?
---@param envOverwrite table?
---@param envMode "merge"|"overwrite"|nil
---@return integer|false
---@return string?
function kernel.AddProgram(location, user, args, envOverwrite, envMode)
  if (not location) or (not user) then
    return false
  end

  if envMode == nil then
    envMode = "overwrite"
  end

  local func, err = loadfile(location)

  if err then
    return false, err
  end

  if func then
    local pid = #kernel.programs + 1
    local env = kernel.MakeEnv(user, pid)

    if envOverwrite and envMode == "overwrite" then
      env = envOverwrite
    end

    if envOverwrite and envMode == "merge" then
      for k,v in pairs(envOverwrite) do
        env[k] = v
      end
    end

    env.APOLLON_API = createApi(user, pid)

    env._G = nil
    env._G = env

    setfenv(func, env)
    table.insert(kernel.programs, {
      location = location,
      user = user,
      thread = coroutine.create(function ()
        local success, err = pcall(function ()
          if args then
            func(table.unpack(args))
          else
            func()
          end
        end)
        os.queueEvent("APOLLON_PROCESS_EXIT", pid, success, err)
      end),
      filter = nil
    })

    return pid
  else
    return false
  end
end

---
---@return User[]?, string?
function kernel.GetUsers()
  local file, err = fs.open("/etc/passwd", "r")

  if not file then
    return nil, err
  end

  local contents = file.readAll()

  if contents == "" then
    return {}
  end

  file.close()
  
  local users = textutils.unserialize(contents)

  return users;
end

function kernel.WriteUsers(data)
  local file, err = fs.open("/etc/passwd", "w")

  if not file then
    return false, err
  end

  file.write(textutils.serialize(data))
  file.close()

  return true
end

function kernel.AddUser(username, password)
  local users, err = kernel.GetUsers()

  if not users then
    return false, err
  end

  if users[username] ~= nil then
    return false, "User already exists"
  end

  users[username] = {
    username = username,
    password = sha256.sha256(password),
    groups = {}
  }

  return kernel.WriteUsers(users)
end

function kernel.RemoveUser(username)
  local users, err = kernel.GetUsers();

  if not users then
    return false, err
  end

  if not users[username] then
    return false, "User doesn't exist"
  end

  users[username] = nil
  kernel.WriteUsers(users)

  return true
end

function kernel.GetUser(username)
  local users, err = kernel.GetUsers();

  if not users then
    return nil, err
  end

  if not users[username] then
    return nil, "User doesn't exist"
  end

  return users[username]
end

function kernel.TryAuthenticate(username, password)
  local user = kernel.GetUser(username)

  if not user then
    return false
  end

  local hashedArg = sha256.sha256(password)

  return user.password == hashedArg
end

kernel.Start()
