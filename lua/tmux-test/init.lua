---@diagnostic disable-next-line: undefined-global
local vim = vim

local M = {}

-- グローバル変数でウィンドウを管理
M.floating_windows = {}

function M.show_multiple_sessions()
  -- 既存のフローティングウィンドウをクリア
  for _, win in ipairs(M.floating_windows) do
    if vim.api.nvim_win_is_valid(win) then
      vim.api.nvim_win_close(win, true)
    end
  end
  M.floating_windows = {}
  
  -- 10個のセッション名
  local sessions = {}
  for i = 1, 10 do
    table.insert(sessions, "claude" .. i)
  end
  
  -- 各セッションの作成
  for _, session_name in ipairs(sessions) do
    local check_cmd = string.format("tmux has-session -t %s 2>/dev/null", session_name)
    vim.fn.system(check_cmd)
    if vim.v.shell_error ~= 0 then
      local create_cmd = string.format("tmux new-session -d -s %s", session_name)
      vim.fn.system(create_cmd)
    end
  end
  
  -- ウィンドウレイアウト計算（2行5列）
  local total_width = vim.o.columns
  local total_height = vim.o.lines
  local cols_count = 5
  local rows_count = 2
  local win_width = math.floor(total_width / cols_count) - 1
  local win_height = math.floor(total_height / rows_count) - 2
  
  -- 各セッションのウィンドウを作成
  for idx, session_name in ipairs(sessions) do
    local row_idx = math.floor((idx - 1) / cols_count)
    local col_idx = (idx - 1) % cols_count
    local row = row_idx * (win_height + 1)
    local col = col_idx * (win_width + 1)
    
    local buf = vim.api.nvim_create_buf(false, true)
    local win_opts = {
      relative = 'editor',
      width = win_width,
      height = win_height,
      row = row,
      col = col,
      style = 'minimal',
      border = 'single',
      title = ' ' .. session_name .. ' ',
      title_pos = 'center',
    }
    local win = vim.api.nvim_open_win(buf, false, win_opts)
    table.insert(M.floating_windows, win)

    -- ターミナルモードでtmuxアタッチ
    vim.api.nvim_win_call(win, function()
      local attach_cmd = string.format("tmux attach-session -t %s", session_name)
      vim.fn.termopen(attach_cmd)
    end)

    -- キーマップ設定
    vim.api.nvim_buf_set_keymap(buf, 'n', 'q', ':close<CR>',
      { noremap = true, silent = true })
    vim.api.nvim_buf_set_keymap(buf, 't', '<C-q>', '<C-\\><C-n>:close<CR>',
      { noremap = true, silent = true })
  end

  -- 最初のウィンドウにフォーカス
  if #M.floating_windows > 0 then
    vim.api.nvim_set_current_win(M.floating_windows[1])
  end
end

function M.setup()
  -- コマンド登録
  vim.api.nvim_create_user_command('TmuxMultiple', M.show_multiple_sessions, {})
end

return M
