require("nvchad.configs.lspconfig").defaults()

local servers = { "html", "cssls", "gopls" }
vim.lsp.enable(servers)

vim.lsp.config("gopls", {
  settings = {
    completeUnimported = true,
    usePlaceholders = true,
  },
})
-- read :h vim.lsp.config for changing options of lsp servers
