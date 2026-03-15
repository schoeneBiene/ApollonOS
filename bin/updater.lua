---@type KernelApi
local apollon = APOLLON_API

local BASE_DOWNLOAD_PATH = "https://raw.githubusercontent.com/schoeneBiene/ApollonOS/master/"

if not apollon.IsPrivileged() then
  print("You must be root to use this command")
  return
end

if not fs.exists("/etc/commit.current") then
  print("error: no commit hash present")
  return
end

local args = table.pack(...)

local function checkForUpdates()
  local file = fs.open("/etc/commit.current", "r")
  local current_sha = file.readAll()
  file.close()

  local latest_commit_data = textutils.unserializeJSON(http.get("https://api.github.com/repos/schoeneBiene/ApollonOS/commits/master").readAll())
  local latest_commt_sha = latest_commit_data.sha

  if latest_commt_sha == current_sha then
    return nil
  end

  local compare_data = textutils.unserializeJSON(http.get("https://api.github.com/repos/schoeneBiene/ApollonOS/compare/"..current_sha.."..."..latest_commt_sha).readAll())

  return compare_data
end

if args[1] == "check" then
  local result = checkForUpdates()

  if not result then
    print("No updates available.")
    return
  end

  print("### Commits ###")

  for _,v in ipairs(result.commits) do
    print(v.commit.author.name..": "..v.commit.message)
  end

  print("### Files ###")
  for _,v in ipairs(result.files) do
    write(v.filename..": "..v.status)

    if v.status == "modified" and not fs.exists(v.filename) then
      write(" (ignored)")
    end

    write("\n")
  end
elseif args[1] == "update" then
  local result = checkForUpdates()
  
  if not result then
    print("No updates available.")
    return
  end

  print("Updating...")

  local files = {}

  for _, v in ipairs(result.files) do
    if not (v.status == "modified" and not fs.exists(v.filename)) then
      table.insert(files, v.filename)
    end
  end

  local contents = {}

  for _,v in ipairs(files) do
    print("Downloading "..v)
    local res, err = http.get(BASE_DOWNLOAD_PATH..v)

    if not res then
      error(err)
    end

    contents[v] = res.readAll()
    res.close()
  end

  print("Applying updates...")

  for _,v in ipairs(contents) do
    local file = fs.open(v, "w")

    file.write(v)
    file.close()
  end

  write("Updates applied. Would you like to reboot now? [Y/n] ")
  local answer = read()

  if answer ~= "n" then
    os.reboot()
  end
else 
  print("Usage: updater <check|update>")
end
  
