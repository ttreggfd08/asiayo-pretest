#!/bin/bash
#
# 用法:
#   ./top_word.sh words.txt
#   ./top_word.sh            # 預設讀取同目錄的 words.txt
#
# 邏輯:
#   tr 'A-Z' 'a-z'            : 全部轉小寫
#   tr -cs "[:alpha:]'" '\n'  : 把所有非字母字元換成換行，
#   grep -v '^$'              : 移除空行
#   sort | uniq -c            : 排序後計算每個單字次數
#   sort -rn                  : 大到小排序
#   awk 'NR==1'               : 取第一名，並去掉 uniq -c 的前導空白
#                               （讀完整串流再輸出，避免 head 提前關閉造成 SIGPIPE）

set -euo pipefail

FILE="${1:-$(dirname "$0")/words.txt}"

if [[ ! -f "$FILE" ]]; then
  echo "找不到檔案: $FILE" >&2
  exit 1
fi

tr 'A-Z' 'a-z' < "$FILE" \
  | tr -cs "[:alpha:]'" '\n' \
  | grep -v '^$' \
  | sort \
  | uniq -c \
  | sort -rn \
  | awk 'NR==1 {print $1, $2}'
