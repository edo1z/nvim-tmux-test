---@diagnostic disable-next-line: undefined-global
local vim = vim

require('tmux-test').setup()

-- Mのキーマッピングを設定（通常ウィンドウ版、トグル）
vim.keymap.set('n', 'M', function()
  require('tmux-test.multiple').show_normal()
end, { desc = 'Toggle 10 tmux sessions in normal windows' })