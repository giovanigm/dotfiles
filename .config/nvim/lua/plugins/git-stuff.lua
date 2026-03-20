return {
	{
		"tpope/vim-fugitive",
		cmd = { "Git", "G" },
	},
	{
		"lewis6991/gitsigns.nvim",
		opts = {
			signs = {
				delete = { text = "󰍵" },
				changedelete = { text = "󱕖" },
			},
		},
		keys = {
			{ "<leader>gp", ":Gitsigns preview_hunk<CR>", desc = "Preview hunk" },
			{ "<leader>gt", ":Gitsigns toggle_current_line_blame<CR>", desc = "Toggle line blame" },
		},
	},
}
