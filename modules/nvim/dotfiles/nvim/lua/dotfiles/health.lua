-- Discovered by :checkhealth through the directory name alone: `lua/dotfiles/health.lua`
-- is what makes the command `:checkhealth dotfiles`. Nothing requires or registers this
-- file, so moving or renaming the directory silently renames the command.
--
-- This is the only place the module probes for executables. Doing it at startup instead
-- would cost every session several PATH walks to report something nobody asked for.

local M = {}

-- The same binary passes under one profile and fails under the other: the dev-only
-- plugins refuse to load below 0.12, while everything on the shared path still runs on
-- 0.11, which is where the remote servers are.
--
-- Two dev-only plugins set that floor and only one of them asserts it yet. nvim-treesitter's
-- main branch states 0.12, and it is the one the message names because it is the one that
-- breaks today. blink.cmp v2 opens its init.lua with
-- error("blink.cmp v2 requires nvim 0.12+"), but v2 is unreleased, so the `version = "*"`
-- in plugins/dev/lsp.lua resolves to v1.10.2, which still runs on 0.10. That constraint is
-- unpinned: the moment upstream tags v2, a `:Lazy update` picks it up and a 0.11 dev machine
-- loses completion outright. So the floor stays 0.12 even if treesitter ever drops its own.
local MINIMUM_VERSIONS = {
  shared = {
    version = { major = 0, minor = 11, patch = 0 },
    reason = "vim.lsp.config and vim.lsp.enable",
  },
  dev = {
    version = { major = 0, minor = 12, patch = 0 },
    reason = "nvim-treesitter (main branch)",
  },
}

-- Missing tools only degrade one feature each, so every one is a warning and never an
-- error. Named one by one because "some tools are missing" does not tell you which to
-- install.
local OPTIONAL_EXECUTABLES = {
  { name = "fzf", reason = "fzf-lua pickers" },
  { name = "rg", reason = "live grep" },
  { name = "fd", reason = "file finding" },
  -- Homebrew splits these two: the binary lives in the `tree-sitter-cli` formula, while
  -- `tree-sitter` ships only the library. With no CLI on PATH nvim-treesitter's main
  -- branch installs no parser at all, and the pcall around vim.treesitter.start() hides
  -- it. Presence is asserted but not version, even though upstream wants >= 0.26.1:
  -- `--version` would spawn a process, which this file deliberately never does.
  { name = "tree-sitter", reason = "generating and building treesitter parsers" },
  { name = "cc", reason = "the C compilation step inside tree-sitter build" },
  -- Three names for one tool: mason's package and nvim-dap's adapter are both `delve`, only
  -- the binary is `dlv`, so the advice has to name the package -- asking for `dlv` finds
  -- nothing. executable() reads the PATH Neovim inherited from the shell that launched it,
  -- which is the very PATH nvim-dap will search, so a dlv sitting in a directory that PATH
  -- does not list is correctly reported missing. Warned about under both profiles, as
  -- tree-sitter and cc above are, though nothing dap-shaped loads outside dev.
  { name = "dlv", reason = "debugging Go with nvim-dap", install = "Run :Mason and install delve" },
}

local function check_version()
  -- init.lua sets this before anything else runs; "unknown" only shows up if this module
  -- is required outside the config, and then the shared floor is the safe one to assert.
  local profile = vim.g.dotfiles_nvim_profile or "unknown"
  local requirement = profile == "dev" and MINIMUM_VERSIONS.dev or MINIMUM_VERSIONS.shared
  local floor = ("%d.%d"):format(requirement.version.major, requirement.version.minor)
  local version = vim.version()
  local requires = ("profile %s requires %s for %s"):format(profile, floor, requirement.reason)

  if vim.version.lt(version, requirement.version) then
    vim.health.error(("Neovim %s is too old; %s"):format(tostring(version), requires))
  else
    vim.health.ok(("Neovim %s; %s"):format(tostring(version), requires))
  end
end

local function check_executables()
  for _, executable in ipairs(OPTIONAL_EXECUTABLES) do
    if vim.fn.executable(executable.name) == 1 then
      vim.health.ok(("%s found"):format(executable.name))
    else
      -- The default advice names the binary, which is right for anything a package manager
      -- ships under its own name. An entry overrides it when what you have to ask for is
      -- not called what the binary is called.
      local advice = executable.install or ("Install %s"):format(executable.name)
      vim.health.warn(("%s not found"):format(executable.name), {
        ("%s to enable %s."):format(advice, executable.reason),
      })
    end
  end
end

function M.check()
  vim.health.start("dotfiles: Neovim version")
  check_version()

  vim.health.start("dotfiles: optional external tools")
  check_executables()
end

return M
