---@diagnostic disable-next-line: undefined-global
local vim = vim

local M = {}

-- グローバル変数でウィンドウとステートを管理
M.floating_windows = {}
M.is_floating_open = false
M.is_normal_open = false
M.saved_layout = nil

-- 10個のセッション名を取得
local function get_session_names()
  local sessions = {}
  for i = 1, 10 do
    table.insert(sessions, "claude" .. i)
  end
  return sessions
end

-- セッションの作成
local function ensure_sessions_exist(sessions)
  for _, session_name in ipairs(sessions) do
    local check_cmd = string.format("tmux has-session -t %s 2>/dev/null", session_name)
    vim.fn.system(check_cmd)
    if vim.v.shell_error ~= 0 then
      local create_cmd = string.format("tmux new-session -d -s %s", session_name)
      vim.fn.system(create_cmd)
    end
  end
end

-- フローティングウィンドウ版を閉じる
function M.close_floating()
  for _, win in ipairs(M.floating_windows) do
    if vim.api.nvim_win_is_valid(win) then
      vim.api.nvim_win_close(win, true)
    end
  end
  M.floating_windows = {}
  M.is_floating_open = false
end

-- 通常ウィンドウ版を閉じる
function M.close_normal()
  if M.saved_layout then
    -- 保存されたレイアウトに戻す
    vim.cmd('silent! %bdelete!')
    vim.cmd(M.saved_layout)
    M.saved_layout = nil
  end
  M.is_normal_open = false
end

-- フローティングウィンドウ版（元の実装）
function M.show_floating()
  -- 既に開いている場合は閉じる
  if M.is_floating_open then
    M.close_floating()
    return
  end

  -- 通常ウィンドウ版が開いている場合は閉じる
  if M.is_normal_open then
    M.close_normal()
  end

  M.close_floating()  -- 既存のものをクリア

  local sessions = get_session_names()
  ensure_sessions_exist(sessions)

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

    -- フローティングウィンドウ間の移動
    vim.api.nvim_buf_set_keymap(buf, 't', '<C-w>h', 
      string.format('<C-\\><C-n>:lua require("tmux-test.multiple").move_to_floating_window("left", %d)<CR>', idx),
      { noremap = true, silent = true })
    vim.api.nvim_buf_set_keymap(buf, 't', '<C-w>l',
      string.format('<C-\\><C-n>:lua require("tmux-test.multiple").move_to_floating_window("right", %d)<CR>', idx),
      { noremap = true, silent = true })
    vim.api.nvim_buf_set_keymap(buf, 't', '<C-w>j',
      string.format('<C-\\><C-n>:lua require("tmux-test.multiple").move_to_floating_window("down", %d)<CR>', idx),
      { noremap = true, silent = true })
    vim.api.nvim_buf_set_keymap(buf, 't', '<C-w>k',
      string.format('<C-\\><C-n>:lua require("tmux-test.multiple").move_to_floating_window("up", %d)<CR>', idx),
      { noremap = true, silent = true })
  end

  -- 最初のウィンドウにフォーカス
  if #M.floating_windows > 0 then
    vim.api.nvim_set_current_win(M.floating_windows[1])
  end

  M.is_floating_open = true
end

-- フローティングウィンドウ間の移動関数
function M.move_to_floating_window(direction, current_idx)
  local cols_count = 5
  local target_idx = current_idx

  if direction == 'left' and (current_idx - 1) % cols_count > 0 then
    target_idx = current_idx - 1
  elseif direction == 'right' and (current_idx - 1) % cols_count < cols_count - 1 then
    target_idx = current_idx + 1
  elseif direction == 'up' and current_idx > cols_count then
    target_idx = current_idx - cols_count
  elseif direction == 'down' and current_idx <= cols_count then
    target_idx = current_idx + cols_count
  end

  if target_idx ~= current_idx and target_idx >= 1 and target_idx <= #M.floating_windows then
    local target_win = M.floating_windows[target_idx]
    if vim.api.nvim_win_is_valid(target_win) then
      vim.api.nvim_set_current_win(target_win)
      vim.cmd("startinsert")
    end
  end
end

-- 通常ウィンドウ版
function M.show_normal()
  -- 既に開いている場合は閉じる
  if M.is_normal_open then
    M.close_normal()
    return
  end

  -- フローティングウィンドウ版が開いている場合は閉じる
  if M.is_floating_open then
    M.close_floating()
  end

  local sessions = get_session_names()
  ensure_sessions_exist(sessions)

  -- 現在のレイアウトを保存
  M.saved_layout = vim.fn.winrestcmd()

  -- 既存のウィンドウを全て閉じる
  vim.cmd('only')

  -- 2行5列のレイアウトを作成
  -- まず横に5つ分割
  for i = 1, 4 do
    vim.cmd('vsplit')
  end

  -- 各列を2行に分割
  vim.cmd('wincmd t')  -- 左上に移動
  for col = 1, 5 do
    vim.cmd('split')
    if col < 5 then
      vim.cmd('wincmd l')  -- 次の列の上段へ
    end
  end

  -- 各ウィンドウでtmuxセッションを開く
  vim.cmd('wincmd t')  -- 左上に移動
  local win_idx = 1

  for row = 1, 2 do
    for col = 1, 5 do
      local session_name = sessions[win_idx]
      if session_name then
        -- 新しいバッファを作成してからターミナルを開く
        vim.cmd('enew')
        local attach_cmd = string.format("tmux attach-session -t %s", session_name)
        vim.fn.termopen(attach_cmd)

        -- バッファローカルなキーマップ
        local buf = vim.api.nvim_get_current_buf()
        vim.api.nvim_buf_set_keymap(buf, 't', '<C-q>', '<C-\\><C-n>:q<CR>',
          { noremap = true, silent = true })
      end

      win_idx = win_idx + 1

      -- 次のウィンドウへ移動
      if win_idx <= 10 then
        vim.cmd('wincmd w')
      end
    end
  end

  -- 左上のウィンドウに戻る
  vim.cmd('wincmd t')

  M.is_normal_open = true
end

return M
