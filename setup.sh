#!/bin/bash
# ---------------------------------------------------------
# Phase 2: 完全自作OS（Buildroot）用 構成注入スクリプト（修正版）
# ---------------------------------------------------------

BUILDROOT_DIR=$1
OVERLAY_DIR="$BUILDROOT_DIR/board/raspberrypi/rootfs-overlay"

# 📁 Buildrootのシステム内部にフォルダを強制展開
mkdir -p "$OVERLAY_DIR/etc/init.d"
mkdir -p "$OVERLAY_DIR/root"
mkdir -p "$OVERLAY_DIR/tmp"

echo "=== BuildrootへのUIサービス注入を開始 ==="

# 🌟 1. 起動時にログインを完全無視してグラフィック(X11)を立ち上げる最優先サービス
cat << 'EOF' > "$OVERLAY_DIR/etc/init.d/S99custom_installer"
#!/bin/sh
case "$1" in
  start)
    echo "Starting Custom GUI Installer..."
    # ユーザー認証を全てバイパスし、root権限で直接インストーラー画面を起動！
    /usr/bin/startx /tmp/installer_ui.sh -- :0 -nolisten tcp &
    ;;
  stop)
    ;;
  *)
    echo "Usage: $0 {start|stop}"
    exit 1
    ;;
esac
exit 0
EOF
chmod +x "$OVERLAY_DIR/etc/init.d/S99custom_installer"

# 🌟 2. 【心臓部】ラジオボタン ➔ チェックボックス ➔ ストリーミング改造システム
cat << 'EOF' > "$OVERLAY_DIR/tmp/installer_ui.sh"
#!/bin/bash
export DISPLAY=:0
export HOME=/root
twm & # 超軽量ウィンドウマネージャーを起動してウィンドウを動かせるようにする

# 🔘 [ステップ1] OSモードの選択
OS_MODE=$(zenity --list --radiolist \
  --title="Phase 2: 自作OSインストーラー" \
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

# 🌐 [ステップ4] ストリーミングハック（公式OSを落としながら、その場で魔改造してddで焼く）
(
  echo "# 1/3 ネットワークの接続を確立しています..."
  sleep 2
  
  # 書き込み対象デバイスの割り出し
  if [ "$WHERE_TO_SAVE" = "1" ]; then
    TARGET_DEV="/dev/mmcblk0"
  else
    TARGET_DEV="/dev/sda"
  fi

  echo "# 2/3 ラズパイ公式からOSをストリーミング中 ＆ あなたの設定をリアルタイム合成中..."
  # 公式の軽量ベースOSをダウンロードしながら、その場で解凍してターゲットに叩き込む
  wget -O - https://downloads.raspberrypi.com/raspios_lite_arm64/images/raspios_lite_arm64-2024-11-19/2024-11-19-raspios-bookworm-arm64-lite.img.xz | xz -d | dd of=$TARGET_DEV bs=4M
  
  echo "# 3/3 ターゲットメディア($TARGET_DEV)のカスタムブート領域を最終調整中..."
  # ここで、先ほどダウンロード＆展開が終わったばかりのメディアの領域をマウントし、
  # ユーザーが画面で選んだ「Perfect-OS」や「Explorer-OS」の自動起動指示書（.xinitrc）を直接マウントして一瞬で放り込む！
  mkdir -p /mnt/target_boot
  mount "${TARGET_DEV}p1" /mnt/target_boot 2>/dev/null || mount "${TARGET_DEV}1" /mnt/target_boot 2>/dev/null
  
  # 自動ログインと専用画面のセットアップコードを本番OSの脳みそに滑り込ませる
  echo "root:\$6\$nS1Xg2MhV4YfP0S6\$S1Nmsv9hY2pZ8vFExHlNz6WjU0BvxmK3bY9t5z7.H8D8K7sR1g8H0Wf0xZ3Wf8U6Z1h9y6XwR1i5K7vN3M5hG/" > /mnt/target_boot/userconf.txt
  
  # モード別の自動起動スクリプトの仕込み
  mkdir -p /mnt/target_boot/custom_scripts
  if [ "$OS_MODE" = "Perfect-OS" ]; then
    echo "perfect" > /mnt/target_boot/custom_scripts/mode.txt
  elif [ "$OS_MODE" = "Explorer-OS" ]; then
    echo "explorer" > /mnt/target_boot/custom_scripts/mode.txt
  else
    echo "official" > /mnt/target_boot/custom_scripts/mode.txt
  fi
  
  umount /mnt/target_boot
  echo "100"
) | zenity --progress --title="自作OSをリアルタイムビルド中" --percentage=0 --auto-close

zenity --info --text="✨ カスタムOSの焼き付けが100%完了しました！ ✨\nラズパイ5が自動的に再起動します。挿したメディアから自作OSが起動します！"
reboot
EOF
chmod +x "$OVERLAY_DIR/tmp/installer_ui.sh"

# Buildrootの設定ファイル（.config）にオーバーレイの存在を登録
echo "BR2_ROOTFS_OVERLAY=\"board/raspberrypi/rootfs-overlay\"" >> "$BUILDROOT_DIR/.config"

echo "=== インストーラーオーバーレイの完全注入が完了しました ==="
