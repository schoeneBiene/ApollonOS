local module = {}

function module.GetIdentifier()
  return "apollon.craftos-apis"
end

---@param kernel Kernel
function module.Load(kernel)
  local orig = kernel.MakeEnv;

  kernel.MakeEnv = function (user, programId)
    local env = orig(user, programId)

    for k, v in pairs(_G) do
      if type(v) == "table" then
        local new = {}

        for k2, v2 in pairs(v) do
          new[k2] = v2
        end

        env[k] = new
      else
        env[k] = v
      end

    end

    env.os.run = function (runEnv, path, ...)
      local pid = kernel.AddProgram(location, user, table.pack(...), runEnv)

      if not pid then
        return false
      end

      while true do
        local _, epid = os.pullEvent("APOLLON_PROCESS_EXIT")

        if pid == epid then
          break
        end
      end
    end

    if user ~= "root" then
      ---@param path string
      ---@return string
      local function standardizePath(path)
        if not path:find("^/") then
          path = "/" .. path
        end

        local parts = {}

        for part in path:gmatch("[^/]+") do
          if part == ".." then
           if #parts > 0 then
             table.remove(parts)
            end
          elseif part ~= "." and part ~= "" then
            table.insert(parts, part)
          end
        end

        return "/" .. table.concat(parts, "/")
     end

      ---@param path string
      ---@return boolean
      local function isInHomeDir(path)
        local res = path:find("^/home/"..user)

        return res ~= nil
      end

      local function mayRead(path)
        return not (path:find("^/etc/passwd"))
      end

      local origFsIsReadyOnly = fs.isReadOnly

      env.fs.isReadOnly = function (path)
        path = standardizePath(path)

        if isInHomeDir(path) then
          return origFsIsReadyOnly(path)
        end

        return true
      end

      local origFsMove = fs.move

      env.fs.move = function (path, dest)
        path = standardizePath(path)
        dest = standardizePath(dest)
        
        if not isInHomeDir(path) or not isInHomeDir(dest) then
          error("Insufficient permissions")
        end

        origFsMove(path, dest)
      end

      local origFsCopy = fs.copy

      env.fs.copy = function (path, dest)
        path = standardizePath(path)
        dest = standardizePath(dest)

        if not mayRead(path) or not isInHomeDir(dest) then
          error("Insufficient permissions")
        end

        origFsCopy(path, dest)
      end

      local origFsDelete = fs.delete

      env.fs.delete = function (path)
        path = standardizePath(path)

        if not isInHomeDir(path) then
          error("Insufficient permissions")
        end
        
        origFsDelete(path)
      end

      local origFsOpen = fs.open

      env.fs.open = function (path, mode)
        path = standardizePath(path)

        if mode == "r" or mode == "rb" then
          if mayRead(path) then
            return origFsOpen(path, mode)
          else
            return nil
          end
        end

        if isInHomeDir(path) then
          return origFsOpen(path, mode)
        end

        error("Insufficient permissions")
      end

      local origIoOpen = io.open

      env.io.open = function (path, mode)
        path = standardizePath(path)

        if mode == "r" or mode == "rb" then
          if mayRead(path) then
            return origIoOpen(path, mode)
          else
            return nil
          end
        end

        if isInHomeDir(path) then
          return origIoOpen(path, mode)
        end

        error("Insufficient permissions")
      end
    end

    return env
  end
end

return module
