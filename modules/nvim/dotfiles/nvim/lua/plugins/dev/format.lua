-- json_repair says "there was no JSON in here to recover" by printing the empty JSON string
-- `""` and exiting 0. conform reads exit 0 as a format that worked and writes stdout into the
-- buffer, so a `json` buffer holding prose came back as one line reading `""` -- destroyed,
-- undoably, but destroyed. conform does refuse output that is blank, and `""` is not blank;
-- past that it offers nothing that can see a command formatter's output, since `condition`
-- runs before the command and `exit_codes` has no code to reject when the tool exits 0. So
-- json_repair is run from here as a Lua formatter, `format` being the one hook conform calls
-- with the result in hand and the choice of whether to hand it back.
--
-- Only that one sentinel is refused. A trailing comma, an unclosed brace, a comment, single
-- quotes and JSON lifted out of a log line all still come back as real JSON and are still
-- written: the test is "the formatter recovered nothing", not "the input was malformed",
-- which is the whole reason json_repair is the formatter here rather than jq.
local function format_json(_, ctx, lines, callback)
  vim.system({
    "json_repair",
    -- json_repair's own default indent is a fixed 2, which makes <leader>cf silently
    -- disagree with every other formatter here about what an indent is. conform resolves
    -- ctx.shiftwidth per buffer and already falls back to tabstop when shiftwidth is 0.
    "--indent",
    tostring(ctx.shiftwidth),
  }, {
    stdin = table.concat(lines, "\n"),
    text = true,
  }, vim.schedule_wrap(function(result)
    if result.code ~= 0 then
      local stderr = vim.trim(result.stderr or "")
      return callback(stderr ~= "" and stderr or ("exited with %d"):format(result.code))
    end

    -- The trailing newline is the last line's ending, not a line of its own.
    local output = vim.split((result.stdout or ""):gsub("\n$", ""), "\n")
    if #output == 1 and vim.trim(output[1]) == '""' then
      -- Reported rather than swallowed: conform turns this into its own "Formatter failed.
      -- See :ConformInfo for details", where this line is what is waiting. A buffer that
      -- silently stays exactly as it was is the failure this surface was added to fix.
      return callback("no JSON to recover in this buffer")
    end
    callback(nil, output)
  end))
end

return {
  {
    "stevearc/conform.nvim",
    lazy = true,
    keys = {
      {
        "<leader>cf",
        function()
          require("conform").format({ async = true, lsp_format = "fallback" })
        end,
        desc = "Format buffer",
      },
    },
    opts = {
      formatters_by_ft = require("lang").formatters_by_ft(),
      default_format_opts = { lsp_format = "fallback" },
      formatters = {
        json_repair = {
          -- Nothing left to inherit: conform's builtin json_repair is a `command`, and a
          -- config holding both a command and a format runs the format and leaves the
          -- command sitting there as something no one calls.
          inherit = false,
          -- With no `command` there is nothing for conform to look for on PATH, and this
          -- repo deliberately does not install json_repair. Without this check a machine
          -- without it would get an error on every <leader>cf in a JSON buffer instead of
          -- the silent no-op the registry documents.
          condition = function()
            return vim.fn.executable("json_repair") == 1
          end,
          format = format_json,
        },
      },
    },
  },
}
