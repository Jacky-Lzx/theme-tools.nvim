local M = {}

local function ready(path, source)
  local marker = path .. "/.theme-tools-commit"
  return vim.fn.filereadable(path .. "/" .. source.entrypoint) == 1
    and vim.fn.filereadable(marker) == 1
    and vim.fn.readfile(marker)[1] == source.commit
end

-- Install immutable revisions outside the plugin checkout. Only a complete
-- checkout is published, so interrupted downloads never become loadable themes.
function M.ensure(source, opts)
  assert(source.name:match("^[%w_-]+$"), "invalid managed source name")
  assert(#source.commit == 40 and source.commit:match("^%x+$"), "managed sources require a full commit SHA")
  local parent = vim.fs.joinpath(vim.fn.fnamemodify(vim.fn.expand(opts.root), ":p"), source.name)
  local path = parent .. "/" .. source.commit
  if ready(path, source) then
    return path
  end
  if vim.uv.fs_stat(path) then
    return nil, "Incomplete managed source: " .. path .. ". Remove this directory and retry installation"
  end
  if vim.fn.executable("git") ~= 1 then
    return nil, "Git is required to download " .. source.name
  end
  local temporary = path .. ".tmp." .. vim.uv.os_getpid() .. "." .. tostring(vim.uv.hrtime())
  local created = false
  local deadline = vim.uv.hrtime() + opts.timeout * 1e6
  local function run(args)
    local remaining = math.floor((deadline - vim.uv.hrtime()) / 1e6)
    if remaining <= 0 then
      error("Source download timed out")
    end
    local result = vim
      .system(args, {
        cwd = temporary,
        text = true,
        env = { GIT_TERMINAL_PROMPT = "0" },
      })
      :wait(remaining)
    if result.code == 124 then
      error("Source download timed out after " .. opts.timeout .. " ms")
    end
    if result.code ~= 0 then
      error((result.stderr or "") .. (result.stdout or "") .. " (exit " .. result.code .. ")")
    end
    return vim.trim(result.stdout or "")
  end
  local ok, err = pcall(function()
    vim.fn.mkdir(parent, "p")
    assert(vim.uv.fs_mkdir(temporary, 448))
    created = true
    run({ "git", "init", "--quiet" })
    run({ "git", "remote", "add", "origin", source.url })
    run({ "git", "fetch", "--quiet", "--depth=1", "--no-tags", "origin", source.commit })
    run({ "git", "checkout", "--quiet", "--detach", "FETCH_HEAD" })
    assert(run({ "git", "rev-parse", "HEAD" }) == source.commit, "Downloaded source revision does not match")
    assert(vim.fn.filereadable(temporary .. "/" .. source.entrypoint) == 1, "Source entrypoint is missing")
    assert(vim.fn.writefile({ source.commit }, temporary .. "/.theme-tools-commit") == 0)
    local renamed, reason = vim.uv.fs_rename(temporary, path)
    -- Another Neovim may have completed the same install in the meantime.
    if not renamed then
      assert(ready(path, source), reason)
    end
  end)
  if created and vim.uv.fs_stat(temporary) then
    vim.fn.delete(temporary, "rf")
  end
  if not ok then
    return nil, "Failed to download " .. source.name .. ": " .. tostring(err)
  end
  return path
end

-- Resolve an explicit update to an immutable revision before installing it.
function M.latest(source, opts)
  if vim.fn.executable("git") ~= 1 then
    return nil, "Git is required to update " .. source.name
  end
  local ref = source.ref or "HEAD"
  local result = vim
    .system({ "git", "ls-remote", "--exit-code", source.url, ref }, {
      text = true,
      env = { GIT_TERMINAL_PROMPT = "0" },
    })
    :wait(opts.timeout)
  if result.code ~= 0 then
    return nil, "Failed to resolve " .. source.name .. ": " .. (result.stderr or "") .. " (exit " .. result.code .. ")"
  end
  local commit = (result.stdout or ""):match("^(%x+)%s")
  if not commit or #commit ~= 40 then
    return nil, "Invalid remote revision for " .. source.name
  end
  return commit
end

return M
