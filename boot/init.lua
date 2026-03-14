---@type KernelApi
local apollon = APOLLON_API
::start::
term.clear()
term.setCursorPos(1, 1)
term.setTextColor(2 ^ math.random(0, 15))
print("Welcome to ApollonOS!")

term.setTextColor(colors.white)

::fail::
write("Username: ")
local username = read()
write("Password: ")
local password = read("*")

if apollon.TryAuthenticate(username, password) then
  local pid = apollon.RunProgram("/bin/shell.lua", username)

  local e, exited, success, err

  repeat
    e, exited, success, err = os.pullEventRaw("APOLLON_PROCESS_EXIT")
  until exited == pid

  if not success then
    if err == nil then
      err = "nil"
    end

    term.setTextColor(colors.red)
    print("Shell program exited with error: "..err)
    term.setTextColor(colors.white)
  end

  goto start
else
  print("Wrong username and/or password. Try again.")
  goto fail;
end

