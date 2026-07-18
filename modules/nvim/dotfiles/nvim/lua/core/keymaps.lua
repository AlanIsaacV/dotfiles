local M = {}

local function map(mode, lhs, rhs, desc, options)
  options = vim.tbl_extend("force", { silent = true, desc = desc }, options or {})
  vim.keymap.set(mode, lhs, rhs, options)
end

local function plugin_or_warn(module, callback)
  return function()
    local ok, plugin = pcall(require, module)
    if not ok then
      vim.notify("This Neovim feature is not installed yet", vim.log.levels.WARN)
      return
    end
    callback(plugin)
  end
end

function M.setup(profile)
  map("n", "<leader>w", "<cmd>write<cr>", "Save buffer")
  map("n", "<leader>q", "<cmd>quit<cr>", "Quit window")
  map("n", "<Esc>", "<cmd>nohlsearch<cr>", "Clear search highlight")

  map("n", "<leader>e", plugin_or_warn("neo-tree.command", function(command)
    command.execute({ toggle = true })
  end), "Toggle file tree")
  map("n", "<leader>ff", plugin_or_warn("fzf-lua", function(fzf)
    fzf.files()
  end), "Find files")
  map("n", "<leader>fg", plugin_or_warn("fzf-lua", function(fzf)
    fzf.live_grep()
  end), "Find text")

  if profile ~= "local" then
    return
  end

  map("n", "<leader>gd", function()
    if vim.fn.exists(":DiffviewOpen") == 2 then
      vim.cmd("DiffviewOpen")
    else
      vim.notify("Diffview is not installed yet", vim.log.levels.WARN)
    end
  end, "Review Git changes")
  map("n", "<leader>cf", plugin_or_warn("conform", function(conform)
    conform.format({ async = true, lsp_format = "fallback" })
  end), "Format buffer")
end

return M
