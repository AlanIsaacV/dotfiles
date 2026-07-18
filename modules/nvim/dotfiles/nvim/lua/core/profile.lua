local M = {}

function M.resolve(context)
  if context.force == "local" or context.force == "remote" then
    return context.force
  end

  return context.is_macos and not context.is_ssh and "local" or "remote"
end

function M.current()
  return M.resolve({
    force = vim.env.NVIM_PROFILE,
    is_macos = vim.uv.os_uname().sysname == "Darwin",
    is_ssh = vim.env.SSH_TTY ~= nil or vim.env.SSH_CONNECTION ~= nil,
  })
end

return M
