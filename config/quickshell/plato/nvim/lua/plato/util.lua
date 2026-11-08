-- ┌─┐┌─┐┌┐┌┬ ┬┌─┐┬─┐┬┌─┌─┐
-- ┌─┘├┤ │││││││ │├┬┘├┴┐└─┐
-- └─┘└─┘┘└┘└┴┘└─┘┴└─┴ ┴└─┘
-- https://github.com/kbuckleys/
--
-- The small things more than one part of the engine needs.
--
--   markers, rootOf(file)     a file's project: the nearest .git, or this
--                             shell's .qmlls.ini / shell.qml — or its own
--                             directory, for a file in no project
--   readJson(path)            a JSON file as a table ({} when missing or bad)
--   writeJson(path, t)        written whole or not at all (see below)
--   fail(err)                 an error said in the status line, without
--                             the Lua file:line before it (and from the
--                             E-number on when vim gave one)
--   ago(t, short)             "3 days ago" — or "3 min ago" with short, and
--                             a date once it is older than a day

local M = {}

M.markers = { ".git", ".qmlls.ini", "shell.qml" }

function M.rootOf(file)
  return vim.fs.root(file, M.markers) or vim.fs.dirname(file)
end

function M.fail(err)
  local s = (tostring(err):gsub("^.-:%d+: ", ""))
  s = (s:gsub("^.-(E%d+:)", "%1"))
  vim.notify(s, vim.log.levels.ERROR)
end

function M.readJson(path)
  local f = io.open(path, "r")
  if not f then return {} end
  local ok, j = pcall(vim.json.decode, f:read("*a"))
  f:close()
  return ok and type(j) == "table" and j or {}
end

-- WHOLE OR NOT AT ALL. Every plato window's engine writes these files, and
-- one cut off halfway (a crash, a full disk) read back as nothing — every
-- project's pins or tabs gone. Written beside the real file and renamed over
-- it, which is atomic on one filesystem: a reader sees the old file or the
-- new one, never part of either.
function M.writeJson(path, t)
  vim.fn.mkdir(vim.fs.dirname(path), "p")
  local tmp = path .. ".tmp" .. vim.uv.os_getpid()
  local f = io.open(tmp, "w")
  if not f then return false end
  f:write(vim.json.encode(t))
  f:close()
  local ok = vim.uv.fs_rename(tmp, path)
  if not ok then os.remove(tmp) end
  return ok and true or false
end

-- READ, CHANGED, WRITTEN, BY ONE ENGINE AT A TIME (audit 10-31). Each plato
-- window's engine read and wrote these files on its own, and two saving
-- together dropped each other's change (sessions: project roots). The lock
-- is a directory, made atomically; one left by a crash is broken after 5 s.
function M.updateJson(path, fn)
  vim.fn.mkdir(vim.fs.dirname(path), "p")
  local lock = path .. ".lock"
  local got = false
  for _ = 1, 100 do
    if vim.uv.fs_mkdir(lock, 448) then got = true; break end
    local st = vim.uv.fs_stat(lock)
    if st and os.time() - st.mtime.sec > 5 then vim.uv.fs_rmdir(lock) end
    vim.uv.sleep(10)
  end
  local all = M.readJson(path)
  local ok, err = pcall(fn, all)
  if ok then M.writeJson(path, all) end
  if got then vim.uv.fs_rmdir(lock) end
  if not ok then error(err) end
  return all
end

function M.ago(t, short)
  local d = os.time() - t
  if short then
    if d < 60 then return d .. " s ago" end
    if d < 3600 then return math.floor(d / 60) .. " min ago" end
    if d < 86400 then return math.floor(d / 3600) .. " h ago" end
    return os.date("%d %b %H:%M", t)
  end
  if d < 60 then return "just now" end
  local function n(v, unit) v = math.floor(v); return v .. " " .. unit .. (v == 1 and "" or "s") .. " ago" end
  if d < 3600 then return n(d / 60, "minute") end
  if d < 86400 then return n(d / 3600, "hour") end
  if d < 86400 * 30 then return n(d / 86400, "day") end
  if d < 86400 * 365 then return n(d / (86400 * 30), "month") end
  return n(d / (86400 * 365), "year")
end

return M
