local M = {}
local g = vim.g
local config = require "aome.core.default_config"

local fnamemodify = vim.fn.fnamemodify

M.get_theme_tb = function(type)
  local default_path = "base46.themes." .. config.ui.theme
  local user_path = "custom.themes." .. config.ui.theme

  local present1, default_theme = pcall(require, default_path)
  local present2, user_theme = pcall(require, user_path)

  if present1 then
    return default_theme[type]
  elseif present2 then
    return user_theme[type]
  else
    error "No such theme!"
  end
end

M.merge_tb = function(...)
  return vim.tbl_deep_extend("force", ...)
end

local change_hex_lightness = require("base46.colors").change_hex_lightness

-- turns color var names in hl_override/hl_add to actual colors
-- hl_add = { abc = { bg = "one_bg" }} -> bg = colors.one_bg
M.turn_str_to_color = function(tb)
  local colors = M.get_theme_tb "base_30"
  local copy = vim.deepcopy(tb)

  for _, hlgroups in pairs(copy) do
    for opt, val in pairs(hlgroups) do
      if opt == "fg" or opt == "bg" or opt == "sp" then
        if not (type(val) == "string" and val:sub(1, 1) == "#" or val == "none" or val == "NONE") then
          hlgroups[opt] = type(val) == "table" and change_hex_lightness(colors[val[1]], val[2]) or colors[val]
        end
      end
    end
  end

  return copy
end

M.extend_default_hl = function(highlights, integration_name)
  local polish_hl = M.get_theme_tb "polish_hl"

  -- polish themes
  if polish_hl and polish_hl[integration_name] then
    highlights = M.merge_tb(highlights, polish_hl[integration_name])
  end

  -- transparency
  if config.ui.transparency then
    local glassy = require "base46.glassy"

    for key, value in pairs(glassy) do
      if highlights[key] then
        highlights[key] = M.merge_tb(highlights[key], value)
      end
    end
  end

  if config.ui.hl_override then
    local overriden_hl = M.turn_str_to_color(config.ui.hl_override)

    for key, value in pairs(overriden_hl) do
      if highlights[key] then
        highlights[key] = M.merge_tb(highlights[key], value)
      end
    end
  end

  return highlights
end

M.load_integrationTB = function(name)
  local highlights = require("base46.integrations." .. name)
  return M.extend_default_hl(highlights, name)
end

-- convert table into string
M.table_to_str = function(tb)
  local result = ""

  for hlgroupName, hlgroup_vals in pairs(tb) do
    local hlname = "'" .. hlgroupName .. "',"
    local opts = ""

    for optName, optVal in pairs(hlgroup_vals) do
      local valueInStr = ((type(optVal)) == "boolean" or type(optVal) == "number") and tostring(optVal)
        or '"' .. optVal .. '"'
      opts = opts .. optName .. "=" .. valueInStr .. ","
    end

    result = result .. "vim.api.nvim_set_hl(0," .. hlname .. "{" .. opts .. "})"
  end

  return result
end

M.saveStr_to_cache = function(filename, tb)
  -- Thanks to https://github.com/nullchilly and https://github.com/EdenEast/nightfox.nvim
  -- It helped me understand string.dump stuff

  local bg_opt = "vim.opt.bg='" .. M.get_theme_tb "type" .. "'"
  local defaults_cond = filename == "defaults" and bg_opt or ""

  local lines = "return string.dump(function()" .. defaults_cond .. M.table_to_str(tb) .. "end, true)"
  local file = io.open(vim.g.base46_cache .. filename, "wb")

  if file then
    file:write(loadstring(lines)())
    file:close()
  end
end

M.compile = function()
  if not vim.loop.fs_stat(vim.g.base46_cache) then
    vim.fn.mkdir(vim.g.base46_cache, "p")
  end

  for _, filename in ipairs(config.base46.integrations) do
    M.saveStr_to_cache(filename, M.load_integrationTB(filename))
  end
end

M.load_all_highlights = function()
  require("plenary.reload").reload_module "base46"
  M.compile()

  for _, filename in ipairs(config.base46.integrations) do
    dofile(vim.g.base46_cache .. filename)
  end

  -- update blankline
  pcall(function()
    require("ibl").update()
  end)
end

M.override_theme = function(default_theme, theme_name)
  local changed_themes = config.ui.changed_themes
  return M.merge_tb(default_theme, changed_themes.all or {}, changed_themes[theme_name] or {})
end

M.toggle_theme = function()
  local themes = config.ui.theme_toggle

  if config.ui.theme ~= themes[1] and config.ui.theme ~= themes[2] then
    vim.notify "Set your current theme to one of those mentioned in the theme_toggle table (chadrc)"
    return
  end

  g.icon_toggled = not g.icon_toggled
  g.toggle_theme_icon = g.icon_toggled and "   " or "   "

  config.ui.theme = (themes[1] == config.ui.theme and themes[2]) or themes[1]

  local old_theme = dofile(vim.fn.stdpath "config" .. "/lua/aome/default_config.lua").ui.theme
  require("nvchad.utils").replace_word(old_theme, config.ui.theme)
  M.load_all_highlights()
end

M.toggle_transparency = function()
  config.ui.transparency = not config.ui.transparency
  M.load_all_highlights()

  local old_transparency_val = dofile(vim.fn.stdpath "config" .. "/lua/aome/core/default_config.lua").ui.transparency
  local new_transparency_val = "transparency = " .. tostring(config.ui.transparency)
  require("nvchad.utils").replace_word("transparency = " .. tostring(old_transparency_val), new_transparency_val)
end

function M.merge_tbl(tbl1, tbl2)
  return vim.tbl_deep_extend("force", tbl1, tbl2)
end

function M.get_colors(base, theme_name)
  P(require("base46.themes")
  local path = "base46.themes." .. theme_name
  local present, theme = pcall(require, path)

  if not present then
    error("`" .. theme_name .. "`" .. " is not an available theme", 2)
    return
  end

  if base == "base46" then
    local base46 = M.merge_tbl(theme.base_16, theme.base_30)
    return base46
  end

  return theme.base_16
end

function M.get_polish(theme_name)
  local path = "base46.hl_themes." .. theme_name
  local present, theme = pcall(require, path)

  if not present then
    error("`" .. theme_name .. "`" .. " is not an available theme", 2)
    return
  end

  return theme.polish_hl
end

function M.get_lualine_theme(base, theme_name)
  if not base == "base46" then
    error "must use base46 for lualine theme"
    return
  end

  local colors = M.get_colors(base, theme_name)
  if colors == nil then
    error "failed to get colors from theme"
    return
  end

  local default_b = { bg = colors.one_bg, fg = colors.white }
  local default_c = { bg = colors.black2, fg = colors.white }
  local lualine_theme = {
    normal = {
      a = { bg = colors.red, fg = colors.black, gui = "bold" },
      b = default_b,
      c = default_c,
      z = { bg = colors.cyan, fg = colors.black, gui = "bold" },
    },
    insert = {
      a = { bg = colors.blue, fg = colors.black, gui = "bold" },
      b = default_b,
      c = default_c,
    },
    visual = {
      a = { bg = colors.dark_purple, fg = colors.black, gui = "bold" },
      b = default_b,
      c = default_c,
    },
    replace = {
      a = { bg = colors.red, fg = colors.black, gui = "bold" },
      b = default_b,
      c = default_c,
    },
    command = {
      a = { bg = colors.green, fg = colors.black, gui = "bold" },
      b = default_b,
      c = default_c,
    },
    inactive = {
      a = { bg = colors.black, fg = colors.gray, gui = "bold" },
      b = { bg = colors.black, fg = colors.gray },
      c = { bg = colors.black, fg = colors.gray },
    },
  }

  return lualine_theme
end

function M.get_dir_modules(dir_path)
  local dir_contents = require("plenary.scandir").scan_dir(dir_path, {})

  local modules = {}
  for _, content in ipairs(dir_contents) do
    local module = fnamemodify(fnamemodify(content, ":t"), ":r")
    table.insert(modules, module)
  end

  return modules
end

M.load_theme = function(user_opts)
  local opts = {
    base = "base46",
    theme = "",
    transparency = false,
  }

  opts = M.merge_tbl(opts, user_opts)

  local colors = M.get_colors(opts.base, opts.theme)
  if not colors then
    return
  end

  -- term hls
  require "base46.term"
end

return M
