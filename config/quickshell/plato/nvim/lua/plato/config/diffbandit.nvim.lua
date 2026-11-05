-- diffbandit.nvim by Corey Kaylor — https://github.com/CoreyKaylor/diffbandit.nvim (Apache-2.0)
--
-- diffbandit.nvim: a side-by-side diff where neither side is padded to meet
-- the other. Each file keeps its own lines and numbers, and a corridor of
-- colored bands between them shows where every change on the left went on
-- the right.
-- Run by plato after the plugin loads; edit freely (plato's plugin panel,
-- "configure", opens this file).
--
-- OPENING ONE. It opens in an nvim tab page of its own; q closes it and
-- plato's file is back as it was.
--   :DiffBanditGitCurrent         this file against git (leader g d)
--   :DiffBanditGit                every changed file in the repository,
--                                 ]f [f from one to the next (leader g D)
--   :DiffBandit a.txt b.txt       two files
--   :DiffBanditGitCompare main x  two branches; :DiffBanditGitCommit HEAD
--   :DiffBanditFolderDiff a/ b/   two directories
--   :DiffBanditMerge FILE         a conflicted file, three ways
--
-- INSIDE ONE. ]c [c the next / previous change, ]s brings the other side
-- level with the cursor, >> << copy a change across, u undoes that, C the
-- commit panel, q closes. The right side is the real file: edit and :w.
--
-- NOT ON SPACE. Space never reaches nvim in plato — it opens plato's own
-- leader menu — so the plugin's Space keys are moved: gs stages or
-- unstages the change (or, in the commit panel, the file), ga turns amend
-- on and off in the commit message, and <Tab> opens a directory in a
-- directory diff (za as well).
--
-- DRAWN IN CELLS. The plugin can draw its corridor as a picture through
-- kitty's graphics protocol; plato is not a terminal, so it is always the
-- cell drawing here, which plato draws itself (view.lua).

-- COLORED FROM PLATO'S THEME. The plugin works its colors out from the
-- color scheme's DiffAdd / DiffDelete / DiffChange blended into Normal's
-- background. Plato's Normal has none (the window under the text is the
-- shell's), so for that moment it is given the theme's ground, the three
-- diff groups the theme's green, red and blue; then every one of the
-- plugin's groups that came out as just that ground loses it again, so
-- its gutters show plato's window rather than a slab painted over it.
-- A theme change (ColorScheme) does all of it again.
local api = vim.api
local hls = require("diffbandit.highlights")
local apply = hls.apply
hls.apply = function(config)
  local p = require("plato.theme").colors()
  local normal = api.nvim_get_hl(0, { name = "Normal", link = false })
  local ground = tonumber(p.black:sub(2), 16)
  api.nvim_set_hl(0, "Normal", vim.tbl_extend("force", normal, { bg = ground }))
  api.nvim_set_hl(0, "DiffAdd", { fg = p.green })
  api.nvim_set_hl(0, "DiffDelete", { fg = p.red })
  api.nvim_set_hl(0, "DiffChange", { fg = p.blue })
  local ok, err = pcall(apply, config)
  api.nvim_set_hl(0, "Normal", normal)
  for name, h in pairs(api.nvim_get_hl(0, {})) do
    if name:find("^DiffBandit") and not h.link and (h.bg == ground or h.fg == ground) then
      if h.bg == ground then h.bg = nil end
      if h.fg == ground then h.fg = nil end
      api.nvim_set_hl(0, name, h)
    end
  end
  if not ok then error(err, 0) end
end

require("diffbandit").setup({
  ui = { connector_renderer = "cells" },
  git = { panel = { keys = { toggle_stage = "gs", toggle_amend = "ga" } } },
  actions = { keys = { toggle_stage = "gs" } },
  folder = { keys = { toggle_expand = "<Tab>" } },
})
