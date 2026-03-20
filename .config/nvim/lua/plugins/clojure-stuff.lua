return {
	"tpope/vim-dispatch",
	"radenling/vim-dispatch-neovim",
	"clojure-vim/vim-jack-in",
	{
		"Olical/conjure", -- etc
		ft = { "clojure", "fennel" },
		lazy = true,
		init = function()
			vim.g["conjure#client#clojure#nrepl#test#current_form_names"] =
				{ "deftest", "defflow", "defspec", "describe" }
		end,
	},
}
