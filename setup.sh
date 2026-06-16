#!/bin/bash
# ---------------------------------------------------------
# 容量エラー回避版：OS変身＆チェックボックス＆バックアップ機能
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
  
  # 最小限の画面パーツとUIツール（Zenity）を導入
  apt-get install -y openbox xorg pcmanfm zenity wget curl -y

  # 🖥️ チェックボックス画面を出すスクリプト
  cat << 'R_EOF' > /tmp/installer_ui.sh
  #!/bin/bash
  export DISPLAY=:0
  openbox &
  
  # 🌟 OSのモードとアプリを同時にポチポチ選べるUI
  CHOICES=$(zenity --list --checklist \
    --title="Custom OS Mode & App Installer" \
    --text="なりたいOSの形と、入れたいアプリを選んで『OK』を押してください。" \
    --column="選択" --column="項目" --column="説明" \
    TRUE "Perfect-OS" "【OSモード】起動時に自作SNSとTurboWarpを2画面分割で即起動" \
    FALSE "Explorer-OS" "【OSモード】ファイルマネージャーが主役のシンプル開発画面" \
    FALSE "Official-Full" "【OSモード】公式のフル版デスクトップ（PIXEL環境）を入れる" \
    TRUE "Python3" "[アプリ] プログラミング言語 & pip環境" \
    TRUE "VS Code" "[アプリ] ブラウザで動く code-server エディタ" \
    --width=550 --height=400)

  echo "$CHOICES" > /tmp/user_choices.txt
  pkill openbox
R_EOF
  chmod +x /tmp/installer_ui.sh
  startx /tmp/installer_ui.sh -- :0 || true

  # 選択結果に応じた処理
  if [ -f /tmp/user_choices.txt ]; then
    SELECTED=$(cat /tmp/user_choices.txt)
    
    # 🐍 アプリのインストール
    if echo "$SELECTED" | grep -q "Python3"; then apt-get install -y python3 python3-pip; fi
    if echo "$SELECTED" | grep -q "VS Code"; then
      curl -fsSL https://code-server.dev/install.sh | sh
      systemctl enable --now code-server@root
      mkdir -p /root/.config/code-server
      echo "bind-addr: 127.0.0.1:8080" > /root/.config/code-server/config.yaml
      echo "auth: none" >> /root/.config/code-server/config.yaml
      echo "cert: false" >> /root/.config/code-server/config.yaml
    fi

    # 🪟 OSモードの変身処理
    if echo "$SELECTED" | grep -q "Official-Full"; then
      # 公式フルデスクトップをその場でダウンロードして変身
      apt-get install -y raspberrypi-ui-mods xinit
    elif echo "$SELECTED" | grep -q "Perfect-OS"; then
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
      # デフォルト：Explorer-OS
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

  # 💾 最後に「自分自身をSDカードに上書き保存する」バックアップツールを用意
  cat << 'B_EOF' > /root/backup_myself.sh
#!/bin/bash
export DISPLAY=:0
zenity --question --title="Save System" --text="改変が完了しました。現在の状態を『完成版OSイメージ』としてSDカード自身に上書き固定しますか？\n（次回からダウンロード不要になります）" --width=400
if [ $? -eq 0 ]; then
  (
    echo "# 現在の状態をイメージ化してSDカード自身に上書き中..."
    dd if=/dev/zero of=/zero.small cp -v 2>/dev/null; rm -f /zero.small
    sudo dd if=/dev/mmcblk0 of=/boot/firmware/perfect_backup.img bs=4M &
    PID=$!
    while kill -0 $PID 2>/dev/null; do sleep 2; done
    echo "100"
  ) | zenity --progress --title="バックアップ中" --percentage=0 --auto-close
  zenity --info --text="上書き固定が完了しました！\n次回からはこの『perfect_backup.img』を焼くだけで復元できます。"
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
