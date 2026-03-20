return {
	"vim-test/vim-test",
	dependencies = {
		"preservim/vimux",
	},
	init = function()
		vim.cmd("let test#strategy = 'vimux'")
	end,
	keys = {
		-- { "<leader>t", ":TestNearest<CR>", desc = "Test nearest" },
		-- { "<leader>T", ":TestFile<CR>", desc = "Test file" },
		-- { "<leader>a", ":TestSuite<CR>", desc = "Test suite" },
		-- { "<leader>l", ":TestLast<CR>", desc = "Test last" },
		-- { "<leader>g", ":TestVisit<CR>", desc = "Test visit" },
	},
}
