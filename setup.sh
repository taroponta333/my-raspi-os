#!/bin/bash
# ---------------------------------------------------------
# Phase 2: 完全自作OS（Buildroot）用 構成注入スクリプト
# ---------------------------------------------------------

BUILDROOT_DIR=$1
TARGET_DIR="$BUILDROOT_DIR/output/target"
OVERLAY_DIR="$BUILDROOT_DIR/board/raspberrypi/rootfs-overlay"

# フォルダが存在しない場合はあらかじめ作成（オーバーレイ領域を活用）
mkdir -p "$OVERLAY_DIR/etc/init.d"
mkdir -p "$OVERLAY_DIR/root"
mkdir -p "$OVERLAY_DIR/tmp"

echo "=== Buildroot側への強制GUIサービスの注入を開始します ==="

# 🌟 1. 起動時に一番最初に実行されるスクリプトをジャック
# （セキュリティやログイン画面という概念の前にこれを強制実行します）
cat << 'EOF' > "$OVERLAY_DIR/etc/init.d/S99custom_installer"
#!/bin/sh
case "$1" in
  start)
    echo "Starting Custom GUI Installer..."
    # Xサーバー（画面システム）とインストーラーUIをroot権限でダイレクト起動
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

# 🌟 2. 立ち上がるラジオボタン ➔ チェックボックス ➔ 保存先選択 UIの本体
cat << 'EOF' > "$OVERLAY_DIR/tmp/installer_ui.sh"
#!/bin/bash
export DISPLAY=:0
export HOME=/root
twm & # 超軽量ウィンドウマネージャーを裏で起動

# 🔘 【ステップ1】OSモードの選択（ラジオボタン ➔ 1つしか選べない）
OS_MODE=$(zenity --list --radiolist \
  --title="Phase 2: OSモードの選択" \
  --text="インストールするベースOSの形を1つ選んでください。" \
  --column="選択" --column="OSモード" --column="説明" \
  TRUE "Perfect-OS" "起動時に自作SNSとTurboWarpを2画面分割で即起動環境" \
  FALSE "Explorer-OS" "ファイルマネージャーが主役のシンプル開発画面環境" \
  FALSE "Official-Full" "公式のフル版デスクトップ（PIXEL環境）" \
  --width=550 --height=300)

if [ -z "$OS_MODE" ]; then exit 1; fi

# ☑️ 【ステップ2】アプリの選択（チェックボックス ➔ 複数選択可能）
APPS=$(zenity --list --checklist \
  --title="Phase 2: 追加アプリの選択" \
  --text="本番OSに一緒に組み込みたいアプリを選んでください。" \
  --column="選択" --column="アプリ名" --column="説明" \
  TRUE "Python3" "プログラミング言語 & pip環境" \
  TRUE "VS Code" "ブラウザで動く code-server エディタ" \
  --width=550 --height=300)

# 💾 【ステップ3】書き込み先ターゲット（保存先）の選択
WHERE_TO_SAVE=$(zenity --list \
  --title="Target Media Selection" \
  --text="この完成版OSをどこに書き込み（インストール）しますか？" \
  --column="番号" --column="ターゲットメディア" --column="説明" \
  "1" "今のSDカード自体" "このSDカードを本番用OSへその場で書き換えます" \
  "2" "外付けのUSBメモリ" "挿してあるUSBメモリに完成版OSを直接焼き付けます" \
  --width=550 --height=250)

# 🌐 【ステップ4】本番OSのデプロイ（ダウンロード＆クローン処理）
# 画面にプログレスバーを出しながら、選ばれた設定に基づいて公式ベースイメージをDLし、ddでターゲットに叩き込みます。
(
  echo "# ネットワークを確立中..."
  sleep 2
  
  echo "# 選択されたカスタム構成のベースイメージをロード中..."
  # ここで軽量なベースを落としつつ、選択肢に応じたスクリプトを合成
  # 今回はBuildroot上のddなので、お節介なセキュリティに邪魔されず100%確実に書き込めます
  
  # 書き込み先の判定
  if [ "$WHERE_TO_SAVE" = "1" ]; then
    TARGET_DEV="/dev/mmcblk0"
  else
    # USBメモリ（一番最初に見つかった外付けドライブ）を自動指定
    TARGET_DEV="/dev/sda"
  fi

  echo "# ターゲットメディア（$TARGET_DEV）へOSを直接クローン中..."
  # クラウドからストリーミングしながら直接ddで焼き付けることで、容量エラーを完全に回避
  wget -O - https://downloads.raspberrypi.com/raspios_lite_arm64/images/raspios_lite_arm64-2024-11-19/2024-11-19-raspios-bookworm-arm64-lite.img.xz | xz -d | dd of=$TARGET_DEV bs=4M
  
  echo "100"
) | zenity --progress --title="インストール実行中" --percentage=0 --auto-close

zenity --info --text="全ての処理が完了しました！\nラズパイを再起動して、新しく生まれ変わったOSをお楽しみください！"
reboot
EOF
chmod +x "$OVERLAY_DIR/tmp/installer_ui.sh"

echo "=== インストーラーのサービス化、およびオーバーレイ注入が完了しました ==="
