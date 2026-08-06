-- Filetype detection for Hyprland ecosystem configs.
vim.filetype.add({
  filename = {
    ["hyprland.conf"] = "hyprlang",
    ["hyprlock.conf"] = "hyprlang",
    ["hypridle.conf"] = "hyprlang",
  },
  pattern = {
    ["/hypr/.*%.conf"] = "hyprlang",
  },
})
