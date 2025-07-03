---@diagnostic disable-next-line: undefined-global
local vim = vim

local M = {}

-- グローバル変数でウィンドウとステートを管理
M.is_normal_open = false
M.saved_layout = nil
M.individual_session = nil -- 個別モードのセッション名
M.original_tab = nil -- 元のタブ番号を保存
M.tmux_tab = nil -- tmuxセッション用のタブ番号

-- セッション数の設定（変更可能）
M.session_count = 10

-- セッション名を取得
local function get_session_names()
  local sessions = {}
  for i = 1, M.session_count do
    table.insert(sessions, "claude" .. i)
  end
  return sessions
end

-- セッション数に基づいて最適な行列数を計算
local function calculate_grid_layout(session_count)
  -- 正方形に近い形を目指す
  local cols = math.ceil(math.sqrt(session_count))
  local rows = math.ceil(session_count / cols)
  return rows, cols
end

-- グリッドレイアウトを作成
local function create_grid_layout(rows, cols)
  -- 最初のウィンドウはすでに存在
  local windows = {vim.api.nvim_get_current_win()}
  
  -- 行を作成
  for row = 2, rows do
    vim.cmd('split')
    vim.cmd('wincmd j')
  end
  
  -- 各行で列を作成
  vim.cmd('wincmd t') -- 左上に移動
  for row = 1, rows do
    if row > 1 then
      vim.cmd('wincmd j')
    end
    
    for col = 2, cols do
      vim.cmd('vsplit')
      vim.cmd('wincmd l')
    end
    
    -- 行の左端に戻る
    for _ = 2, cols do
      vim.cmd('wincmd h')
    end
  end
  
  -- ウィンドウサイズを均等に
  vim.cmd('wincmd =')
  
  -- 全ウィンドウのIDを取得（左上から右下へ順番に）
  windows = {}
  vim.cmd('wincmd t')
  for row = 1, rows do
    if row > 1 then
      -- 次の行の先頭へ
      vim.cmd('wincmd j')
      for _ = 2, cols do
        vim.cmd('wincmd h')
      end
    end
    
    for col = 1, cols do
      table.insert(windows, vim.api.nvim_get_current_win())
      if col < cols then
        vim.cmd('wincmd l')
      end
    end
  end
  
  return windows
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

-- 既存のバッファを検索する関数
local function find_buffer_by_name(name)
  vim.notify(string.format("DEBUG find_buffer_by_name: looking for '%s'", name))
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_valid(buf) then
      local buf_name = vim.api.nvim_buf_get_name(buf)
      local is_loaded = vim.api.nvim_buf_is_loaded(buf)
      local is_terminal = vim.api.nvim_buf_get_option(buf, 'buftype') == 'terminal'
      vim.notify(string.format("DEBUG: buf %d, name='%s', loaded=%s, terminal=%s", buf, buf_name, tostring(is_loaded), tostring(is_terminal)))
      
      -- ターミナルバッファの場合、名前の末尾でマッチング
      if is_terminal and is_loaded and buf_name:match(name .. "$") then
        vim.notify(string.format("DEBUG: Found matching terminal buffer %d", buf))
        return buf
      end
    end
  end
  vim.notify("DEBUG: No matching buffer found")
  return nil
end

-- 単一のウィンドウにセッションを設定する関数
local function setup_session_in_window(session_name, window_id)
  local existing_buf = find_buffer_by_name(session_name)
  
  if existing_buf then
    -- 既存バッファを使用
    vim.api.nvim_win_set_buf(window_id, existing_buf)
  else
    -- 新しいバッファを作成
    vim.api.nvim_win_call(window_id, function()
      vim.cmd('enew')
      local buf_before = vim.api.nvim_get_current_buf()
      local name_before = vim.api.nvim_buf_get_name(buf_before)
      vim.notify(string.format("DEBUG: After enew - buf=%d, name='%s'", buf_before, name_before))
      
      -- new-session -Aオプションを使用
      local attach_cmd = string.format("tmux new-session -A -s %s", session_name)
      
      -- gitgutterなどの自動コマンドを一時的に無効化
      local eventignore_save = vim.o.eventignore
      vim.o.eventignore = "all"
      
      local job_id = vim.fn.termopen(attach_cmd)
      
      -- 自動コマンドを復元
      vim.o.eventignore = eventignore_save
      
      local buf_after = vim.api.nvim_get_current_buf()
      local name_after = vim.api.nvim_buf_get_name(buf_after)
      vim.notify(string.format("DEBUG: After termopen - buf=%d, name='%s'", buf_after, name_after))
      
      -- バッファローカルなキーマップ
      local buf = vim.api.nvim_get_current_buf()
      vim.api.nvim_buf_set_keymap(buf, 't', '<C-q>', '<C-\\><C-n>:q<CR>',
        { noremap = true, silent = true })
      vim.api.nvim_buf_set_keymap(buf, 'n', 'o',
        string.format('<cmd>lua require("tmux-test.multiple").open_individual("%s")<CR>', session_name),
        { noremap = true, silent = true })
    end)
  end
  
  -- ウィンドウオプションを設定
  vim.api.nvim_win_call(window_id, function()
    vim.wo.number = false
    vim.wo.relativenumber = false
    vim.wo.signcolumn = 'no'
  end)
end

-- 通常ウィンドウ版を閉じる
function M.close_normal()
  -- デバッグ情報
  vim.notify(string.format("DEBUG close_normal: M.tmux_tab=%s, M.original_tab=%s, current_tab=%d, total_tabs=%d",
    tostring(M.tmux_tab), tostring(M.original_tab), vim.fn.tabpagenr(), vim.fn.tabpagenr('$')))
  
  -- tmuxタブが存在する場合は閉じる
  if M.tmux_tab then
    -- 現在のタブを保存
    local current_tab = vim.fn.tabpagenr()
    
    -- tmuxタブに移動
    vim.cmd('tabnext ' .. M.tmux_tab)
    
    -- タブを閉じる前のバッファ情報を保存（デバッグ用）
    local buffers_before = {}
    local wins = vim.api.nvim_tabpage_list_wins(0)
    for _, win in ipairs(wins) do
      local buf = vim.api.nvim_win_get_buf(win)
      if vim.api.nvim_buf_is_valid(buf) then
        local buf_name = vim.api.nvim_buf_get_name(buf)
        table.insert(buffers_before, {buf = buf, name = buf_name})
      end
    end
    vim.notify(string.format("DEBUG before tabclose: %d buffers in tmux tab", #buffers_before))
    
    -- タブを閉じる
    vim.cmd('tabclose')
    
    -- タブを閉じた後のバッファ確認（デバッグ用）
    local buffers_alive = 0
    for _, buf_info in ipairs(buffers_before) do
      if vim.api.nvim_buf_is_valid(buf_info.buf) then
        buffers_alive = buffers_alive + 1
        vim.notify(string.format("DEBUG: Buffer still alive: %s", buf_info.name))
      end
    end
    vim.notify(string.format("DEBUG after tabclose: %d/%d buffers still alive", buffers_alive, #buffers_before))
    
    -- 元のタブが現在のタブより後ろにあった場合、番号が1つ減る
    if M.original_tab and M.original_tab > M.tmux_tab then
      M.original_tab = M.original_tab - 1
    end
    
    M.tmux_tab = nil
  end

  M.is_normal_open = false
end

-- 通常ウィンドウ版
function M.show_normal()
  -- デバッグ情報（show_normal開始時）
  vim.notify(string.format("DEBUG show_normal start: is_normal_open=%s, M.tmux_tab=%s, M.original_tab=%s, current_tab=%d, total_tabs=%d",
    tostring(M.is_normal_open), tostring(M.tmux_tab), tostring(M.original_tab), vim.fn.tabpagenr(), vim.fn.tabpagenr('$')))
  
  -- 既に開いている場合は閉じる（トグル動作）
  if M.is_normal_open then
    M.close_normal()
    -- 元のタブに戻る
    if M.original_tab then
      vim.cmd('tabnext ' .. M.original_tab)
    end
    return
  end

  local sessions = get_session_names()
  ensure_sessions_exist(sessions)

  -- 現在のタブ番号を保存
  M.original_tab = vim.fn.tabpagenr()

  -- 新しいタブを作成
  vim.cmd('tabnew')
  M.tmux_tab = vim.fn.tabpagenr()
  
  -- レイアウトを計算
  local rows, cols = calculate_grid_layout(#sessions)
  
  -- グリッドレイアウトを作成
  local windows = create_grid_layout(rows, cols)
  
  -- 各ウィンドウにセッションを設定
  for i, session_name in ipairs(sessions) do
    if i <= #windows then
      setup_session_in_window(session_name, windows[i])
    end
  end

  -- 左上のウィンドウに戻る
  vim.cmd('wincmd t')

  M.is_normal_open = true
end

-- 個別ウィンドウモードを開く
function M.open_individual(session_name)
  -- セッション名を保存
  M.individual_session = session_name

  -- 元のタブに戻る
  if M.original_tab then
    vim.cmd('tabnext ' .. M.original_tab)
  end

  -- 右端に垂直分割で開く
  vim.cmd('vsplit')
  vim.cmd('wincmd L') -- 右端に移動

  -- ウィンドウ幅を調整（画面の40%程度）
  local width = math.floor(vim.o.columns * 0.4)
  vim.cmd(string.format('vertical resize %d', width))

  -- ターミナルを開く
  local attach_cmd = string.format("tmux attach-session -t %s", session_name)
  vim.fn.termopen(attach_cmd)

  -- バッファ名を設定
  vim.api.nvim_buf_set_name(0, session_name .. " (individual)")

  -- キーマップ設定
  local buf = vim.api.nvim_get_current_buf()
  vim.api.nvim_buf_set_keymap(buf, 't', '<C-q>', '<C-\\><C-n>:q<CR>',
    { noremap = true, silent = true })
  -- qで閉じて通常ウィンドウモードに戻る
  vim.api.nvim_buf_set_keymap(buf, 'n', 'q',
    '<cmd>lua require("tmux-test.multiple").close_individual()<CR>',
    { noremap = true, silent = true })

  -- 行番号を非表示
  vim.wo.number = false
  vim.wo.relativenumber = false
  vim.wo.signcolumn = 'no'

  -- インサートモードに入る
  vim.cmd("startinsert")
end

-- 個別ウィンドウモードを閉じる
function M.close_individual()
  -- 現在のウィンドウを閉じる
  vim.cmd('q')
  
  -- 個別セッション情報をクリア
  M.individual_session = nil
end

return M
