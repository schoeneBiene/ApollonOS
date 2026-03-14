local function panic(err)
  term.setTextColor(colors.white)
  term.setBackgroundColor(colors.blue)
  term.clear()
  term.setCursorPos(1, 1)
  print("The kernel has suffered a critical error and needs to stop: "..tostring(err))
  term.setTextColor(colors.white)
  print("\nPress any key to reboot")
  os.pullEventRaw("key")
  os.reboot()
end

local success, err = pcall(function ()
  require("/boot/kernel")
end)

if not success then
  panic(err)
end

os.shutdown()
