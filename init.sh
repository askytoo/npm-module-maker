#!/bin/bash

# 環境変数を取得
# .envファイルのパスを設定
ENV_FILE="./.env"

# .envファイルが存在するかチェック
if [ -f "$ENV_FILE" ]; then
  # .envファイルの内容を読み込む
  set -o allexport
  source "$ENV_FILE"
  set +o allexport
else
  echo "$ENV_FILE does not exist."
  exit 1
fi

# モジュール名を入力
# モジュール名がすでに存在する場合はメッセージを出して再度入力を促すことを繰り返す。
cd my_modules || exit
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

# ディレクトリの作成と移動
mkdir "$moduleName"
cd "$moduleName" || exit

# Gitの初期化
git init

#リモートリポジトリの作成
# 正しく入力されるまで繰り返す
while true; do
	read -p "make remote repository? (y/n): " createRemote
	if [ "$createRemote" == "y" ] || [ "$createRemote" == "Y" ] || [ "$createRemote" == "n" ] || [ "$createRemote" == "N" ]; then
		break
	fi
	echo "input y or n."
done

if [ "$createRemote" == "y" ] || [ "$createRemote" == "Y" ]; then
	# リモートリポジトリの作成
	response=$(
		curl -L -w '\n%{http_code}' \
			-X POST \
			-H "Accept: application/vnd.github+json" \
			-H "Authorization: Bearer '$GITHUB_APIKEY'" \
			-H "X-GitHub-Api-Version: 2022-11-28" \
			https://api.github.com/user/repos \
			-d '{"name":"'$moduleName'", "private": true}'
	)
	#ステータスコードが201以外の場合はエラー
	if [ "${response: -3}" != "201" ]; then
		echo "failed to create remote repository."
		exit 1
	fi

	# リモートリポジトリの登録
	# responseからssh_urlを取得
	remoteURL=$(echo "$response" | jq -r '.ssh_url')
	echo "remoteURL: $remoteURL"
	git remote add origin "$remoteURL"

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
		read -p "remote repository URL? example:\"git@github.com:<USER_NAME>/<GIT_REPO>.git\" " remoteURL

		# リモートリポジトリの登録
		git remote add origin "$remoteURL"
	else
		remoteURL="git@github.com:'$GIT_USER'/<GIT_REPO>.git"
	fi
fi

# package.jsonの作成
cp 
echo '{
  "name": "'$moduleName'",
  "version": "0.1.0",
  "description": "'$moduleDescription'",
  "main": "dist/index.js",
  "files": [
    "dist"
  ],
  "scripts": {
    "test": "jest",
    "build": "tsc --project tsconfig.build.json",
    "prepare": "npm run build"
  },
  "repository": {
    "type": "git",
    "url": "git+ssh://'$remoteURL'"
  },
  "keywords": [],
  "author": "'$GIT_USER'",
  "license": "ISC",
  "private": true
}' >package.json

# TypeScriptの初期化

# .tsconfig.jsonの修正
echo '{
  "compilerOptions": {
    "target": "es2020",
    "lib": ["es2020", "dom"],
    "allowJs": true,
    "checkJs": true,
    "skipLibCheck": true,
    "strict": true,
    "forceConsistentCasingInFileNames": true,
    "esModuleInterop": true,
    "module": "commonjs",
    "moduleResolution": "node",
    "jsx": "react",
    "sourceMap": true,
    "rootDir": ".",
    "outDir": "./dist",
    "experimentalDecorators": true,
    "emitDecoratorMetadata": true,
    "declaration": true,
    "declarationMap": true,
    "baseUrl": "./src",
    "paths": {
      "@/*": ["./src/*"]
    },
  },
  "include": [".eslintrc.cjs", "**/*.ts", "**/*.tsx", "**/*.cjs", "**/*.mjs"],
  "exclude": ["dist", "node_modules"],
  "compileOnSave": false
}' >tsconfig.json

echo '{
  "extends": "./tsconfig.json",
  "compilerOptions": {
    "rootDir": "./src" 
  },
  "include": ["./src/**/*.ts", "./src/**/*.tsx", "./src/**/*.cjs", "./src/**/*.mjs"],
}' >tsconfig.build.json

# 必要なディレクトリの作成
mkdir src
mkdir __tests__

# index.tsの作成
touch src/index.ts

#ESlintの初期化
echo '// eslint-disable-next-line @typescript-eslint/no-var-requires
const path = require("path");

/** @type {import("eslint").Linter.Config} */
const config = {
  overrides: [
    {
      extends: [
        "plugin:@typescript-eslint/recommended-requiring-type-checking",
      ],
      files: ["*.ts", "*.tsx"],
      parserOptions: {
        project: path.join(__dirname, "tsconfig.json"),
      },
    },
  ],
  parser: "@typescript-eslint/parser",
  parserOptions: {
    project: path.join(__dirname, "tsconfig.json"),
  },
  plugins: ["@typescript-eslint"],
  extends: ["plugin:@typescript-eslint/recommended"],
  rules: {
    "@typescript-eslint/consistent-type-imports": [
      "warn",
      {
        prefer: "type-imports",
        fixStyle: "inline-type-imports",
      },
    ],
    "@typescript-eslint/no-unused-vars": ["warn", { argsIgnorePattern: "^_" }],
  },
};

module.exports = config;
' >.eslintrc.cjs

# 必要なパッケージのインストール
echo "installing packages typescript @types/node eslint @types/eslint @typescript-eslint/eslint-plugin ts-jest  @types/jest"
npm i --save-dev typescript @types/node eslint @typescript-eslint/eslint-plugin ts-jest @types/jest

# jestの初期化
echo '/** @type {import("ts-jest/dist/types").InitialOptionsTsJest} */
module.exports = {
    preset: "ts-jest",
    testEnvironment: "node",
    testPathIgnorePatterns: ["dist", "node_modules"],
};' >jest.config.js

# gitignoreの作成
echo '/node_modules
*undo
/dist
' >.gitignore

# Reactを使う場合
if [ "$useReact" == "y" ] || [ "$useReact" == "Y" ]; then
	# reactはインストールしないで、sample-viewerのnode_modules内のreactとリンクする
	echo "installing @types/react @types/react-dom prettier tailwindcss prettier-plugin-tailwindcss @types/prettier eslint-config-prettier postcss postcss-cli autoprefixer npm-run-all"
	npm i -D @types/react @types/react-dom prettier tailwindcss prettier-plugin-tailwindcss @types/prettier eslint-config-prettier postcss postcss-cli autoprefixer npm-run-all

	sed -i "/\"devDependencies\": {/i \"resolve\": {\"alias\": {\"react\": \"./node_modules/react\",\"react-dom\": \"./node_modules/rea ct-dom\"}}," "package.json"
	echo ''

	echo '/** @type {import("tailwindcsss"PostCSS).Config} */
module.exports = {
  content: ["./src/**/*.{js,ts,jsx,tsx}"],
  theme: {
    extendPostCS: {},
  },
  plugins: [],
};
' >tailwind.config.js

	echo '/** @type {import("prettier").Config} */
const config = {
  plugins: [require.resolve("prettier-plugin-tailwindcss")],
};

module.exports = config;
' >.prettierrc.cjs

	echo 'const config = {
  plugins: {
    tailwindcss: {},
    autoprefixer: {},
  },
};

module.exports = config;
' >postcss.config.js

	echo '@tailwind base;
@tailwind components;
@tailwind utilities;
' >src/index.css

	sed -i "/\"build\": \"tsc --project tsconfig.build.json\",/a \"dev\": \"npm-run-all -p watch:*\"," "package.json"
	sed -i "/\"build\": \"tsc --project tsconfig.build.json\",/a \"watch:css\": \"postcss src/index.css -o dist/index.css --watch\"," "package.json"
	sed -i "/\"build\": \"tsc --project tsconfig.build.json\",/a \"watch:ts\": \"tsc --project tsconfig.build.json --watch\"," "package.json"
	sed -i "/\"build\": \"tsc --project tsconfig.build.json\",/a \"build:css\": \"postcss src/index.css -o dist/index.css\"," "package.json"
	sed -i "/\"build\": \"tsc --project tsconfig.build.json\",/a \"build:ts\": \"tsc --project tsconfig.build.json\"," "package.json"
	sed -i "s/\"build\": \"tsc --project tsconfig.build.json\",/\"build\": \"npm run build:ts \&\& npm run build:css\",/" "package.json"

	rm src/index.ts
	# モジュール名からコンポーネント名を作成
	# -で区切られた文字列をキャメルケースに変換する
	# https://qiita.com/ryounagaoka/items/2b2e5d5d0d0c1c4b6b0e
	# 例: sample-module-name -> SampleModuleName
	componentName=$(echo "$moduleName" | sed -e "s/\(^\|-\)\([a-z]\)/\U\2/g")

	echo 'import React from "react";

const '$componentName': React.FC = () => {
  const [count, setCount] = React.useState(0);
  return (
    <div className="flex items-center justify-center h-screen flex-col">
      <div className="flex justify-center">
        <h1 className="text-4xl">'$moduleName'</h1>
      </div>
      <div className="flex justify-center text-center items-center pt-4 gap-3">
        <button
          className="rounded bg-blue-500 px-4 py-2 font-bold text-white hover:bg-blue-700"
          onClick={() => setCount(count + 1)}
        >
          Click me
        </button>
        <p>count: {count}</p>
      </div>
    </div>
  );
};

export default '$componentName';
' >src/index.tsx

	npm run build

	sudo npm link ../sample-viwer/node_modules/react
	sudo npm link

	#モジュールを確認する側(sample-viewr)の設定
	cd ../sample-viwer/ || exit
	npm i ../"$moduleName"
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
