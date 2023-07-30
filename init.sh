#!/bin/bash

commonPackages=(
	"typescript"
	"@types/node"
	"eslint"
	"@typescript-eslint/eslint-plugin"
	"ts-jest"
	"@types/jest"
)

# reactはインストールしないで、sample-viewerのnode_modules内のreactとリンクする
reactPackages=(
	"@types/react"
	"@types/react-dom"
	"prettier"
	"tailwindcss"
	"prettier-plugin-tailwindcss"
	"@types/prettier"
	"eslint-config-prettier"
	"postcss"
	"postcss-cli"
	"autoprefixer"
	"npm-run-all"
)

# このファイルがあるディレクトリを取得
startDir=$(pwd)

# 環境変数を取得
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

# GIT_USERが設定されているかチェック
# GIT_USERが設定されていない場合は終了する
if [ -z "$GIT_USER" ]; then
	echo "GIT_USER is not set. please set GIT_USER in .env file."
	exit 1
fi

# MODULES_DIRディレクトリが存在するかチェック
# MODULES_DIRディレクトリが存在しない場合は終了する
if [ ! -d "$MODULES_DIR" ]; then
	echo "modules directory does not exist. please create modules directory or set MODULES_DIR in .env file."
	exit 1
fi

# モジュールのディレクトリに移動
cd "$MODULES_DIR" || exit 1

# モジュール名を入力
# モジュール名がすでに存在する場合はメッセージを出して再度入力を促すことを繰り返す。
while true; do
	read -p "module name? " moduleName
	if [ -d "$moduleName" ]; then
		echo "module name already exists."
	else
		break
	fi
done

# モジュールの説明を入力
read -p "module description? " moduleDescription

# Reactを使用するかどうかを入力
# 正しく入力されるまで繰り返す
while true; do
	read -p "use React? (y/n): " useReact
	if [ "$useReact" == "y" ] || [ "$useReact" == "Y" ] || [ "$useReact" == "n" ] || [ "$useReact" == "N" ]; then
		break
	fi
	echo "input y or n."
done

# Reactを使用する場合は
if [ "$useReact" == "y" ] || [ "$useReact" == "Y" ]; then

	# VIEWER_DIRディレクトリが存在するかチェック
	# VIEWER_DIRディレクトリが存在しない場合は終了する
	if [ ! -d "$VIEWER_DIR" ]; then
		echo "sample viewer directory does not exist. please create sample viewer directory by Next.js or set VIEWER_DIR in .env file."
		exit 1
	fi

fi

#リモートリポジトリの作成
# 正しく入力されるまで繰り返す
while true; do
	read -p "create remote repository? (y/n): " createRemote
	if [ "$createRemote" == "y" ] || [ "$createRemote" == "Y" ] || [ "$createRemote" == "n" ] || [ "$createRemote" == "N" ]; then
		break
	fi
	echo "input y or n."
done

if [ "$createRemote" == "y" ] || [ "$createRemote" == "Y" ]; then
	#GITHUB_API_KEYが設定されているかチェック
	#設定されていない場合は終了する
	if [ -z "$GITHUB_API_KEY" ]; then
		echo "GITHUB_API_KEY is not set. please set GITHUB_API_KEY in .env file."
		exit 1
	fi

	# リモートリポジトリの作成
	response=$(
		curl -L -w '\n%{http_code}' \
			-X POST \
			-H "Accept: application/vnd.github+json" \
			-H "Authorization: Bearer $GITHUB_API_KEY" \
			-H "X-GitHub-Api-Version: 2022-11-28" \
			https://api.github.com/user/repos \
			-d '{"name":"'$moduleName'", "private": true}'
	)
	#ステータスコードが201以外の場合はエラー
	if [ "${response: -3}" != "201" ]; then
		echo "failed to create remote repository. please check GITHUB_API_KEY in .env file and try again later."
		echo "response: $response"
		exit 1
	fi

	echo "remote repository created."

	# responseからssh_urlを取得
	remoteURL=$(echo "$response" | grep -oP '(?<="ssh_url": ")[^"]+')

else
	# リモートリポジトリの登録を問い合わせ
	# 正しく入力されるまで繰り返す
	while true; do
		read -p "register remote repository? (y/n): " registerRemote
		if [ "$registerRemote" == "y" ] || [ "$registerRemote" == "Y" ] || [ "$registerRemote" == "n" ] || [ "$registerRemote" == "N" ]; then
			break
		fi
		echo "input y or n."
	done

	if [ "$registerRemote" == "y" ] || [ "$registerRemote" == "Y" ]; then
		# リモートリポジトリのURLを入力
		read -p "remote repository URL? example:\"git@github.com:<GIT_USER>/<GIT_REPO>.git\" " remoteURL

		# リモートリポジトリの登録
		git remote add origin "$remoteURL"
		echo "remote repository registered."
	else
		remoteURL="git@github.com:'$GIT_USER'/<GIT_REPO>.git"
	fi
fi

# ディレクトリの作成と移動
mkdir "$MODULES_DIR/$moduleName" && echo "$moduleName directory created in $MODULES_DIR."
cd "$MODULES_DIR/$moduleName" || exit 1

# カレントディレクトリの取得
newModuleDir=$(pwd)

# Gitの初期化
git init

# リモートリポジトリの登録
git remote add origin "$remoteURL" && echo "remote repository registered."

# tsconfig.jsonの作成
cp "$startDir"/tmp/tsconfig.json.tmp ./tsconfig.json

# tsconfig.build.jsonの作成
cp "$startDir"/tmp/tsconfig.build.json.tmp ./tsconfig.build.json

# 必要なディレクトリの作成
mkdir src
mkdir __tests__

# .eslintrc.cjsの作成
cp "$startDir"/tmp/.eslintrc.cjs.tmp ./.eslintrc.cjs

# jest.config.jsの作成
cp "$startDir"/tmp/jest.config.js.tmp ./jest.config.js

# gitignoreの作成
cp "$startDir"/tmp/.gitignore.tmp ./.gitignore

# Reactを使うかどうかで処理を分岐
if [ "$useReact" == "n" ] || [ "$useReact" == "N" ]; then
	# Reactを使わない場合
	# package.jsonの作成
	cp "$startDir"/tmp/package.json.tmp ./package.json

	# package.jsonの修正
	sed -i -e "s/<MODULE_NAME>/$moduleName/g" ./package.json
	sed -i -e "s/<MODULE_DESCRIPTION>/$moduleDescription/g" ./package.json
	sed -i -e "s/<GIT_USER>/$GIT_USER/g" ./package.json
	sed -i -e "s/<REMOTE_URL>/$remoteURL/g" ./package.json

	# 必要なパッケージのインストール
	echo "installing packages ${commonPackages[*]}"
	npm i -D "${commonPackages[*]}"

	# index.tsの作成
	touch src/index.ts

else
	# Reactを使う場合
	# package.jsonの作成
	cp "$startDir"/tmp/package.json.r.tmp ./package.json
	sed -i -e "s/<MODULE_NAME>/$moduleName/g" ./package.json
	sed -i -e "s/<MODULE_DESCRIPTION>/$moduleDescription/g" ./package.json
	sed -i -e "s/<GIT_USER>/$GIT_USER/g" ./package.json
	sed -i -e "s/<REMOTE_URL>/$remoteURL/g" ./package.json

	# commonPackagesとreactPackagesを結合
	packages=("${commonPackages[*]} ${reactPackages[*]}")
	echo "installing packages ${packages[*]}"
	npm i -D ${packages[*]}

	# tailwind.config.jsの作成
	cp "$startDir"/tmp/tailwind.config.js.r.tmp ./tailwind.config.js

	# .prettierrc.cjsの作成
	cp "$startDir"/tmp/.prettierrc.cjs.r.tmp ./.prettierrc.cjs

	# postcss.config.jsの作成
	cp "$startDir"/tmp/postcss.config.js.r.tmp ./postcss.config.js

	echo '@tailwind base;
@tailwind components;
@tailwind utilities;
' >src/index.css

	# モジュール名からコンポーネント名を作成
	# -で区切られた文字列をキャメルケースに変換する
	# https://qiita.com/ryounagaoka/items/2b2e5d5d0d0c1c4b6b0e
	# 例: sample-module-name -> SampleModuleName
	componentName=$(echo "$moduleName" | sed -e "s/\(^\|-\)\([a-z]\)/\U\2/g")

	# src/index.tsxの作成
	cp "$startDir"/tmp/index.tsx.r.tmp ./src/index.tsx
	sed -i -e "s/<MODULE_NAME>/$moduleName/g" ./src/index.tsx
	sed -i -e "s/<COMPONENT_NAME>/$componentName/g" ./src/index.tsx

	npm run build

	sudo npm link "$VIEWER_DIR"/node_modules/react
	sudo npm link

	#モジュールを確認する側(sample-viewr)の設定
	cd "$VIEWER_DIR" || exit 1
	npm i "$newModuleDir"
	sudo npm link "$moduleName"

	sed -i "/const modules = \[/a {name: '$moduleName', path: '\/$moduleName'}," "src/pages/index.tsx"

	touch src/pages/"$moduleName".tsx

	echo 'import { NextPage } from "next";
import '$componentName' from "'$moduleName'";
import "'$moduleName'/dist/index.css";

const '$componentName'Viwer: NextPage = () => {
  return (
    <div>
      <'$componentName' />
    </div>
  );
};

export default '$componentName'Viwer;
' >src/pages/"$moduleName".tsx
fi

# 完了メッセージの表示
echo "complete!!!"
