-- Transfer Lua configuration to another instance of the same Neovim executable.
-- Preserve shared tables and Lua closure upvalues without running them in the UI.
local M = {}

function M.encode(value)
  local objects, lines, count = {}, { "local objects = {}" }, 0
  local encode
  encode = function(item)
    local kind = type(item)
    if kind == "nil" or kind == "number" or kind == "boolean" then
      return tostring(item)
    elseif kind == "string" then
      return string.format("%q", item)
    end
    assert(kind == "table" or kind == "function", "preview cannot transfer " .. kind)
    if objects[item] then
      return objects[item]
    end
    count = count + 1
    local ref = "objects[" .. count .. "]"
    objects[item] = ref
    if kind == "table" then
      lines[#lines + 1] = ref .. " = {}"
      for key, field in pairs(item) do
        local left, right = encode(key), encode(field)
        lines[#lines + 1] = ref .. "[" .. left .. "] = " .. right
      end
    else
      assert(debug.getinfo(item, "S").what ~= "C", "preview cannot transfer a C function")
      lines[#lines + 1] = ref .. " = assert(loadstring(" .. string.format("%q", string.dump(item)) .. "))"
      local i = 1
      while true do
        local name, field = debug.getupvalue(item, i)
        if not name then
          break
        end
        local right = encode(field)
        lines[#lines + 1] = "debug.setupvalue(" .. ref .. ", " .. i .. ", " .. right .. ")"
        i = i + 1
      end
    end
    return ref
  end
  local root = encode(value)
  lines[#lines + 1] = "return " .. root
  return table.concat(lines, "\n")
end

return M
