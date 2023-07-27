#!/bin/bash

# React Component Module用に作成したものを削除していく
# モジュール名を入力
# モジュール名がすでに存在する場合はメッセージを出して再度入力を促すことを繰り返す。
cd my_modules || exit
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
cd sample-viwer || exit 

# モジュールを削除
sudo npm unlink "$moduleName" && echo "remove $moduleName from sample-viwer."

# pages/index.tsx内のモジュールを削除
sed -i "/{name: '$moduleName', path: '\/$moduleName'},/d" "src/pages/index.tsx" && echo "remove $moduleName from pages/index.tsx."

# pages/$moduleName.tsxを削除
rm "src/pages/$moduleName.tsx" && echo "remove $moduleName.tsx from pages."

# シンボリックリンクを削除
sudo rm -r -f /usr/lib/node_modules/"$moduleName" && echo "remove $moduleName from /usr/lib/node_modules."

echo "remove $moduleName module complete."
