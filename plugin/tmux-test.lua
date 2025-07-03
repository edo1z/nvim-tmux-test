---@diagnostic disable-next-line: undefined-global
local vim = vim

require('tmux-test').setup()

-- <leader>LRのキーマッピングを設定（読み取り専用）
vim.keymap.set('n', '<leader>LR', function()
  require('tmux-test').show_tmux_session()
end, { desc = 'Show tmux session in floating window (read-only)' })

-- <leader>LIのキーマッピングを設定（インタラクティブ）
vim.keymap.set('n', '<leader>LI', function()
  require('tmux-test').show_tmux_interactive()
end, { desc = 'Show tmux session in floating window (interactive)' })