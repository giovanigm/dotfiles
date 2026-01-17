require "nvchad.autocmds"

-- Set CWD to the directory of the file passed as an argument on startup
vim.api.nvim_create_autocmd("VimEnter", {
  pattern = "*",
  callback = function()
    -- Check if exactly one argument (a file) was provided on the command line
    if vim.fn.argc() == 1 then
      -- Set the current directory to the parent directory of the expanded filename
      vim.api.nvim_set_current_dir(vim.fn.expand("%:p:h"))
    end
  end
})

-- Highlight when yanking (copying) text
--  Try it with `yap` in normal mode
--  See `:help vim.hl.on_yank()`
vim.api.nvim_create_autocmd('TextYankPost', {
  desc = 'Highlight when yanking (copying) text',
  group = vim.api.nvim_create_augroup('kickstart-highlight-yank', { clear = true }),
  callback = function()
    vim.hl.on_yank()
  end,
})
