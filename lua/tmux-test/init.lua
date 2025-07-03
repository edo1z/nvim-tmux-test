---@diagnostic disable-next-line: undefined-global
local vim = vim

local M = {}

function M.show_tmux_session()
  local session_name = "nvim-tmux-test"
  -- tmuxセッションが存在するかチェック
  local check_cmd = string.format("tmux has-session -t %s 2>/dev/null", session_name)
  vim.fn.system(check_cmd)
  -- セッションが存在しない場合は作成
  if vim.v.shell_error ~= 0 then
    local create_cmd = string.format("tmux new-session -d -s %s", session_name)
    vim.fn.system(create_cmd)
  end
  -- セッションでclaude codeを実行
  local send_cmd = string.format("tmux send-keys -t %s 'claude' C-m", session_name)
  vim.fn.system(send_cmd)
  -- 少し待機してから出力を取得
  vim.cmd("sleep 100m")
  -- セッションの内容を取得
  local capture_cmd = string.format("tmux capture-pane -t %s -p", session_name)
  local output = vim.fn.system(capture_cmd)
  -- フローティングウィンドウの設定
  local width = math.floor(vim.o.columns * 0.8)
  local height = math.floor(vim.o.lines * 0.8)
  local row = math.floor((vim.o.lines - height) / 2)
  local col = math.floor((vim.o.columns - width) / 2)
  local buf = vim.api.nvim_create_buf(false, true)
  -- バッファに内容を設定
  local lines = vim.split(output, '\n')
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  -- フローティングウィンドウを作成
  local win_opts = {
    relative = 'editor',
    width = width,
    height = height,
    row = row,
    col = col,
    style = 'minimal',
    border = 'rounded',
    title = ' tmux: ' .. session_name .. ' ',
    title_pos = 'center',
  }
  local win = vim.api.nvim_open_win(buf, true, win_opts)
  -- バッファとウィンドウのオプション設定
  vim.api.nvim_buf_set_option(buf, 'modifiable', false)
  vim.api.nvim_buf_set_option(buf, 'buftype', 'nofile')
  vim.api.nvim_win_set_option(win, 'wrap', false)
  -- qキーでウィンドウを閉じる
  vim.api.nvim_buf_set_keymap(buf, 'n', 'q', ':close<CR>', { noremap = true, silent = true })
  -- Escキーでもウィンドウを閉じる
  vim.api.nvim_buf_set_keymap(buf, 'n', '<Esc>', ':close<CR>', { noremap = true, silent = true })
end

function M.show_tmux_interactive()
  local session_name = "nvim-tmux-test"
  -- tmuxセッションが存在するかチェック
  local check_cmd = string.format("tmux has-session -t %s 2>/dev/null", session_name)
  vim.fn.system(check_cmd)
  -- セッションが存在しない場合は作成してclaude codeを実行
  if vim.v.shell_error ~= 0 then
    local create_cmd = string.format("tmux new-session -d -s %s 'claude'", session_name)
    vim.fn.system(create_cmd)
  end
  -- フローティングウィンドウの設定
  local width = math.floor(vim.o.columns * 0.8)
  local height = math.floor(vim.o.lines * 0.8)
  local row = math.floor((vim.o.lines - height) / 2)
  local col = math.floor((vim.o.columns - width) / 2)
  local buf = vim.api.nvim_create_buf(false, true)
  -- フローティングウィンドウを作成
  local win_opts = {
    relative = 'editor',
    width = width,
    height = height,
    row = row,
    col = col,
    style = 'minimal',
    border = 'rounded',
    title = ' tmux: ' .. session_name .. ' (interactive) ',
    title_pos = 'center',
  }
  local win = vim.api.nvim_open_win(buf, true, win_opts)
  -- ターミナルモードでtmuxアタッチ
  local attach_cmd = string.format("tmux attach-session -t %s", session_name)
  vim.fn.termopen(attach_cmd)
  vim.cmd("startinsert")
  -- Terminal-Normalモードでのキーマップ追加
  vim.api.nvim_buf_set_keymap(buf, 'n', 'q', ':close<CR>',
    { noremap = true, silent = true })
  -- ターミナルモードから直接閉じるキーマップ
  vim.api.nvim_buf_set_keymap(buf, 't', '<C-q>', '<C-\\><C-n>:close<CR>',
    { noremap = true, silent = true })
end

function M.setup()
  -- コマンド登録
  vim.api.nvim_create_user_command('TmuxTest', M.show_tmux_session, {})
  vim.api.nvim_create_user_command('TmuxTestInteractive', M.show_tmux_interactive, {})
end

return M