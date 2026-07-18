local M = {}

function M.spec(profile)
  local specs = vim.deepcopy(require("plugins.shared"))
  if profile == "local" then
    vim.list_extend(specs, require("plugins.local"))
  end
  return specs
end

return M
