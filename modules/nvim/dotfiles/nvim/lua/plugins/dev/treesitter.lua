local lang = require("lang")

-- The filetypes this repository is itself written in, which the lang/ registry will never
-- declare: a language file means a server and a formatter, and there is none to declare
-- for a query file or this config's own Lua.
local BASE_PARSERS = { "bash", "json", "lua", "markdown", "query", "vim", "vimdoc", "yaml" }

local function union(first, second)
  local seen, names = {}, {}
  for _, list in ipairs({ first, second }) do
    for _, name in ipairs(list) do
      if not seen[name] then
        seen[name] = true
        names[#names + 1] = name
      end
    end
  end
  table.sort(names)
  return names
end

-- Registry keys are Neovim filetypes and the base set names parsers, and the two are not
-- the same vocabulary: the `bash` parser highlights filetype `sh`, `vimdoc` highlights
-- `help`. The parser list is in parser names, so the FileType pattern has to be that list
-- put back through the ft-to-parser registrations, or those two buffers never get one.
local function filetype_patterns(parsers)
  local seen, filetypes = {}, {}
  for _, parser in ipairs(parsers) do
    for _, filetype in ipairs(vim.treesitter.language.get_filetypes(parser)) do
      if not seen[filetype] then
        seen[filetype] = true
        filetypes[#filetypes + 1] = filetype
      end
    end
  end
  table.sort(filetypes)
  return filetypes
end

return {
  {
    "nvim-treesitter/nvim-treesitter",
    -- Upstream states the plugin does not support lazy-loading. Its cost lands in both
    -- arms of this objective's startup comparison, so it cannot flatter the deferral the
    -- specs in lsp.lua are measured for.
    lazy = false,
    -- Parsers install through this build step and afterwards through nvim-treesitter's own
    -- commands, with no timeout and no cleanup of a half-finished install. That departs from
    -- ADR 01M0PDHRTWTC7AVDH9X6CFEKBA, which gives every process a startup spawns a deadline
    -- and makes it remove what it partly created; ADR 01M0QZ3DJX0C0Q61BABW5W08FM narrows the
    -- rule to processes the user is blocked on -- startup does not finish, or the editor is
    -- unusable, until they return -- and an install is not one: it runs as a task and the
    -- editor works meanwhile. The accepted cost is real. An install that hangs, hangs, with
    -- no deadline and nothing said about it, and a half-extracted grammar sits under
    -- stdpath("cache") until the next attempt -- a retry is still correct, because upstream
    -- clears that path first. The five-minute timer and staging sweep that stood here were a
    -- third of this file, which has to stay editable by hand.
    build = ":TSUpdate",
    config = function()
      local parsers = union(lang.filetypes(), BASE_PARSERS)
      -- Published so the resolved union is readable from a running Neovim instead of
      -- re-derived by whoever is checking that a new lang/ file reached it.
      vim.g.dotfiles_nvim_treesitter_parsers = parsers

      -- Neither highlighting nor indentation is enabled by the plugin on `main`; both are
      -- Neovim features this turns on per filetype.
      vim.api.nvim_create_autocmd("FileType", {
        pattern = filetype_patterns(parsers),
        callback = function()
          -- The install is asynchronous, so a first-run buffer can open before its parser
          -- is built, and an uncaught start() there would error on every such open.
          if pcall(vim.treesitter.start) then
            vim.bo.indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
          end
        end,
      })
    end,
  },
}
