# （前回のアプリインストール処理がすべて終わった直後の位置に追加）
  
  # 💾 自分で自分をバックアップ・上書きするための専用スクリプトを作成
  cat << 'B_EOF' > /root/backup_myself.sh
  #!/bin/bash
  export DISPLAY=:0
  
  zenity --question \
    --title="System Backup & Lock" \
    --text="アプリの導入と改変が完了しました。\n現在の状態を『完成版OSイメージ』としてSDカード自身の空き領域（またはUSBメモリ）に上書き保存しますか？\n（次回からダウンロード不要で一瞬で起動するようになります）" \
    --width=400
  
  if [ $? -eq 0 ]; then
    # 🌟 現在のSDカード（/dev/mmcblk0）を丸ごとイメージ化して保存する魔法のコマンド
    # 進行状況をプログレスバーで表示します
    (
      echo "# システムをイメージ化しています...（数分かかります）"
      # 不要なゴミデータを消してイメージを軽量化
      dd if=/dev/zero of=/zero.small cp -v 2>/dev/null; rm -f /zero.small
      
      # 実際のバックアップ実行（バックグラウンドで処理し、進捗を送る）
      sudo dd if=/dev/mmcblk0 of=/boot/firmware/perfect_backup.img bs=4M &
      PID=$!
      while kill -0 $PID 2>/dev/null; do
        echo "# 書き込み中... じわじわ進行しています..."
        sleep 2
      done
      echo "100"
      echo "# バックアップが完了しました！"
    ) | zenity --progress --title="バックアップ中" --percentage=0 --auto-close

    zenity --info --title="完了" --text="『perfect_backup.img』が保存されました！\n次回からはこのファイルを焼くだけで、今作った環境が1秒で復元されます。" --width=300
  fi
B_EOF
  chmod +x /root/backup_myself.sh

  # 完了フラグを立てて、最後に「バックアップしますか？」のUIを画面に出す
  touch /var/img_configured
  startx /root/backup_myself.sh -- :0 || true
  
  reboot
  exit 0
