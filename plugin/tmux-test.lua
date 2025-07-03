---@diagnostic disable-next-line: undefined-global
local vim = vim

require('tmux-test').setup()

-- mのキーマッピングを設定（フローティングウィンドウ版、トグル）
vim.keymap.set('n', 'm', function()
  require('tmux-test.multiple').show_floating()
end, { desc = 'Toggle 10 tmux sessions in floating windows' })

-- Mのキーマッピングを設定（通常ウィンドウ版、トグル）
vim.keymap.set('n', 'M', function()
  require('tmux-test.multiple').show_normal()
end, { desc = 'Toggle 10 tmux sessions in normal windows' })