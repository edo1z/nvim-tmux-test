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
  for idx, session_name in ipairs(sessions) do
    local check_cmd = string.format("tmux has-session -t %s 2>/dev/null", session_name)
    vim.fn.system(check_cmd)
    if vim.v.shell_error ~= 0 then
      local create_cmd = string.format("tmux new-session -d -s %s", session_name)
      vim.fn.system(create_cmd)
    end
    -- ウィンドウ名を設定
    local rename_cmd = string.format("tmux rename-window -t %s:0 'Claude%d'", session_name, idx)
    vim.fn.system(rename_cmd)
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
      -- new-session -Aオプションを使用（既存セッションにアタッチ、なければ作成）
    local attach_cmd = string.format("tmux new-session -A -s %s", session_name)
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
  -- まず2行に分割
  vim.cmd('split')
  
  -- 上段（1-5）を作成
  vim.cmd('wincmd k')  -- 上に移動
  for i = 1, 4 do
    vim.cmd('vsplit')
  end
  
  -- 下段（6-10）を作成
  vim.cmd('wincmd j')  -- 下に移動
  for i = 1, 4 do
    vim.cmd('vsplit')
  end
  
  -- ウィンドウサイズを均等に
  vim.cmd('wincmd =')
  
  -- ウィンドウ数を確認
  local win_count = #vim.api.nvim_list_wins()
  vim.notify(string.format("Total windows created: %d", win_count))
  
  -- 各ウィンドウでtmuxセッションを開く（上段から順に）
  vim.cmd('wincmd t')  -- 左上に移動
  
  -- 上段（claude1-5）
  for i = 1, 5 do
    local session_name = sessions[i]
    local current_win = vim.api.nvim_get_current_win()
    vim.notify(string.format("Processing %s in window %d", session_name, current_win))
    
    -- 新しいバッファを作成してからターミナルを開く
    vim.cmd('enew')
    -- new-session -Aオプションを使用（既存セッションにアタッチ、なければ作成）
    local attach_cmd = string.format("tmux new-session -A -s %s", session_name)
    local job_id = vim.fn.termopen(attach_cmd)
    
    -- バッファ名を設定（タブに表示される）
    vim.api.nvim_buf_set_name(0, session_name)
    
    -- バッファローカルなキーマップ
    local buf = vim.api.nvim_get_current_buf()
    vim.api.nvim_buf_set_keymap(buf, 't', '<C-q>', '<C-\\><C-n>:q<CR>',
      { noremap = true, silent = true })
    
    -- 行番号を非表示に
    vim.wo.number = false
    vim.wo.relativenumber = false
    vim.wo.signcolumn = 'no'
    
    if i < 5 then
      vim.cmd('wincmd l')  -- 右へ移動
      -- 短い遅延を追加
      vim.wait(50)
    end
  end
  
  -- 下段へ移動（claude6-10）
  -- 左上に戻ってから下に移動することで確実に左下に移動
  vim.cmd('wincmd t')  -- 左上に移動
  vim.cmd('wincmd j')  -- 下に移動（左下へ）
  -- 現在のウィンドウIDを確認
  local initial_win = vim.api.nvim_get_current_win()
  vim.notify(string.format("Initial window for bottom row: %d", initial_win))
  
  for i = 6, 10 do
    local session_name = sessions[i]
    local current_win = vim.api.nvim_get_current_win()
    vim.notify(string.format("Processing %s in window %d", session_name, current_win))
    
    -- 新しいバッファを作成してからターミナルを開く
    vim.cmd('enew')
    -- new-session -Aオプションを使用（既存セッションにアタッチ、なければ作成）
    local attach_cmd = string.format("tmux new-session -A -s %s", session_name)
    local job_id = vim.fn.termopen(attach_cmd)
    
    -- デバッグ情報を出力
    if job_id <= 0 then
      vim.notify(string.format("ERROR: Session %s failed to start! job_id=%s", session_name, tostring(job_id)), vim.log.levels.ERROR)
    else
      vim.notify(string.format("Session %s: job_id=%s", session_name, tostring(job_id)))
    end
    
    -- バッファ名を設定
    vim.api.nvim_buf_set_name(0, session_name)
    
    -- バッファローカルなキーマップ
    local buf = vim.api.nvim_get_current_buf()
    vim.api.nvim_buf_set_keymap(buf, 't', '<C-q>', '<C-\\><C-n>:q<CR>',
      { noremap = true, silent = true })
    
    -- 行番号を非表示に
    vim.wo.number = false
    vim.wo.relativenumber = false
    vim.wo.signcolumn = 'no'
    
    if i < 10 then
      vim.cmd('wincmd l')  -- 右へ移動
      -- 短い遅延を追加
      vim.wait(50)
    end
  end

  -- 左上のウィンドウに戻る
  vim.cmd('wincmd t')

  M.is_normal_open = true
end

return M
