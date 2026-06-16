#!/bin/bash
# ---------------------------------------------------------
# チェックボックスUI付き トリプルマルチブート対応スクリプト
# ---------------------------------------------------------

ROOTFS=$1
if [ -z "$ROOTFS" ]; then
    echo "エラー: マウント先（ROOTFS）が指定されていません。"
    exit 1
fi

echo "=== カスタムOSの構成注入を開始します ==="

# 📁 必要なフォルダを自動作成
sudo mkdir -p "$ROOTFS/root"
sudo mkdir -p "$ROOTFS/etc/systemd/system/getty@tty1.service.d"

# 🌟 1. 起動時にファイルマネージャー(PCManFM)を自動起動する設定 (Explorer OS用)
cat << 'EOF' | sudo tee "$ROOTFS/root/.xinitrc.explorer"
xsetroot -cursor_name left_ptr
openbox &
pcmanfm --desktop &
pcmanfm /root &
exec openbox
EOF
sudo chmod +x "$ROOTFS/root/.xinitrc.explorer"

# 🌟 2. 2画面分割で自動起動する設定 (Perfect OS用)
cat << 'EOF' | sudo tee "$ROOTFS/root/.xinitrc.perfect"
xsetroot -cursor_name left_ptr
openbox &
firefox-esr --window-size=960,1080 --window-position=0,0 --app=file:///root/turbowarp.html &
firefox-esr --window-size=960,1080 --window-position=960,0 --app=file:///root/sns.html &
exec openbox
EOF
sudo chmod +x "$ROOTFS/root/.xinitrc.perfect"

# 🌟 3. 自動ログイン(rootユーザー)の設定
cat << 'EOF' | sudo tee "$ROOTFS/etc/systemd/system/getty@tty1.service.d/autologin.conf"
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin root --noclear %I $TERM
EOF

# 🌟 4. CUIログイン直後に画面システム(X11)を自動スタートさせる設定
cat << 'EOF' | sudo tee "$ROOTFS/root/.bashrc_trigger"
if [ -z "$DISPLAY" ] && [ "$(tty)" = "/dev/tty1" ]; then
    if [ -f /root/mode_perfect ]; then
        cp /root/.xinitrc.perfect /root/.xinitrc
    else
        cp /root/.xinitrc.explorer /root/.xinitrc
    fi
    startx
fi
EOF
cat "$ROOTFS/root/.bashrc_trigger" | sudo tee -a "$ROOTFS/root/.bashrc"

# 🌟 5. 【大改造】起動直後にチェックボックス画面を表示して、アプリを選択インストールする仕組み（rc.local）
cat << 'EOF' | sudo tee "$ROOTFS/etc/rc.local"
#!/bin/sh -e

if [ -f /root/reinstall ] || [ ! -f /var/img_configured ]; then
  echo "=== インストーラーUIの準備中 ==="
  rm -f /var/img_configured /root/reinstall
  sleep 3
  apt-get update
  
  # インストーラー画面（Zenity）とデスクトップ環境に必要な最小限のパーツを先に導入
  apt-get install -y openbox xorg pcmanfm zenity wget curl -y

  # 🖥️ グラフィック画面の裏で、チェックボックス画面を立ち上げるスクリプトをその場で作成
  cat << 'R_EOF' > /tmp/installer_ui.sh
  #!/bin/bash
  export DISPLAY=:0
  openbox &
  
  # 🌟 ここでマウス操作ができるチェックボックス画面を出現させます！
  CHOICES=$(zenity --list --checklist \
    --title="Custom OS App Installer" \
    --text="インストールしたいアプリにチェックを入れて『OK』を押してください。" \
    --column="選択" --column="アプリ名" --column="説明" \
    TRUE "Python3" "プログラミング言語 & pip環境" \
    TRUE "Firefox" "自作SNSやTurboWarpを開く軽量ブラウザ" \
    TRUE "VS Code" "ブラウザで動く code-server エディタ" \
    --width=500 --height=350)

  # ユーザーが選んだ結果（カンマ区切り）を保存
  echo "$CHOICES" > /tmp/user_choices.txt
  pkill openbox
R_EOF
  chmod +x /tmp/installer_ui.sh

  # 画面システム（X11）上でインストーラーUIを起動
  startx /tmp/installer_ui.sh -- :0 || true

  # 選択結果の読み込み
  if [ -f /tmp/user_choices.txt ]; then
    SELECTED=$(cat /tmp/user_choices.txt)
    
    # 🐍 Python3 のインストール判定
    if echo "$SELECTED" | grep -q "Python3"; then
      echo "--> Python3をインストール中..."
      apt-get install -y python3 python3-pip
    fi

    # 🌐 Firefox のインストール判定
    if echo "$SELECTED" | grep -q "Firefox"; then
      echo "--> Firefoxをインストール中..."
      apt-get install -y firefox-esr
    fi

    # 💻 VS Code のインストール判定
    if echo "$SELECTED" | grep -q "VS Code"; then
      echo "--> VS Codeをインストール中..."
      curl -fsSL https://code-server.dev/install.sh | sh
      systemctl enable --now code-server@root
      mkdir -p /root/.config/code-server
      echo "bind-addr: 127.0.0.1:8080" > /root/.config/code-server/config.yaml
      echo "auth: none" >> /root/.config/code-server/config.yaml
      echo "cert: false" >> /root/.config/code-server/config.yaml
    fi
  fi

  # 完了フラグを立てて再起動
  touch /var/img_configured
  echo "=== すべての選択セットアップが完了しました！ ==="
  reboot
  exit 0
fi
exit 0
EOF
sudo chmod +x "$ROOTFS/etc/rc.local"
sudo touch "$ROOTFS/boot/ssh"

echo "=== カスタム注入が正常に完了しました！ ==="
