return {
  {
    "mason-org/mason.nvim",
    lazy = false,
    opts = {
      ui = {
        icons = {
          package_pending = " ",
          package_installed = " ",
          package_uninstalled = " ",
        },
      },

      max_concurrent_installers = 10,
    },
  },
  {
    "mason-org/mason-lspconfig.nvim",
    lazy = false,
    dependencies = { "mason-org/mason.nvim" },
    opts = {
      ensure_installed = { "ts_ls", "gopls", "lua_ls", "jsonls" },
    },
  },
  {
    "WhoIsSethDaniel/mason-tool-installer.nvim",
    lazy = false,
    dependencies = { "mason-org/mason.nvim" },
    opts = {
      ensure_installed = { "prettierd", "stylua", "gofumpt", "goimports-reviser", "golines" },
      auto_update = false,
      run_on_start = true,
    },
  },
  {
    "neovim/nvim-lspconfig",
    lazy = false,
    config = function()
      local servers = { "gopls", "ts_ls", "lua_ls", "jsonls" }
      vim.lsp.enable(servers)

      vim.lsp.config("gopls", {
        settings = {
          completeUnimported = true,
          usePlaceholders = true
        }
      })

      vim.lsp.config("ts_ls", {
        filetypes = { "typescript", "typescriptreact", "javascript", "javascriptreact" },
        cmd = { "typescript-language-server", "--stdio" }, -- Command to start the server
        settings = {
          -- Optional: Configure the server to find the nearest project root (package.json or tsconfig.json)
          -- This helps with monorepos and mixed JS/TS projects
          -- You may need to use an adapter like tsgo for optimal monorepo support
          -- Example setting:
          -- tsserver = {
          --     root_dir = lspconfig.util.root_finder({ "tsconfig.json", "package.json" }, { upward = true })(),
          -- }
        },
      })

      vim.lsp.config("lua_ls", {
        settings = {
          Lua = {
            runtime = {
              version = "LuaJIT",
            },
            diagnostics = {
              globals = { "vim" },
            },
            workspace = {
              library = vim.api.nvim_get_runtime_file("", true),
              checkThirdParty = false,
            },
            telemetry = {
              enable = false,
            },
          },
        },
      })

      vim.lsp.config("jsonls", {
        settings = {
          json = {
            schemas = require("schemastore").json.schemas(),
            validate = { enable = true },
          },
        },
      })

      local map = vim.keymap.set
      map("n", "K", vim.lsp.buf.hover, {})
      map("n", "gD", vim.lsp.buf.declaration, { desc = "LSP: go to declaration" })
      map("n", "gd", vim.lsp.buf.definition, { desc = "LSP: Go to definition" })
      -- vim.keymap.set("n", "<leader>gd", vim.lsp.buf.definition, {})
      -- vim.keymap.set("n", "<leader>gr", vim.lsp.buf.references, {})
      -- vim.keymap.set("n", "<leader>ca", vim.lsp.buf.code_action, {})
    end,
  },
}
