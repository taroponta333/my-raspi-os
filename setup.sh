#!/bin/bash
# ---------------------------------------------------------
# 再インストール機能付き カスタム注入スクリプト
# ---------------------------------------------------------

ROOTFS=$1

if [ -z "$ROOTFS" ]; then
    echo "エラー: マウント先（ROOTFS）が指定されていません。"
    exit 1
fi

echo "=== 自作OSのカスタム注入を開始します ==="

# 🌟 1. 起動時にファイルマネージャー(PCManFM)を自動起動する設定
sudo mkdir -p "$ROOTFS/root"
cat << 'EOF' | sudo tee "$ROOTFS/root/.xinitrc"
# マウスカーソルを表示
xsetroot -cursor_name left_ptr
# ウィンドウマネージャーを起動
openbox &
# ファイルマネージャーを起動
pcmanfm --desktop &
pcmanfm /root &
exec openbox
EOF
sudo chmod +x "$ROOTFS/root/.xinitrc"

# 🌟 2. ログイン画面をパスして自動ログイン(root)にする設定
sudo mkdir -p "$ROOTFS/etc/systemd/system/getty@tty1.service.d"
cat << 'EOF' | sudo tee "$ROOTFS/etc/systemd/system/getty@tty1.service.d/autologin.conf"
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin root --noclear %I $TERM
EOF

# 🌟 3. CUIログイン直後に自動でグラフィック画面(X11)を立ち上げる設定
echo "if [ -z \"\$DISPLAY\" ] && [ \"\$(tty)\" = \"/dev/tty1\" ]; then startx; fi" | sudo tee -a "$ROOTFS/root/.bashrc"

# 🌟 4. 【進化版】再インストール機能付きの自動セットアップ（rc.local）
cat << 'EOF' | sudo tee "$ROOTFS/etc/rc.local"
#!/bin/sh -e

# 💡 再インストール（リセット）の判定
# 「/root/reinstall」というファイルが存在するか、まだ一度も設定されていない場合
if [ -f /root/reinstall ] || [ ! -f /var/img_configured ]; then
  echo "=== セットアップまたは再インストールを開始します ==="
  
  # 再インストール時は、一度古い目印を消す
  rm -f /var/img_configured
  rm -f /root/reinstall

  # ネットワークの準備を少し待つ
  sleep 5
  apt-get update
  
  # Python3、ブラウザ、ファイルマネージャー、画面パーツを強制的に上書き・再導入
  apt-get install -y --reinstall python3 python3-pip openbox xorg pcmanfm firefox-esr wget curl
  
  # VS Code (code-server) を最新版に再インストール
  curl -fsSL https://code-server.dev/install.sh | sh
  systemctl enable --now code-server@root
  
  # VS Codeの設定ファイルを再構築
  mkdir -p /root/.config/code-server
  echo "bind-addr: 127.0.0.1:8080" > /root/.config/code-server/config.yaml
  echo "auth: none" >> /root/.config/code-server/config.yaml
  echo "cert: false" >> /root/.config/code-server/config.yaml

  # 完了の目印を作成
  touch /var/img_configured
  echo "=== セットアップが完了しました。再起動します ==="
  reboot
  exit 0
fi

exit 0
EOF
sudo chmod +x "$ROOTFS/etc/rc.local"

# 🌟 5. 遠隔操作用のSSHを有効化
sudo touch "$ROOTFS/boot/ssh"

echo "=== カスタム注入が正常に完了しました！ ==="
