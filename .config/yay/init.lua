-- yay init.lua — security hooks for AUR package auditing
-- https://github.com/Jguer/yay

local known_domains = {
  "github.com", "gitlab.com", "bitbucket.org", "codeberg.org", "git.sr.ht",
  "dl.google.com", "code.claude.com", "downloads.claude.ai", "dl.pstmn.io",
  "rubygems.org", "pypi.org", "registry.npmjs.org", "launchpad.net",
  "repository.spotify.com", "update.code.visualstudio.com",
  "releases.mozilla.org", "ftp.gnu.org", "cdn.openbsd.org",
  "ventoy.net", "asdf-vm.com", "brave.com", "getpostman.com",
  "spotify.com", "code.visualstudio.com", "anthropic.com", "heroku.com",
  "fastlane.tools", "developer.android.com", "nodejs.org",
  "kernel.org", "freedesktop.org", "gnome.org", "kde.org",
  "qt.io", "x.org", "openbsd.org", "debian.org", "canonical.com",
  "archlinux.org",
}

--- Danger patterns that abort install ---
local function check_danger(pkgbuild, pkgbase)
  local patterns = {
    { pat = "curl[^%(%)]-|%s-[ba]sh",    name = "curl | bash/sh" },
    { pat = "wget[^%(%)]-|%s-[ba]sh",    name = "wget | bash/sh" },
    { pat = "rm%s+-rf%s+/[^u]",          name = "rm -rf / (not /usr)" },
    { pat = "chmod%s+777",               name = "chmod 777" },
    { pat = "chmod%s+-R%s+777",          name = "chmod -R 777" },
    { pat = "useradd",                   name = "useradd in PKGBUILD" },
    { pat = "usermod",                   name = "usermod in PKGBUILD" },
    { pat = "/tmp/.-%.sh",              name = "shell script in /tmp" },
  }

  for _, rule in ipairs(patterns) do
    if string.find(pkgbuild, rule.pat) then
      return true, rule.name
    end
  end
  return false
end

--- Scan for warnings (just log) ---
local function check_warnings(pkgbuild, pkgbase)
  -- SKIP checksums
  local skips = {}
  for line in string.gmatch(pkgbuild, "([^\n]*SKIP[^\n]*)") do
    if string.find(line, "sha%d*sum") or string.find(line, "checksum") then
      table.insert(skips, line)
    end
  end
  if #skips > 0 then
    yay.log.warn(pkgbase .. ": " .. #skips .. " SKIP checksum(s) found")
  end

  -- Check for source URLs from unfamiliar domains (non-comment lines only)
  local seen = {}
  for line in string.gmatch(pkgbuild, "[^\n]+") do
    if not string.find(line, "^%s*#") then
      for url in string.gmatch(line, "https?://([%w%.%-]+)") do
        if not seen[url] then
          seen[url] = true
          local known = false
          for _, domain in ipairs(known_domains) do
            if url == domain or string.find(url, "%." .. domain .. "$") then
              known = true
              break
            end
          end
          if not known then
            yay.log.warn(pkgbase .. ": unfamiliar domain: " .. url)
          end
        end
      end
    end
  end

  -- No source array at all
  if not string.find(pkgbuild, "source_?%w*=%s*%(") then
    yay.log.warn(pkgbase .. ": no source array found")
  end
end

--- Scan .install file if present ---
local function check_install_file(dir, pkgbase)
  local handle = io.popen("find " .. dir .. " -maxdepth 1 -name '*.install' 2>/dev/null | head -1")
  if not handle then return end
  local install_file = handle:read("*a"):gsub("\n$", "")
  handle:close()
  if install_file == nil or install_file == "" then return end

  local f = io.open(install_file, "r")
  if not f then return end
  local body = f:read("*a")
  f:close()

  local patterns = {
    { pat = "curl",         name = "network call in .install" },
    { pat = "wget",         name = "network call in .install" },
    { pat = "eval",         name = "eval in .install" },
    { pat = "/tmp/.-%.sh", name = "shell script in /tmp" },
    { pat = "rm%s+-rf%s+/[^u]", name = "rm -rf / in .install" },
    { pat = "chmod%s+777",  name = "chmod 777 in .install" },
  }
  for _, rule in ipairs(patterns) do
    if string.find(body, rule.pat) then
      yay.log.warn(pkgbase .. ": " .. rule.name .. " (" .. install_file .. ")")
    end
  end
end

--- AURPreInstall: PKGBUILD scan before anything runs ---
yay.create_autocmd("AURPreInstall", {
  desc = "Security audit: abort on dangerous PKGBUILD patterns",
  callback = function(event)
    local data = event.data
    yay.log.info("[aur-audit] scanning " .. data.base)

    local dangerous, what = check_danger(data.pkgbuild, data.base)
    if dangerous then
      yay.log.error(data.base .. ": DANGER — " .. what)
      yay.abort(data.base .. ": blocked by security hook: " .. what ..
                "\nReview: " .. data.pkgbuild_path)
    end

    check_warnings(data.pkgbuild, data.base)
    check_install_file(data.dir, data.base)

    -- Flag PKGBUILD modified in last 24h
    local now = os.time()
    if data.last_modified > 0 and (now - data.last_modified) < 86400 then
      yay.log.warn(data.base .. ": PKGBUILD modified in last 24h — review carefully")
    end
  end,
})

--- AURPostDownload: re-scan after source files land ---
yay.create_autocmd("AURPostDownload", {
  desc = "Re-scan after source download, before build",
  callback = function(event)
    local data = event.data
    yay.log.info("[aur-audit] re-scanning " .. data.base .. " (post-download)")

    local dangerous, what = check_danger(data.pkgbuild, data.base)
    if dangerous then
      yay.log.error(data.base .. ": DANGER — " .. what)
      yay.abort(data.base .. ": blocked by security hook: " .. what)
    end
  end,
})

--- UpgradeSelect: warn about recently modified AUR packages ---
yay.create_autocmd("UpgradeSelect", {
  desc = "Warn about AUR packages modified in last 3 days",
  callback = function(event)
    local recent_cutoff = os.time() - (3 * 24 * 60 * 60)
    for _, pkg in ipairs(event.data.upgrades) do
      if pkg.repository == "aur" and pkg.last_modified >= recent_cutoff then
        yay.log.warn("recently modified: " .. pkg.name ..
                     " (" .. os.date("%Y-%m-%d", pkg.last_modified) .. ")")
      end
    end
  end,
})

--- PostInstall: audit log ---
yay.create_autocmd("PostInstall", {
  desc = "Log installed packages for audit trail",
  callback = function(event)
    for _, pkg in ipairs(event.data.packages) do
      local action = "installed"
      if pkg.local_version ~= "" then action = "upgraded" end
      yay.log.info(pkg.name .. " " .. pkg.version .. " " .. action .. " (" .. pkg.source .. ")")
    end
  end,
})
