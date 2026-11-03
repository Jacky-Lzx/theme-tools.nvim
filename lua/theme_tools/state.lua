local M = {}

function M.read(path)
  if vim.fn.filereadable(path) == 0 then
    return nil
  end
  local ok, data = pcall(function()
    return vim.json.decode(table.concat(vim.fn.readfile(path), "\n"))
  end)
  if not ok or type(data) ~= "table" or type(data.name) ~= "string" then
    return nil, "Invalid theme state: " .. path
  end
  return data.name
end

function M.write(path, name)
  -- Startup restoration and repeated confirmations need no disk write. Read
  -- the file each time so a choice saved by another instance is still replaced.
  if M.read(path) == name then
    return true
  end
  local temporary = path .. ".tmp." .. vim.uv.os_getpid()
  local ok, err = pcall(function()
    vim.fn.mkdir(vim.fn.fnamemodify(path, ":h"), "p")
    if vim.fn.writefile({ vim.json.encode({ name = name }) }, temporary) ~= 0 then
      error("Cannot write " .. temporary)
    end
    local renamed, reason = vim.uv.fs_rename(temporary, path)
    if not renamed then
      error(reason)
    end
  end)
  if not ok then
    vim.fn.delete(temporary)
    return nil, tostring(err)
  end
  return true
end

return M
