return {
  "nvim-treesitter/nvim-treesitter",
  event = { "BufReadPost", "BufNewFile" },
  cmd = { "TSInstall", "TSBufEnable", "TSBufDisable", "TSModuleInfo" },
  build = ":TSUpdate",
  main = "nvim-treesitter.config",
  opts = {
    auto_install = true,
    highlight = { enable = true },
    indent = { enable = true },
  },
}
