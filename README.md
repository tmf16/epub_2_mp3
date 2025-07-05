# epub_2_mp3

このプロジェクトは、EPUBファイルをテキストファイルに変換し、さらにテキストファイルをMP3ファイルに変換するための一連のRubyスクリプトを提供します。

## 概要

このプロジェクトには、2つの主要なRubyスクリプトが含まれています。

1.  `epub_2_text.rb`: EPUBファイルを章ごとにテキストファイルに分割して出力します。
2.  `text_2_mp3.rb`: テキストファイルをOpenAIのTTS（Text-to-Speech）APIを使用してMP3ファイルに変換します。

## セットアップ

### 必要なツール

*   Ruby
*   Bundler
*   ffmpeg

### インストール

1.  依存関係をインストールします。

    ```bash
    bundle install
    ```

2.  OpenAIのAPIキーを環境変数 `OPENAI_API_KEY` に設定します。

    ```bash
    export OPENAI_API_KEY='YOUR_OPENAI_API_KEY'
    ```
    または、`.env` ファイルを作成し、その中に `OPENAI_API_KEY=YOUR_OPENAI_API_KEY` と記述します。

## 使用方法

### 1. EPUBからテキストへ (`epub_2_text.rb`)

`epub_2_text.rb`スクリプトは、指定されたEPUBファイルを処理し、テキストファイルを出力します。

**テキスト整形について:**
`epub_2_text.rb`内の`EpubProcessor.clean_and_format_lines`メソッドは、EPUBから抽出したテキスト行を整形するためのものです。書籍によって不要な情報やフォーマットが異なるため、このメソッドはユーザーが書籍ごとにカスタマイズすることを想定しています。デフォルトでは、各行の前後空白を削除し、空行を除去するのみの処理となっています。必要に応じて`epub_2_text.rb`内のコメントアウトされたサンプルコードを参考に、このメソッドを編集してください。

**基本的な使い方:**
`files/text/` ディレクトリにテキストファイルを出力します。

```bash
ruby epub_2_text.rb <EPUBファイルパス>
```

例:
```bash
ruby epub_2_text.rb files/epub/sample.epub
```

**出力先ディレクトリを指定する場合:**
指定したディレクトリにテキストファイルを出力します。ディレクトリが存在しない場合は自動的に作成されます。

```bash
ruby epub_2_text.rb <EPUBファイルパス> <出力先ディレクトリ>
```

例:
```bash
ruby epub_2_text.rb files/epub/sample.epub my_texts/
```

### 2. テキストからMP3へ (`text_2_mp3.rb`)

`text_2_mp3.rb`スクリプトは、指定されたテキストファイルをOpenAIのTTS（Text-to-Speech）APIを使用してMP3ファイルに変換します。

**基本的な使い方:**
`files/mp3/` ディレクトリにMP3ファイルを出力します。

```bash
ruby text_2_mp3.rb <テキストファイルパス>
```

例:
```bash
ruby text_2_mp3.rb files/text/001_chapter_01.txt
```

**出力先ディレクトリを指定する場合:**
指定したディレクトリにMP3ファイルを出力します。ディレクトリが存在しない場合は自動的に作成されます。

```bash
ruby text_2_mp3.rb <テキストファイルパス> <出力先ディレクトリ>
```

例:
```bash
ruby text_2_mp3.rb files/text/001_chapter_01.txt my_mp3s/
```

これにより、`files/tmp`ディレクトリに一時的なMP3ファイルが作成され、最終的に指定された出力ディレクトリに結合されたMP3ファイルが出力されます。

## テスト用EPUBについて
本リポジトリには、パブリックドメインになっている福沢諭吉『学問のすゝめ』のEPUBを含めています。
- 作品: 『学問のすゝめ』（福沢諭吉、1872年刊）
- 配布元：[提灯書庫 青空文庫 EPUB mobi置き場](https://kyukyunyorituryo.github.io/bookshelf/)
