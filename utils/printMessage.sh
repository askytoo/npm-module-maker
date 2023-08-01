# messageを出力する関数を定義
printError() {
  # エラーメッセージを引数から取得
  errorMessage="$1"

  # 赤色の文字を出力
  echo -e "\n\e[31mError: $errorMessage\e[0m"
}

printInfo() {
  # エラーメッセージを引数から取得
  infoMessage="$1"

  # 青色の文字を出力
  echo -e "\n\e[34mInfo: $infoMessage\e[0m"
}

printWarning() {
  # エラーメッセージを引数から取得
  warningMessage="$1"

  # 黄色の文字を出力
  echo -e "\n\e[33mWarning: $warningMessage\e[0m"
}

