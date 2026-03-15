local module = {}

function module.GetIdentifier()
  return "apollon.installer"
end

---@param kernel Kernel
function module.Load(kernel)
  if fs.exists("/etc/install.cfg") then
    print("Setting up your system...")
    local file = fs.open("/etc/install.cfg", "r")
    local contents = file.readAll()
    file.close()
    local config = textutils.unserialize(contents)

    local res, err = kernel.AddUser(config.username, config.password)

    if not res then
      error("Failed to create user: "..tostring(err))
    end

    if config.shouldWheel then
      kernel.AddGroupToUser(config.username, "wheel")
    end

    kernel.RemoveUser("root")
    kernel.AddUser("root", config.rootPassword)

    fs.delete("/etc/install.cfg")
    os.reboot()
  end
end

return module
