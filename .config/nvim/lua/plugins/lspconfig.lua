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
      ensure_installed = { "ts_ls", "gopls", "lua_ls", "jsonls", "yamlls", "hyprls", "rust_analyzer" },
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
      local servers = { "gopls", "ts_ls", "lua_ls", "jsonls", "yamlls", "hyprls", "rust_analyzer" }
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
              globals = { "vim", "hl" },
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

      vim.lsp.config("yamlls", {
        settings = {
          yaml = {
            schemas = require("schemastore").yaml.schemas(),
            validate = true,
          },
        },
      })

      vim.lsp.config("hyprls", {
        cmd = { "hyprls", "--stdio" },
      })

      vim.lsp.config("rust_analyzer", {
        settings = {
          ["rust-analyzer"] = {
            check = {
              -- clippy is a superset of `cargo check` (rustc diagnostics + lints)
              command = "clippy",
              checkOnSave = true,
            },
          },
        },
      })

      local map = vim.keymap.set
      -- Hover first; on code with compile errors rust-analyzer returns no (or
      -- an empty) hover, so fall back to the diagnostic — under the cursor if
      -- there is one, else on the whole line.
      local function hover_is_empty(result)
        if not result then
          return true
        end
        local contents = result.contents
        if type(contents) == "string" then
          return contents == ""
        end
        return vim.tbl_isempty(contents or {})
      end

      local function show_diagnostic_fallback()
        -- scope = "cursor" needs a diagnostic exactly under the cursor; if
        -- there is none, widen to the line.
        if vim.diagnostic.open_float({ scope = "cursor" }) == nil then
          vim.diagnostic.open_float({ scope = "line" })
        end
      end

      map("n", "K", function()
        local clients = vim.lsp.get_clients({ bufnr = 0 })
        if #clients == 0 then
          return show_diagnostic_fallback()
        end
        local params = vim.lsp.util.make_position_params(0, clients[1].offset_encoding)
        vim.lsp.buf_request(0, "textDocument/hover", params, function(err, result)
          if err or hover_is_empty(result) then
            show_diagnostic_fallback()
          else
            vim.lsp.buf.hover()
          end
        end)
      end, { desc = "LSP: hover, or diagnostic under cursor" })
      map("n", "gD", vim.lsp.buf.declaration, { desc = "LSP: go to declaration" })
      map("n", "gd", vim.lsp.buf.definition, { desc = "LSP: Go to definition" })
      -- vim.keymap.set("n", "<leader>gd", vim.lsp.buf.definition, {})
      -- vim.keymap.set("n", "<leader>gr", vim.lsp.buf.references, {})
      map("n", "<leader>ca", vim.lsp.buf.code_action, { desc = "LSP: code action" })
    end,
  },
}
