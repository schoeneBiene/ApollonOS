local FILES = {
  "/startup.lua",
  "/bin/logout.lua",
  "/bin/reboot.lua",
  "/bin/shell.lua",
  "/bin/sudo.lua",
  "/bin/tasklist.lua",
  "/bin/userctl.lua",
  "/bin/whoami.lua",
  "/boot/modules/craftos-apis.lua",
  "/boot/modules/installer.lua",
  "/boot/modules/sudo.lua",
  "/boot/init.lua",
  "/boot/kernel.lua",
  "/etc/passwd",
  "/lib/sha256.lua"
}

local BASE_PATH = "https://raw.githubusercontent.com/schoeneBiene/ApollonOS/master"

print("Welcome to the ApollonOS installer!")

---@param question string
---@param default boolean
---@return boolean
local function yesOrNoQuestion(question, default) 
  if default then
    question = question.." [Y/n] "
  else
    question = question.." [y/N] "
  end

  write(question)
  
  while true do
    local _, key = os.pullEvent("key")

    if keys.getName(key) == "enter" then
      if default then
        write("Y\n")
      else 
        write("N\n")
      end

      return default
    end

    if keys.getName(key) == "y" then
      write("y\n")
      return true
    end

    if keys.getName(key) == "z" then
      write("y\n")
      return true
    end

    if keys.getName(key) == "n" then
      write("n\n")
      return false
    end
  end
end

---@param question string
---@param hideChar string?
---@return string
local function input(question, hideChar)
  write(question)
  return read(hideChar)
end

local username = input("Please name your user account: ")
local password = input("Give your new account a password: ", "*")
local shouldWheel = yesOrNoQuestion("Would you like to add your new user to the wheel group? (enables sudo access)", true)

local rootPassword = input("Give the root user a password: ", "*")
local shouldMoveFiles = false

if #fs.list("/") > 1 then
  shouldMoveFiles = yesOrNoQuestion("There are files in the root directory, would you like to move them to your users' home directory?", true)
end

if not yesOrNoQuestion("Would you like install ApollonOS with the provided options?", true) then
  return
end

if shouldMoveFiles then
  print("Moving files")
  local basePath = fs.combine("/home", username)

  local function moveFiles(dirPath)
    fs.makeDir(fs.combine(basePath, dirPath))
    local list = fs.list(dirPath)

    for _,v in ipairs(list) do
      if fs.combine(dirPath, v) == basePath then
        goto continue
      end
      
      if fs.isDir(fs.combine(dirPath, v)) then
        if dirPath == "/" and (v == "rom" or v == "home") then
          goto continue
        else 
          moveFiles(fs.combine(dirPath, v))
        end
      else
        fs.move(fs.combine(dirPath, v), fs.combine(basePath, dirPath, v))
      end

      ::continue::
    end

    if dirPath ~= "/" then
      fs.delete(dirPath)
    end
  end

  moveFiles("/")
end

print("Downloading files")

for _,v in ipairs(FILES) do
  print("Downloading "..v)

  local res, err = http.get(BASE_PATH..v)

  if not res then
    error(err)
  end

  local contents = res.readAll()
  res.close()

  local file = fs.open(v, "w")
  file.write(contents)
  file.close()
end

local config = {
  username = username,
  password = password,
  shouldWheel = shouldWheel,
  rootPassword = rootPassword
}

print("Writing config")

local file = fs.open("/etc/install.cfg", "w")
file.write(textutils.serialize(config))
file.close()
