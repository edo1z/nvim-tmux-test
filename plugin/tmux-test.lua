---@diagnostic disable-next-line: undefined-global
local vim = vim

require('tmux-test').setup()

-- <leader>Lのキーマッピングを設定
vim.keymap.set('n', '<leader>L', function()
  require('tmux-test').show_tmux_session()
end, { desc = 'Show tmux session in floating window' })