#!/bin/bash
# ---------------------------------------------------------
# 最終兵器：強制GUIインストーラーサービス自動注入スクリプト
# ---------------------------------------------------------

ROOTFS=$1
if [ -z "$ROOTFS" ]; then
    echo "エラー: マウント先（ROOTFS）が指定されていません。"
    exit 1
fi

echo "=== カスタムOSの構成注入を開始します ==="

# 📁 必要なフォルダを強制作成
sudo mkdir -p "$ROOTFS/root"
sudo mkdir -p "$ROOTFS/etc/systemd/system"

# 🌟 1. ラズパイの起動の親玉に「カスタムインストーラー」を最優先登録する
cat << 'EOF' | sudo tee "$ROOTFS/etc/systemd/system/custom-installer.service"
[Unit]
Description=Forced GUI Custom Installer
After=multi-user.target
X-Overwrite=yes

[Service]
Type=simple
User=root
WorkingDirectory=/root
# ログインやセキュリティを全てすっ飛ばして、直接画面システムとUIスクリプトを強制起動
ExecStart=/usr/bin/startx /tmp/installer_ui.sh -- :0 -nolisten tcp
Restart=no

[Install]
WantedBy=multi-user.target
EOF

# systemdサービスを有効化するためのシンボリックリンクをビルド時に作成
sudo ln -sf /etc/systemd/system/custom-installer.service "$ROOTFS/etc/systemd/system/multi-user.target.wants/custom-installer.service"

# 🌟 2. インストーラーUIと変身・クローン機能のコア（本体）
cat << 'EOF' | sudo tee "$ROOTFS/tmp/installer_ui.sh"
#!/bin/bash
export DISPLAY=:0
export HOME=/root
openbox &

# 先に最小限のUIツールが入っているか確認（入っていなければその場で即導入）
if ! command -v zenity &> /dev/null; then
  apt-get update && apt-get install -y zenity openbox xorg pcmanfm wget curl -y
fi

# 🔘 【ステップ1】OSモードの選択（ラジオボタン）
OS_MODE=$(zenity --list --radiolist \
  --title="ステップ 1/2: OSモードの選択" \
  --text="ベースとなるOSのモードを1つだけ選んでください。" \
  --column="選択" --column="OSモード" --column="説明" \
  TRUE "Perfect-OS" "起動時に自作SNSとTurboWarpを2画面分割で即起動" \
  FALSE "Explorer-OS" "ファイルマネージャーが主役のシンプル開発画面" \
  FALSE "Official-Full" "公式のフル版デスクトップ（PIXEL環境）を入れる" \
  --width=550 --height=300)

if [ -z "$OS_MODE" ]; then pkill openbox; exit 1; fi
echo "$OS_MODE" > /tmp/user_os_choice.txt

# ☑️ 【ステップ2】アプリの選択（チェックボックス）
APPS=$(zenity --list --checklist \
  --title="ステップ 2/2: 追加アプリの選択" \
  --text="インストールしたいアプリにチェックを入れてください（複数可）。" \
  --column="選択" --column="アプリ名" --column="説明" \
  TRUE "Python3" "プログラミング言語 & pip環境" \
  TRUE "VS Code" "ブラウザで動く code-server エディタ" \
  --width=550 --height=300)

echo "$APPS" > /tmp/user_app_choices.txt
pkill openbox

# 📦 ダウンロード＆構築処理
OS_SELECTED=$(cat /tmp/user_os_choice.txt)
APPS_SELECTED=$(cat /tmp/user_app_choices.txt)

# アプリのインストール
if echo "$APPS_SELECTED" | grep -q "Python3"; then apt-get install -y python3 python3-pip; fi
if echo "$APPS_SELECTED" | grep -q "VS Code"; then
  curl -fsSL https://code-server.dev/install.sh | sh
  systemctl enable --now code-server@root
  mkdir -p /root/.config/code-server
  echo "bind-addr: 127.0.0.1:8080" > /root/.config/code-server/config.yaml
  echo "auth: none" >> /root/.config/code-server/config.yaml
  echo "cert: false" >> /root/.config/code-server/config.yaml
fi

# OSモードの変身
if [ "$OS_SELECTED" = "Official-Full" ]; then
  apt-get install -y raspberrypi-ui-mods xinit
elif [ "$OS_SELECTED" = "Perfect-OS" ]; then
  apt-get install -y firefox-esr
  cat << 'P_EOF' > /root/.xinitrc
xsetroot -cursor_name left_ptr
openbox &
firefox-esr --window-size=960,1080 --window-position=0,0 --app=file:///root/turbowarp.html &
firefox-esr --window-size=960,1080 --window-position=960,0 --app=file:///root/sns.html &
exec openbox
P_EOF
  chmod +x /root/.xinitrc
else
  apt-get install -y firefox-esr
  cat << 'E_EOF' > /root/.xinitrc
xsetroot -cursor_name left_ptr
openbox &
pcmanfm --desktop &
pcmanfm /root &
exec openbox
E_EOF
  chmod +x /root/.xinitrc
fi

# 🌟 3. クローン・バックアップメニューの起動
# 自分自身を呼び出すために退避
cat << 'B_EOF' > /root/backup_myself.sh
#!/bin/bash
export DISPLAY=:0
export HOME=/root

WHERE_TO_SAVE=$(zenity --list \
  --title="Save Your Custom OS" \
  --text="現在の完璧な状態をどこに保存しますか？選択してください。" \
  --column="番号" --column="保存方法" --column="説明" \
  "1" "今のSDカード自体に保存" "SDカード内に『perfect_backup.img』としてバックアップ" \
  "2" "外付けのUSBメモリに保存" "挿してあるUSBメモリを丸ごと自作OSに焼き上げる" \
  --width=550 --height=250)

if [ "$WHERE_TO_SAVE" = "1" ]; then
  (
    echo "# 現在の状態をイメージ化してSDカード内のフォルダに安全に保存中..."
    dd if=/dev/zero of=/zero.small cp -v 2>/dev/null; rm -f /zero.small
    sudo dd if=/dev/mmcblk0 of=/boot/firmware/perfect_backup.img bs=4M &
    PID=$!
    while kill -0 $PID 2>/dev/null; do sleep 2; done
    echo "100"
  ) | zenity --progress --title="SDカードへ保存中" --percentage=0 --auto-close
  zenity --info --text="今のSDカードへの保存が完了しました！\n『/boot/firmware/perfect_backup.img』に保存されています。"

elif [ "$WHERE_TO_SAVE" = "2" ]; then
  TARGETS=$(lsblk -dno NAME,SIZE,MODEL | grep -v "mmcblk0")
  if [ -z "$TARGETS" ]; then
    zenity --error --title="エラー" --text="外付けのUSBメモリが見つかりません。USBポートに挿してからやり直してください。"
    exit 1
  fi

  TARGET_DEV=$(echo "$TARGETS" | zenity --list \
    --title="Select USB Storage" \
    --text="焼き付けたいUSBメモリを選んでください。\n⚠️中身はすべて消去されます！" \
    --column="デバイス名" --column="容量" --column="モデル名" \
    --width=500 --height=250)

  if [ -n "$TARGET_DEV" ]; then
    DEV_NAME=$(echo "$TARGET_DEV" | awk '{print $1}')
    DEST_DEV="/dev/$DEV_NAME"
    (
      echo "# USBメモリ($DEST_DEV)へシステムを丸ごと複製中..."
      sudo dd if=/dev/mmcblk0 of=$DEST_DEV bs=4M &
      PID=$!
      while kill -0 $PID 2>/dev/null; do sleep 2; done
      echo "100"
    ) | zenity --progress --title="USBへコピー中" --percentage=0 --auto-close
    zenity --info --text="USBメモリへの焼き付けが完了しました！"
  fi
fi

# インストーラーサービスを無効化して、次回からは普通のデスクトップが起動するようにする
sudo systemctl disable custom-installer.service
sudo reboot
B_EOF
chmod +x /root/backup_myself.sh

# バックアップ画面を呼び出す
/root/backup_myself.sh
EOF
sudo chmod +x "$ROOTFS/tmp/installer_ui.sh"

# 🌟 自動ログイン環境の強制準備 (念のためのセーフティネット)
sudo mkdir -p "$ROOTFS/etc/systemd/system/getty@tty1.service.d"
cat << 'EOF' | sudo tee "$ROOTFS/etc/systemd/system/getty@tty1.service.d/autologin.conf"
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin root --noclear %I $TERM
EOF

sudo touch "$ROOTFS/boot/ssh"
echo "=== システムサービスとしての組み込みが完了しました！ ==="
