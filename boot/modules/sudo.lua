local module = {}

function module.GetIdentifier()
  return "apollon.sudo"
end

---@param kernel Kernel
function module.Load(kernel)
  local function UserCanUse(username)
    if username == "root" then
      return true
    end

    local user = kernel.GetUser(username)

    if not user then
      return false
    end

    local contains = false

    for _, v in ipairs(user.groups) do
      if v == "wheel" then
        contains = true
        break
      end
    end

    return contains
  end

  return {
    Execute = function (username, password, ...)
      local success = kernel.TryAuthenticate(username, password)

      if not success then
        return false
      end

      if not UserCanUse(username) then
        return false
      end

      return kernel.AddProgram("/bin/shell.lua", "root", table.pack(...))
    end,

    UserCanUse = function (username)
      return UserCanUse(username)
    end
  }
end

return module

