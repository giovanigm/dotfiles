return {
	"romgrk/barbar.nvim",
	dependencies = {
		"lewis6991/gitsigns.nvim", -- OPTIONAL: for git status
		"nvim-tree/nvim-web-devicons", -- OPTIONAL: for file icons
	},
	init = function()
		vim.g.barbar_auto_setup = false
	end,
	opts = {
		exclude_ft = { "alpha" },
	},
	event = "BufReadPost",
	keys = {
		{ "<Tab>", "<cmd>BufferNext<CR>", desc = "Next buffer" },
		{ "<S-Tab>", "<cmd>BufferPrevious<CR>", desc = "Previous buffer" },
		{ "<leader>x", "<cmd>BufferClose<CR>", desc = "Close buffer" },
	},
	version = "^1.0.0", -- optional: only update when a new 1.x version is released
}
