---@diagnostic disable-next-line: undefined-global
local vim = vim

local M = {}

function M.setup()
  -- multipleモジュールの関数をエクスポート
  local multiple = require('tmux-test.multiple')
  M.show_normal = multiple.show_normal

  -- コマンド登録
  vim.api.nvim_create_user_command('TmuxMultipleNormal', multiple.show_normal, {})
end

return M
