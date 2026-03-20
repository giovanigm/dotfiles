return {
	"nvim-lualine/lualine.nvim",
	dependencies = {
		"nvim-tree/nvim-web-devicons",
		{
			"linrongbin16/lsp-progress.nvim",
			opts = {
				series_format = function(title, message, percentage, done)
					if done or not percentage then
						return nil
					end
					return string.format("%.0f%%", percentage)
				end,
				client_format = function(client_name, spinner, series_messages)
					if #series_messages == 0 then
						return nil
					end
					return string.format("%s (%s)", client_name, series_messages[1])
				end,
			},
		},
	},
	config = function()
		-- Refresh lualine when LSP progress updates
		vim.api.nvim_create_augroup("lualine_lsp_progress", { clear = true })
		vim.api.nvim_create_autocmd("User", {
			group = "lualine_lsp_progress",
			pattern = "LspProgressStatusUpdated",
			callback = require("lualine").refresh,
		})

		require("lualine").setup({
			options = {
				section_separators = "",
				component_separators = "",
			},
			sections = {
				lualine_c = {
					"filename",
					function()
						return require("lsp-progress").progress()
					end,
				},
			},
		})
	end,
}
