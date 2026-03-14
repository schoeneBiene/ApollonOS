---@type KernelApi
local apollon = APOLLON_API

if not apollon.IsPrivileged() then
  print("You must be root to execute this command")
  return
end

local args = table.pack(...)

if args[1] == "create" then
  if args[2] then
    local username = args[2]
    write("Enter a password for "..username..": ")
    local password = read("*")

    local success, err = apollon.CreateUser(username, password)

    if not success then
      print("Creating user failed: "..err)
    else 
      print("Sucessfully created user")
    end
  else 
    print("Must provide a username")
  end
elseif args[1] == "remove" then
  if args[2] then
    write("Are you sure that you want to remove the user "..args[2].."? [y/N]: ")
    local confirm = read()

    if confirm == "y" then
      local success, err = apollon.RemoveUser(args[2])
      print(success)

      if not success then
        print("Removing user failed: "..err)
      else
        print("Successfully removed user")
      end
    end
  else 
    print("Must provide a username")
  end
elseif args[1] == "groupadd" then
  local username = args[2]

  if not username then
    print("Must provide a username")
  end

  local group = args[3]

  if not group then
    print("Must provide a group")
  end

  local success, err = apollon.AddGroupToUser(username, group)

  if not success then
    print("Adding group failed: "..err)
  else 
    print("Successfully added group")
  end
end
