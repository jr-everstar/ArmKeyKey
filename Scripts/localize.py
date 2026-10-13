from pathlib import Path
import json
r=Path(__file__).resolve().parents[1]
strings={
'Familiar typing. A new Mac.':'熟悉的輸入體驗，全新的 Mac。',
'Get started':'開始使用',
'Install ArmKeyKey in your Library/Input Methods folder, then add ArmKeyKey in System Settings → Keyboard → Text Input → Edit → +. Log out and back in if it is not listed.':'將 ArmKeyKey 安裝到使用者資源庫的 Input Methods 資料夾，再前往「系統設定 → 鍵盤 → 文字輸入 → 編輯 → ＋」加入 ArmKeyKey。若未顯示，請登出後重新登入。',
'Open Keyboard Settings':'開啟鍵盤設定','Input method':'輸入法','Cangjie':'倉頡','Simplex':'速成',
'Learn Cangjie candidate order':'記住倉頡選字順序','Learn Simplex candidate order':'記住速成選字順序',
'Use 1–9 to select candidates. Space and arrow keys follow the original input method behavior.':'使用 1–9 選字。空白鍵與方向鍵保留原輸入法的操作方式。',
'Your learned ordering':'個人選字順序','Export…':'匯出⋯','Import…':'匯入⋯','Reset…':'重設⋯',
'Typing stays on this Mac. No accounts, network requests, or typing logs.':'輸入資料只留在這部 Mac，不需要帳號、不連線，也不記錄輸入內容。',
'Version 0.1 · Cangjie & Simplex':'版本 0.1 · 倉頡與速成','Licenses':'授權資訊','Reset learned ordering?':'重設個人選字順序？','Cancel':'取消','Reset':'重設',
'This removes learned candidate preferences for both input methods. Export a backup first if you want to keep them.':'這會移除兩種輸入法記住的選字偏好。如需保留，請先匯出備份。',
'Done.':'完成。','The operation failed. Check the file and try again. Your backup must be an ArmKeyKey JSON file.':'操作失敗，請檢查檔案後再試一次。備份必須是 ArmKeyKey JSON 檔案。',
'Replace learned ordering?':'取代個人選字順序？','Import replaces learning for both input methods. Export a backup first.':'匯入會取代兩種輸入法的選字偏好，請先匯出備份。',
'ArmKeyKey candidates':'ArmKeyKey 候選字','ArmKeyKey Settings…':'ArmKeyKey 設定⋯'}
for locale in ['en','zh-Hant']:
    (r/f'Resources/{locale}.lproj/Localizable.strings').write_text('\n'.join(f'{json.dumps(k,ensure_ascii=False)} = {json.dumps(v if locale=="zh-Hant" else k,ensure_ascii=False)};' for k,v in strings.items())+'\n')
