local M = {}

-- TeX syntax colors come from Tree-sitter; semantic tokens retain variable identity.
-- These groups are compiled into independent schemes and reused by palette variants.
function M.groups()
  local groups = {}
  local types = { "macro", "variable", "type", "enumMember", "string", "comment", "property", "number", "operator" }
  for _, ft in ipairs({ "tex", "plaintex" }) do
    for _, kind in ipairs(types) do
      groups["@lsp.type." .. kind .. "." .. ft] = kind == "variable" and { link = "@variable" } or {}
      groups["@lsp.typemod." .. kind .. ".declaration." .. ft] = {}
    end
    groups["@lsp.mod.declaration." .. ft] = {}
  end
  return groups
end

return M
