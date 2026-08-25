-- JSON is here for the formatter and nothing else: no `server` key, so it stays out of
-- M.server_filetypes() and a .json buffer loads neither lspconfig nor mason, and no `debug`
-- key, so it stays out of M.debug_filetypes() too.
--
-- json_repair rather than jq: what gets pasted into a JSON buffer is routinely a fragment
-- lifted out of a log line, or has a trailing comma or an unclosed brace, and jq exits 5 on
-- every one of those, which is a <leader>cf that does nothing. Its args are overridden in
-- plugins/dev/format.lua so the indent follows the buffer's shiftwidth.
--
-- It is deliberately not installed by this repo, so a machine without it on PATH gets a
-- silent no-op from conform.
return {
  formatters = { "json_repair" },
}
