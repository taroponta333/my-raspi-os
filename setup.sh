#!/bin/bash
# ---------------------------------------------------------
# Phase 2: Alpine Linux 自動設定オーバーレイ（apkovl）生成版
# ---------------------------------------------------------

DEPLOY_DIR=$1

echo "=== Alpine Linux 向け自動設定ファイルの生成を開始 ==="

# 📁 一時的な設定配置フォルダを作成
STAGE_DIR=$(mktemp -d)
mkdir -p "$STAGE_DIR/etc/init.d"
mkdir -p "$STAGE_DIR/tmp"

# 🌟 1. ログイン画面を完全に消し去る大元の設定 (inittab)
cat << 'EOF' > "$STAGE_DIR/etc/inittab"
# /etc/inittab
::sysinit:/etc/init.d/rcS
::shutdown:/etc/init.d/rcK

# ログインを無視して、root権限で直接X11(画面)とインストーラーUIを起動
tty1::respawn:/usr/bin/startx /tmp/installer_ui.sh -- :0 -nolisten tcp
EOF

# 🌟 2. 【UI本体】ラジオボタン ➔ チェックボックス ➔ ストリーミングシステム
cat << 'EOF' > "$STAGE_DIR/tmp/installer_ui.sh"
#!/bin/bash
export DISPLAY=:0
export HOME=/root

# 🌐 ネットワークを強制起動
rc-service networking start 2>/dev/null
udhcpc -i eth0 2>/dev/null
udhcpc -i wlan0 2>/dev/null

# 📦 画面に必要な最小限のパッケージをその場で高速セットアップ
apk update
apk add bash zenity xorg-server xf86-video-fbdev twm wget xinit unxz

# 軽量ウィンドウマネージャーを起動
twm &

# 🔘 [ステップ1] OSモードの選択
OS_MODE=$(zenity --list --radiolist \
  --title="Phase 2: 自作OSインストーラー" \
  --text="インストールする本番OSのモードを選択してください。" \
  --column="選択" --column="OSモード" --column="説明" \
  TRUE "Perfect-OS" "自作SNSとTurboWarpを左右2画面分割で爆速起動" \
  FALSE "Explorer-OS" "ファイルマネージャーがメインのシンプル開発画面" \
  FALSE "Official-Full" "公式のフル版デスクトップ（PIXEL環境）" \
  --width=550 --height=300)

if [ -z "$OS_MODE" ]; then reboot; exit 1; fi

# ☑️ [ステップ2] アプリの追加
APPS=$(zenity --list --checklist \
  --title="Phase 2: 追加アプリ" \
  --text="本番OSに最初から組み込んでおきたいアプリを選択（複数可）。" \
  --column="選択" --column="アプリ名" --column="説明" \
  TRUE "Python3" "プログラミング環境 ＆ pipツール" \
  TRUE "VS Code" "WEBブラウザから叩ける高機能コードエディタ" \
  --width=550 --height=300)

# 💾 [ステップ3] 焼き付け先メディアの選択
WHERE_TO_SAVE=$(zenity --list \
  --title="Save Destination" \
  --text="完成したカスタムOSをどこにインストールしますか？" \
  --column="番号" --column="保存方法" --column="説明" \
  "1" "今のSDカード自体" "このインストーラーメディアを上書きして本番OSに変身させます" \
  "2" "外付けのUSBメモリ" "ラズパイに挿してある外付けUSBメモリを丸ごと自作OS化します" \
  --width=550 --height=250)

if [ -z "$WHERE_TO_SAVE" ]; then reboot; exit 1; fi

# 🌐 [ステップ4] ストリーミング書き込み
(
  if [ "$WHERE_TO_SAVE" = "1" ]; then
    TARGET_DEV="/dev/mmcblk0"
  else
    TARGET_DEV="/dev/sda"
  fi

  echo "# ラズパイ公式からOSをストリーミング中 ＆ 魔改造データを直接書き込み中..."
  wget -O - https://downloads.raspberrypi.com/raspios_lite_arm64/images/raspios_lite_arm64-2024-11-19/2024-11-19-raspios-bookworm-arm64-lite.img.xz | unxz | dd of=$TARGET_DEV bs=4M
  
  # 本番OSへの設定注入
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
chmod +x "$STAGE_DIR/tmp/installer_ui.sh"

# 📦 変更した設定ファイルをAlpineが認識する特別な圧縮形式「.apkovl」にまとめる
cd "$STAGE_DIR"
tar -czf "$DEPLOY_DIR/localhost.apkovl.tar.gz" ./*
rm -rf "$STAGE_DIR"

echo "=== localhost.apkovl.tar.gz の自動生成が完了しました ==/
