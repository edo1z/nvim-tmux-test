---@diagnostic disable-next-line: undefined-global
local vim = vim

local M = {}

-- グローバル変数でウィンドウとステートを管理
M.is_normal_open = false
M.saved_layout = nil
M.individual_session = nil -- 個別モードのセッション名

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


-- 通常ウィンドウ版を閉じる
function M.close_normal()
  -- すべてのtmuxセッションのバッファを閉じる
  local sessions = get_session_names()
  for _, session_name in ipairs(sessions) do
    -- セッション名に一致するバッファを検索して削除
    for _, buf in ipairs(vim.api.nvim_list_bufs()) do
      if vim.api.nvim_buf_is_valid(buf) then
        local buf_name = vim.api.nvim_buf_get_name(buf)
        if buf_name:match(session_name) and not buf_name:match("%(individual%)") then
          vim.api.nvim_buf_delete(buf, { force = true })
        end
      end
    end
  end

  -- すべてのウィンドウを閉じて元のレイアウトに戻す
  vim.cmd('only')

  M.is_normal_open = false
end

-- 通常ウィンドウ版
function M.show_normal()
  -- 既に開いている場合は閉じる
  if M.is_normal_open then
    M.close_normal()
    return
  end

  -- フローティングウィンドウ版が開いている場合は閉じる

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
  vim.cmd('wincmd k') -- 上に移動
  for i = 1, 4 do
    vim.cmd('vsplit')
  end

  -- 下段（6-10）を作成
  vim.cmd('wincmd j') -- 下に移動
  for i = 1, 4 do
    vim.cmd('vsplit')
  end

  -- ウィンドウサイズを均等に
  vim.cmd('wincmd =')

  -- ウィンドウ数を確認
  local win_count = #vim.api.nvim_list_wins()
  vim.notify(string.format("Total windows created: %d", win_count))

  -- 各ウィンドウでtmuxセッションを開く（上段から順に）
  vim.cmd('wincmd t') -- 左上に移動

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
    -- 個別ウィンドウモードへの切り替え
    vim.api.nvim_buf_set_keymap(buf, 'n', 'o',
      string.format('<cmd>lua require("tmux-test.multiple").open_individual("%s")<CR>', session_name),
      { noremap = true, silent = true })

    -- 行番号を非表示に
    vim.wo.number = false
    vim.wo.relativenumber = false
    vim.wo.signcolumn = 'no'

    if i < 5 then
      vim.cmd('wincmd l') -- 右へ移動
      -- 短い遅延を追加
      vim.wait(50)
    end
  end

  -- 下段へ移動（claude6-10）
  -- 左上に戻ってから下に移動することで確実に左下に移動
  vim.cmd('wincmd t') -- 左上に移動
  vim.cmd('wincmd j') -- 下に移動（左下へ）
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
      vim.notify(string.format("ERROR: Session %s failed to start! job_id=%s", session_name, tostring(job_id)),
        vim.log.levels.ERROR)
    else
      vim.notify(string.format("Session %s: job_id=%s", session_name, tostring(job_id)))
    end

    -- バッファ名を設定
    vim.api.nvim_buf_set_name(0, session_name)

    -- バッファローカルなキーマップ
    local buf = vim.api.nvim_get_current_buf()
    vim.api.nvim_buf_set_keymap(buf, 't', '<C-q>', '<C-\\><C-n>:q<CR>',
      { noremap = true, silent = true })
    -- 個別ウィンドウモードへの切り替え
    vim.api.nvim_buf_set_keymap(buf, 'n', 'o',
      string.format('<cmd>lua require("tmux-test.multiple").open_individual("%s")<CR>', session_name),
      { noremap = true, silent = true })

    -- 行番号を非表示に
    vim.wo.number = false
    vim.wo.relativenumber = false
    vim.wo.signcolumn = 'no'

    if i < 10 then
      vim.cmd('wincmd l') -- 右へ移動
      -- 短い遅延を追加
      vim.wait(50)
    end
  end

  -- 左上のウィンドウに戻る
  vim.cmd('wincmd t')

  M.is_normal_open = true
end

-- 個別ウィンドウモードを開く
function M.open_individual(session_name)
  -- 10個表示を閉じる
  if M.is_normal_open then
    M.close_normal()
  end

  -- セッション名を保存
  M.individual_session = session_name

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

-- 個別ウィンドウモードを閉じて通常ウィンドウモードに戻る
function M.close_individual()
  -- 現在のウィンドウを閉じる
  vim.cmd('q')
end

return M
