---@diagnostic disable-next-line: undefined-global
local vim = vim

require('tmux-test').setup()

-- mのキーマッピングを設定（10個のセッション表示）
vim.keymap.set('n', 'm', function()
  require('tmux-test').show_multiple_sessions()
end, { desc = 'Show 10 tmux sessions in grid layout' })