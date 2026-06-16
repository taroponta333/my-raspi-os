#!/bin/bash
# ---------------------------------------------------------
# Phase 2: Alpine Linux ベース 超軽量インストーラー生成スクリプト
# ---------------------------------------------------------

DEPLOY_DIR=$1

echo "=== Alpine Linux への強制GUIインストーラー注入を開始 ==="

# 📁 起動時に実行するオーバーレイ領域（apkovl）を擬似的に作成
mkdir -p "$DEPLOY_DIR/root"
mkdir -p "$DEPLOY_DIR/etc/local.d"

# 🌟 1. 起動した瞬間にログイン画面を無視してGUIを立ち上げる命令
cat << 'EOF' > "$DEPLOY_DIR/etc/local.d/custom_installer.start"
#!/bin/sh
echo "Initializing Custom GUI Installer..."

# 必要最低限のGUIツール（Xorg, Zenity, TWM）を裏で強制セットアップ
apk update
apk add bash zenity xorg-server xf86-video-fbdev twm wget xinit

# 直接画面とUIスクリプトをroot権限のまま起動
startx /tmp/installer_ui.sh -- :0 -nolisten tcp &
EOF
chmod +x "$DEPLOY_DIR/etc/local.d/custom_installer.start"

# 🌟 2. 【UIの本体】ラジオボタン ➔ チェックボックス ➔ ストリーミング改造システム
cat << 'EOF' > "$DEPLOY_DIR/tmp/installer_ui.sh"
#!/bin/bash
export DISPLAY=:0
export HOME=/root
twm &

# 🔘 [ステップ1] OSモードの選択
OS_MODE=$(zenity --list --radiolist \
  --title="Phase 2: 自作OSインストーラー (Alpine)" \
  --text="インストールする本番OSのモードを選択してください。" \
  --column="選択" --column="OSモード" --column="説明" \
  TRUE "Perfect-OS" "自作SNSとTurboWarpを左右2画面分割で爆速起動" \
  FALSE "Explorer-OS" "ファイルマネージャーがメインのシンプル開発画面" \
  FALSE "Official-Full" "公式のフル版デスクトップ（PIXEL環境）" \
  --width=550 --height=300)

if [ -z "$OS_MODE" ]; then exit 1; fi

# ☑️ [ステップ2] アプリの追加
APPS=$(zenity --list --checklist \
  --title="Phase 2: 追加アプリ" \
  --text="本番OSに最初から組み込んでおきたいアプリを選択（複数可）。" \
  --column="選択" --column="アプリ名" --column="説明" \
  TRUE "Python3" "プログラミング環境 ＆ pipツール" \
  TRUE "VS Code" "WEBブラウザから叩ける高機能コードエディタ" \
  --width=550 --height=300)

# 💾 [ステップ3] 焼き付け先ターゲットメディアの選択
WHERE_TO_SAVE=$(zenity --list \
  --title="Save Destination" \
  --text="完成したカスタムOSをどこにインストールしますか？" \
  --column="番号" --column="保存方法" --column="説明" \
  "1" "今のSDカード自体" "このインストーラーメディアを上書きして本番OSに変身させます" \
  "2" "外付けのUSBメモリ" "ラズパイに挿してある外付けUSBメモリを丸ごと自作OS化します" \
  --width=550 --height=250)

if [ -z "$WHERE_TO_SAVE" ]; then exit 1; fi

# 🌐 [ステップ4] ストリーミングハック
(
  echo "# 1/2 ターゲットメディアをフォーマット中..."
  if [ "$WHERE_TO_SAVE" = "1" ]; then
    TARGET_DEV="/dev/mmcblk0"
  else
    TARGET_DEV="/dev/sda"
  fi

  echo "# 2/2 ラズパイ公式からOSをストリーミング中 ＆ 魔改造データを直接書き込み中..."
  # 公式OSを引っ張りながらそのままddで書き込む（セキュリティの影響は100%受けません）
  wget -O - https://downloads.raspberrypi.com/raspios_lite_arm64/images/raspios_lite_arm64-2024-11-19/2024-11-19-raspios-bookworm-arm64-lite.img.xz | unxz | dd of=$TARGET_DEV bs=4M
  
  # 本番OSの自動起動ファイルなどの最終加工
  mkdir -p /mnt/target
  mount "${TARGET_DEV}p1" /mnt/target 2>/dev/null || mount "${TARGET_DEV}1" /mnt/target 2>/dev/null
  echo "root:\$6\$nS1Xg2MhV4YfP0S6\$S1Nmsv9hY2pZ8vFExHlNz6WjU0BvxmK3bY9t5z7.H8D8K7sR1g8H0Wf0xZ3Wf8U6Z1h9y6XwR1i5K7vN3M5hG/" > /mnt/target/userconf.txt
  
  mkdir -p /mnt/target/custom_scripts
  echo "$OS_MODE" > /mnt/target/custom_scripts/mode.txt
  echo "$APPS" > /mnt/target/custom_scripts/apps.txt
  
  umount /mnt/target
  echo "100"
) | zenity --progress --title="自作OSをリアルタイムビルド中" --percentage=0 --auto-close

zenity --info --text="✨ カスタムOSの書き換えが完了しました！ ✨\n自動的に再起動します。"
reboot
EOF
chmod +x "$DEPLOY_DIR/tmp/installer_ui.sh"

# 🌟 Alpine Linuxの起動設定（config.txt）をラズパイ5向けに微調整
echo "arm_64bit=1" >> "$DEPLOY_DIR/config.txt"
echo "enable_uart=1" >> "$DEPLOY_DIR/config.txt"

echo "=== Alpineベースのカスタムインストーラー配置が完了しました ==="
