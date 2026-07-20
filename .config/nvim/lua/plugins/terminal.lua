return {
	"akinsho/toggleterm.nvim",
	opts = {
		direction = "float",
		float_opts = {
			border = "curved",
		},
	},
	keys = {
		{
			"<A-t>",
			function()
				local root = vim.fs.root(0, {
					".git",
					"package.json",
					"deps.edn",
					"project.clj",
					"pyproject.toml",
					"setup.py",
					"setup.cfg",
					"Makefile",
					"go.work",
					"go.mod",
					"pom.xml",
					"build.gradle",
					"build.gradle.kts",
					"settings.gradle",
					"settings.gradle.kts",
					"gradlew",
					"pubspec.yaml",
				})
				local dir = root or vim.fn.getcwd()
				require("toggleterm").toggle(vim.v.count1, nil, dir, "float")
			end,
			desc = "Toggle terminal",
		},
		{ "<A-t>", "<cmd>ToggleTerm<CR>", mode = "t", desc = "Toggle terminal" },
	},
}
