local autocmd = vim.api.nvim_create_autocmd

-- user event that loads after UIEnter + only if file buf is there
autocmd({ "UIEnter", "BufReadPost", "BufNewFile" }, {
	group = vim.api.nvim_create_augroup("NvFilePost", { clear = true }),
	callback = function(args)
		local file = vim.api.nvim_buf_get_name(args.buf)
		local buftype = vim.api.nvim_get_option_value("buftype", { buf = args.buf })

		if not vim.g.ui_entered and args.event == "UIEnter" then
			vim.g.ui_entered = true
		end

		if file ~= "" and buftype ~= "nofile" and vim.g.ui_entered then
			vim.api.nvim_exec_autocmds("User", { pattern = "FilePost", modeline = false })
			vim.api.nvim_del_augroup_by_name("NvFilePost")

			vim.schedule(function()
				vim.api.nvim_exec_autocmds("FileType", {})

				if vim.g.editorconfig then
					require("editorconfig").config(args.buf)
				end
			end)
		end
	end,
})

autocmd("FileType", {
	pattern = "*",
	callback = function()
		pcall(vim.treesitter.start)
	end,
})

local create_cmd = vim.api.nvim_create_user_command

create_cmd("TSInstallAll", function()
	local spec = require("lazy.core.config").plugins["nvim-treesitter"]
	local opts = type(spec.opts) == "table" and spec.opts or {}
	require("nvim-treesitter").install(opts.ensure_installed)
end, {})

-- -- Set CWD to the directory of the file passed as an argument on startup
-- autocmd("VimEnter", {
-- 	pattern = "*",
-- 	callback = function()
-- 		-- Check if exactly one argument (a file) was provided on the command line
-- 		if vim.fn.argc() == 1 then
-- 			-- Set the current directory to the parent directory of the expanded filename
-- 			vim.api.nvim_set_current_dir(vim.fn.expand("%:p:h"))
-- 		end
-- 	end,
-- })

-- Highlight when yanking (copying) text
--  Try it with `yap` in normal mode
--  See `:help vim.hl.on_yank()`
autocmd("TextYankPost", {
	desc = "Highlight when yanking (copying) text",
	group = vim.api.nvim_create_augroup("kickstart-highlight-yank", { clear = true }),
	callback = function()
		vim.hl.on_yank()
	end,
})

-- -- Show alpha when no buffers are left
-- autocmd("BufEnter", {
-- 	callback = function()
-- 		local bufs = vim.fn.getbufinfo({ buflisted = 1 })
-- 		local is_empty = vim.api.nvim_buf_get_name(0) == ""
-- 		if is_empty and #bufs == 0 then
-- 			vim.schedule(function()
-- 				local alpha = require("alpha")
-- 				local dashboard = require("alpha.themes.dashboard")
-- 				alpha.start(false, dashboard.config)
-- 			end)
-- 		end
-- 	end,
-- })

-- Close references on select
autocmd("FileType", {
	pattern = "qf",
	callback = function()
		vim.keymap.set("n", "<CR>", "<CR>:cclose<CR>", { buffer = true, silent = true })
	end,
})
