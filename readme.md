
これは何？
--

リンカです。今のところルネサスRXマイコンのELFオブジェクトに対応しています。
コンパイラ・開発環境としてCS+を想定しています。
(2018/9/20現在)


使い方
--
1).setup.shを実行します。
./setup.sh

setup.sh ではRubyの拡張モジュールのビルドと配置を行います。
rubyがビルドできる環境があれば拡張モジュールはビルドできるはずです。
Debian/Ubuntu系の環境だと、
$sudo apt install ruby-dev
でrubyのビルドに必要なファイルがインストールされます。

正常にビルドが終了するとelf32.soというライブラリが生成され、ELFフォルダに配置されます。
リンカを動かすのに必要な準備は以上です。

2).リンカの実行
app.rbがエントリポイントです。
コマンドライン引数で .clnkファイルを指定すると .clnkファイルの内容に従ってリンクを行います。

実行例)
./app.rb  test/led/one_file/DefaultBuild/sakura2.clnk
リンクが終了すると、.clnkの-outputで指定したファイルが出力されます。

3).書き込み
リンクしたファイル(.abs)をE1エミュレータ等をターゲットボードに書き込み、プログラムを実行してください。

サンプルについて
--
test/led フォルダ以下にGR-SAKURAで動作確認をしたサンプルプロジェクト一式があります。
https://github.com/simotin13/rb_linker/tree/master/test/led

- one_file
１ファイル(resetprg.obj)のみをリンクするサンプルです。
DefaultBuild/sakura.clnkファイルを指定してリンクします。
リンクが終了するとDefaultBuild/sakura.absが出力されます。※CS+でビルド済みのsakura.absを上書きします。

- two_files
DefaultBuild/resetprg.objとDefaultBuild/main.objをリンクします。
