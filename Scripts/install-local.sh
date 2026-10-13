#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
source_app="$PWD/build/Build/Products/Release/ArmKeyKey.app"
target_app="$HOME/Library/Input Methods/ArmKeyKey.app"
[[ -d "$source_app" ]] || { echo '請先執行 Scripts/build.sh。' >&2; exit 1; }
codesign --verify --strict "$source_app"
if [[ -e "$target_app" ]]; then
    echo 'ArmKeyKey is already installed. Switch to another input source, move the old app to Trash, then run this script again. Learned ordering is preserved.' >&2
    exit 1
fi
mkdir -p "$HOME/Library/Input Methods"
ditto "$source_app" "$target_app"
"$target_app/Contents/MacOS/ArmKeyKey" --register-input-source
open "$target_app" --args --settings
printf '已安裝並註冊。請在 ArmKeyKey 按「安裝並加入輸入來源」。手動加入時請選「中文（繁體）」，若未顯示請登出後重新登入。\n'
