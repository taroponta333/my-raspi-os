#!/bin/bash
# ---------------------------------------------------------
# 決定版：OS選択(ラジオボタン) ＋ アプリ選択(チェックボックス) UI搭載
# ---------------------------------------------------------

ROOTFS=$1
if [ -z "$ROOTFS" ]; then
    echo "エラー: マウント先（ROOTFS）が指定されていません。"
    exit 1
fi

echo "=== カスタムOSの構成注入を開始します ==="

# 📁 必要なフォルダを作成
sudo mkdir -p "$ROOTFS/root"
sudo mkdir -p "$ROOTFS/etc/systemd/system/getty@tty1.service.d"

# 🌟 1. 自動ログイン(rootユーザー)の設定
cat << 'EOF' | sudo tee "$ROOTFS/etc/systemd/system/getty@tty1.service.d/autologin.conf"
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin root --noclear %I $TERM
EOF

# 🌟 2. ログイン直後に画面システム（X11）を自動起動するトリガー
echo "if [ -z \"\$DISPLAY\" ] && [ \"\$(tty)\" = \"/dev/tty1\" ]; then startx; fi" | sudo tee -a "$ROOTFS/root/.bashrc"

# 🌟 3. インストーラーUIと変身機能（rc.local）
cat << 'EOF' | sudo tee "$ROOTFS/etc/rc.local"
#!/bin/sh -e

if [ -f /root/reinstall ] || [ ! -f /var/img_configured ]; then
  rm -f /var/img_configured /root/reinstall
  sleep 3
  apt-get update
  
  # 必要な最小限のパーツを導入
  apt-get install -y openbox xorg pcmanfm zenity wget curl -y

  # 🖥️ 2段階インストーラー画面を出すスクリプトを生成
  cat << 'R_EOF' > /tmp/installer_ui.sh
  #!/bin/bash
  export DISPLAY=:0
  openbox &
  
  # 🔘 【ステップ1】OSモードの選択（ラジオボタン ＝ 1つしか選べない！）
  OS_MODE=$(zenity --list --radiolist \
    --title="ステップ 1/2: OSモードの選択" \
    --text="ベースとなるOSのモードを1つだけ選んでください。" \
    --column="選択" --column="OSモード" --column="説明" \
    TRUE "Perfect-OS" "起動時に自作SNSとTurboWarpを2画面分割で即起動" \
    FALSE "Explorer-OS" "ファイルマネージャーが主役のシンプル開発画面" \
    FALSE "Official-Full" "公式のフル版デスクトップ（PIXEL環境）を入れる" \
    --width=550 --height=300)

  # キャンセルされたら離脱
  if [ -z "$OS_MODE" ]; then pkill openbox; exit 1; fi
  echo "$OS_MODE" > /tmp/user_os_choice.txt

  # ☑️ 【ステップ2】アプリの選択（チェックボックス ＝ 複数選択可能！）
  APPS=$(zenity --list --checklist \
    --title="ステップ 2/2: 追加アプリの選択" \
    --text="インストールしたいアプリにチェックを入れてください（複数可）。" \
    --column="選択" --column="アプリ名" --column="説明" \
    TRUE "Python3" "プログラミング言語 & pip環境" \
    TRUE "VS Code" "ブラウザで動く code-server エディタ" \
    --width=550 --height=300)

  echo "$APPS" > /tmp/user_app_choices.txt
  pkill openbox
R_EOF
  chmod +x /tmp/installer_ui.sh
  startx /tmp/installer_ui.sh -- :0 || true

  # 📦 選択結果に応じたインストール処理
  if [ -f /tmp/user_os_choice.txt ] && [ -f /tmp/user_app_choices.txt ]; then
    OS_SELECTED=$(cat /tmp/user_os_choice.txt)
    APPS_SELECTED=$(cat /tmp/user_app_choices.txt)
    
    # 🐍 アプリの個別インストール判定
    if echo "$APPS_SELECTED" | grep -q "Python3"; then apt-get install -y python3 python3-pip; fi
    if echo "$APPS_SELECTED" | grep -q "VS Code"; then
      curl -fsSL https://code-server.dev/install.sh | sh
      systemctl enable --now code-server@root
      mkdir -p /root/.config/code-server
      echo "bind-addr: 127.0.0.1:8080" > /root/.config/code-server/config.yaml
      echo "auth: none" >> /root/.config/code-server/config.yaml
      echo "cert: false" >> /root/.config/code-server/config.yaml
    fi

    # 🪟 OSモードの設定（ラジオボタンの結果で確実に分岐）
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
      # Explorer-OS
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
  fi

  # 💾 保存先の選択メニュー（SDカード or USB）
  cat << 'B_EOF' > /root/backup_myself.sh
#!/bin/bash
export DISPLAY=:0

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
B_EOF
  chmod +x /root/backup_myself.sh

  touch /var/img_configured
  echo "=== セットアップ完了！ ==="
  startx /root/backup_myself.sh -- :0 || true
  reboot
  exit 0
fi
exit 0
EOF
sudo chmod +x "$ROOTFS/etc/rc.local"
sudo touch "$ROOTFS/boot/ssh"

echo "=== カスタム注入が正常に完了しました！ ==="
