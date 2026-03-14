---@type KernelApi
local apollon = APOLLON_API

local cwd = apollon.GetHomeDir()
local user = apollon.GetCurrentUser()

local parentShell = shell

local SEARCH_PATHS = {
  "/bin",
  "/rom/programs",
  "/rom/programs/http",
  "/rom/programs/turtle",
  "/rom/programs/rednet",
  "/rom/programs/fun",
  "/rom/programs/command",
  "/rom/programs/pocket"
}

--- Execute a program with the given arguments.
---@param location string
---@param ... string?
local function runProgram(location, ...)
  local pid, err = apollon.RunProgramMergeEnv(location, nil, { shell = parentShell },...)

  if not pid then
    if not err then
      err = "nil"
    end

    print("Error: "..err)
    return false
  end

  local exited, success, err

  repeat
    _, exited, success, err = os.pullEventRaw("APOLLON_PROCESS_EXIT")
  until exited == pid

  return success, err
end

---@param program string
---@return string?
local function resolveProgram(program) 
  if program:find("^/") then
    if fs.exists(program) then
      return program
    else 
      return nil
    end
  end

  local cwd_path = fs.combine(cwd, program)

  if fs.exists(cwd_path) and not fs.isDir(cwd_path) then
    return cwd_path
  end

  if not cwd_path:find("\\.lua$") and fs.exists(cwd_path..".lua") then
    return cwd_path..".lua"
  end

  if not cwd_path:find("\\.lua$") then
    program = program..".lua"
  end

  for _, search in ipairs(SEARCH_PATHS) do
    local list = fs.list(search)

    for _, v in ipairs(list) do
      if v == program and not fs.isDir(fs.combine(search, v)) then
        return fs.combine(search, v)
      end
    end
  end

  return nil
end

local function executeProgram(input)
  local t = {}

  for w in input:gmatch("%S+") do
    table.insert(t, w)
  end

  local program = table.remove(t, 1)
  local location = resolveProgram(program)

  if not location then
    return false, "NOT_FOUND"
  end

  return runProgram(location, table.unpack(t))
end

local shouldExit = false

local function makeShellObject() 
  return {
    execute = function (command, ...)
      local location = resolveProgram(command)

      if not location then
        return false
      end

      return runProgram(location, ...)
    end,
    run = function (...)
      return executeProgram(table.concat(table.pack(...), " "))
    end,
    exit = function ()
      shouldExit = true
    end,
    dir = function ()
      return cwd
    end,
    setDir = function (path)
      if not path:find("^/") then
        cwd = "/"..path
      else 
        cwd = path
      end
    end,
    path = function ()
      return "."..table.concat(SEARCH_PATHS, ":")
    end,
    setPath = function (path)
      -- TODO
    end,
    resolve = function (path)
      if path:find("^/") then
        return path
      end

      return fs.combine(cwd, path)
    end,
    resolveProgram = function (command)
      return resolveProgram(command)
    end,
    programs = function ()
      -- todo
    end,
    complete = function ()
      -- todo
    end,
    completeProgram = function ()
      -- todo
    end,
    setCompletionFunction = function ()
      -- todo
    end,
    getCompletionInfo = function ()
      -- todo
    end,
    getRunningProgram = function ()
      return ""
    end,
    setAlias = function (command, program)
      -- todo
    end,
    clearAlias = function (command)
      -- todo
    end,
    aliases = function ()
      -- todo
      return {}
    end
  }
end

if not parentShell then
  parentShell = makeShellObject()
else
  cwd = parentShell.dir()
end

local args = ...

if args ~= nil then
  local args_packed = table.pack(...)
  executeProgram(table.concat(args_packed, " "))
  return
end

local history = {}

while true do
  term.setTextColor(colors.green)
  write(user.."@ApollonOS")
  term.setTextColor(colors.white)
  write(":")
  term.setTextColor(colors.blue)
  write(cwd:gsub("^/home/"..user, "~"))
  term.setTextColor(colors.white)
  write("$ ")

  ---@type string
  local input = read(nil, history)

  if input == "" then
    goto continue
  end

  table.insert(history, input)

  local res, err = executeProgram(input)

  if err == "NOT_FOUND" then
    print("Could not find program")
  elseif err ~= nil then 
    term.setTextColor(colors.red)
    print("Error: "..err)
    term.setTextColor(colors.white)
  end

  if shouldExit then
    break
  end

    ::continue::
end
