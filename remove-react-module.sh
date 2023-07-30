#!/bin/bash

# React Component Module用に作成したものを削除していく
# モジュール名を入力
# モジュール名がすでに存在する場合はメッセージを出して再度入力を促すことを繰り返す。
# .envファイルのパスを設定
ENV_FILE="./.env"

# .envファイルが存在するかチェック
if [ -f "$ENV_FILE" ]; then
	# .envファイルの内容を読み込む
	# GITHUB_API_KEY
	# GIT_USER
	# MODULES_DIR(full path)
	# VIEWR_DIR(full path)
	set -o allexport
	source "$ENV_FILE"
	set +o allexport
else
	echo "$ENV_FILE does not exist. please create .env file from .env.tmp file."
	exit 1
fi

cd "$MODULES_DIR" || exit 1
while true; do
	read -p "remove module name? " moduleName
	if [ -d "$moduleName" ]; then
		break
	else
		echo "module name does not exist."
	fi
done

#  モジュールのソースディレクトリを削除
rm -rf "$moduleName" && echo "remove $moduleName directory."

# 確認側の設定を削除する
cd "$VIEWER_DIR" || exit 1

# モジュールを削除
sudo npm unlink "$moduleName" && echo "remove $moduleName from sample-viwer."

# pages/index.tsx内のモジュールを削除
sed -i "/{name: '$moduleName', path: '\/$moduleName'},/d" "src/pages/index.tsx" && echo "remove $moduleName from pages/index.tsx."

# pages/$moduleName.tsxを削除
rm "src/pages/$moduleName.tsx" && echo "remove $moduleName.tsx from pages."

# シンボリックリンクを削除
sudo rm -r -f /usr/lib/node_modules/"$moduleName" && echo "remove $moduleName from /usr/lib/node_modules."

echo "remove $moduleName module complete."
