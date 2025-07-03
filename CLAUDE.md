# Luaファイル作成時の注意事項
- Neovimプラグイン開発では、ファイルの先頭に以下を追加してvimグローバル変数の警告を回避:
  ```lua
  ---@diagnostic disable-next-line: undefined-global
  local vim = vim
  ```
- 空行（改行のみ）はOK、ただし空白文字やタブのみの行は作らない
- 行末の余分な空白文字は削除する

