-- Each lang/<name>.lua returns plain data, not a lazy spec: lazy's opts merge replaces
-- lists instead of concatenating them, so spec fragments contributing to one
-- ensure_installed would silently keep only the last file imported.
--
-- A file's name is the Neovim filetype it configures; conform is keyed by it. Nothing
-- else names the languages, so the name is the only thing carrying the filetype.

local M = {}

local function module_names()
  local seen, names = {}, {}
  -- Resolved against the runtimepath, because the config is symlinked and cannot know
  -- where on disk it came from.
  for _, path in ipairs(vim.api.nvim_get_runtime_file("lua/lang/*.lua", true)) do
    local name = vim.fn.fnamemodify(path, ":t:r")
    if name ~= "init" and not seen[name] then
      seen[name] = true
      names[#names + 1] = name
    end
  end
  table.sort(names)
  return names
end

function M.all()
  local all = {}
  for _, name in ipairs(module_names()) do
    -- This runs during lazy spec evaluation, and lazy catches an import failure per
    -- module: unguarded, one malformed language file takes the entire plugins.dev
    -- import set with it and Neovim still starts, quietly missing LSP and formatting.
    local ok, spec = pcall(require, "lang." .. name)
    if ok and type(spec) ~= "table" then
      -- A file that forgets its `return` loads fine and yields `true`; indexing that in
      -- M.servers() throws past this pcall and costs the import set just the same.
      ok, spec = false, ("expected a table, got %s"):format(type(spec))
    end
    if ok then
      all[name] = spec
    else
      vim.notify(("lang: skipping lua/lang/%s.lua: %s"):format(name, spec), vim.log.levels.ERROR)
    end
  end
  return all
end

function M.filetypes()
  -- Sorted for the same reason M.servers() is: the callers hand this straight to lazy's
  -- `ft` and to a treesitter install list, and an unordered pairs() walk over M.all()
  -- reorders both between runs, which makes before/after spec diffs unusable.
  local filetypes = vim.tbl_keys(M.all())
  table.sort(filetypes)
  return filetypes
end

function M.servers()
  local servers = {}
  for _, spec in pairs(M.all()) do
    if spec.server then
      servers[#servers + 1] = spec.server
    end
  end
  table.sort(servers, function(a, b)
    return a.name < b.name
  end)
  return servers
end

function M.server_names()
  local names = {}
  for _, server in ipairs(M.servers()) do
    names[#names + 1] = server.name
  end
  return names
end

function M.debug_adapters()
  local adapters = {}
  for _, spec in pairs(M.all()) do
    local adapter = type(spec.debug) == "table" and spec.debug.adapter or nil
    -- Typed rather than merely truthy, because the comparator below reaches for `.name`: an
    -- adapter declared as a bare string yields nil there and the comparison throws past
    -- M.all()'s pcall, which costs the whole plugins.dev import set instead of one language.
    if type(adapter) == "table" and type(adapter.name) == "string" then
      adapters[#adapters + 1] = adapter
    end
  end
  table.sort(adapters, function(a, b)
    return a.name < b.name
  end)
  return adapters
end

function M.debug_adapter_names()
  local names = {}
  -- Order inherited from M.debug_adapters(), for mason-nvim-dap's ensure_installed.
  for _, adapter in ipairs(M.debug_adapters()) do
    names[#names + 1] = adapter.name
  end
  return names
end

function M.debug_configurations_by_ft()
  local declared = {}
  -- Every adapter the registry got as far as declaring, not just this file's own: a
  -- configuration names its adapter by name, and one language reusing another's -- a future
  -- c.lua on codelldb -- is a legitimate declaration rather than a dangling one.
  for _, name in ipairs(M.debug_adapter_names()) do
    declared[name] = true
  end

  local by_ft = {}
  for filetype, spec in pairs(M.all()) do
    local configurations = type(spec.debug) == "table" and spec.debug.configurations or nil
    -- Length rather than type alone: nvim-dap walks dap.configurations[ft] with ipairs, so a
    -- table keyed by anything but 1..n is not a configuration list, and an empty one declares
    -- nothing that the filetype's absence from this map does not already say.
    if type(configurations) == "table" and #configurations > 0 then
      local unusable
      for _, configuration in ipairs(configurations) do
        -- The symmetric half of M.debug_adapters()' guard, and the reason it has to exist:
        -- nvim-dap resolves a configuration's `type` against dap.adapters only when the
        -- session is STARTED. Configurations declared over an adapter that never entered the
        -- registry therefore fail at the first <leader>dc with "no adapter", long after the
        -- load that could have named the lang file responsible.
        if type(configuration) ~= "table" then
          unusable = ("a %s where a configuration table was expected"):format(type(configuration))
        elseif not declared[configuration.type] then
          unusable = ("no adapter named %s"):format(tostring(configuration.type))
        end
        if unusable then
          break
        end
      end
      -- The filetype's whole list, not the offending entry: a list silently one shorter than
      -- the lang file reads is the failure nobody notices, while a filetype absent from this
      -- map takes its <leader>d keys with it, which is a debugger that says so.
      if unusable then
        vim.notify(
          ("lang: skipping %s debug configurations: %s"):format(filetype, unusable),
          vim.log.levels.ERROR
        )
      else
        by_ft[filetype] = configurations
      end
    end
  end
  return by_ft
end

function M.debug_filetypes()
  -- Derived from the map above rather than from M.filetypes(), which is what keeps the
  -- <leader>d keys and dap.configurations in lockstep by construction: a filetype whose
  -- configurations were dropped above must not be a filetype the keys exist in. Sorted for
  -- the reason M.filetypes() is -- this is handed to lazy as a per-binding `ft` list.
  local filetypes = vim.tbl_keys(M.debug_configurations_by_ft())
  table.sort(filetypes)
  return filetypes
end

function M.formatters_by_ft()
  local by_ft = {}
  for filetype, spec in pairs(M.all()) do
    if spec.formatters then
      by_ft[filetype] = spec.formatters
    end
  end
  return by_ft
end

return M
