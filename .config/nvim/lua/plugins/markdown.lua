return {
  "MeanderingProgrammer/render-markdown.nvim",
  ft = "markdown",
  dependencies = { "nvim-treesitter/nvim-treesitter" },
  opts = {
    preset = "obsidian", -- mimic Obsidian UI (colored headings, hidden markup)
    -- Plugin enables this by default; disable to keep normal mode fully rendered
    anti_conceal = { enabled = false },
    -- Preview in normal mode, raw markdown in insert mode
    render_modes = { "n", "no", "c" },
    -- No soft wrap in preview: it fragments rendered tables (virtual text can't
    -- wrap, see plugin doc/limitations.md). Toggle per buffer with :setlocal wrap
    win_options = {
      wrap = { default = vim.o.wrap, rendered = false },
    },
    -- Padded cells = aligned columns and a proper table look; wide tables scroll
    -- horizontally instead of wrapping
    pipe_table = {
      cell = "padded",
    },

    -- ── Spacing (glow-like layout) ───────────────────────────
    heading = {
      position = "inline", -- blank virtual line above headings
      border = true, -- extra separation above/below
      left_pad = 1,
    },
    dash = {
      width = "full", -- full-width horizontal rule, like glow
    },
    code = {
      left_margin = 10, -- inset from the left edge, like glow's code blocks
      left_pad = 2,
      right_pad = 2,
      min_width = 60, -- code blocks stay wide even for short snippets
      border = "thick", -- rounded corners like glow
    },
    bullet = {
      left_pad = 1,
      right_pad = 1,
    },
    checkbox = {
      left_pad = 1,
      right_pad = 2,
    },
    paragraph = {
      left_margin = 2,
    },
  },
}
