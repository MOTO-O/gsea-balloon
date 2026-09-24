# gsea-balloon：Git / GitHubで修正・バージョン管理する手順

2026-09-24。今回の候補バージョンは **1.2.0** です。まだ公開・タグ付けはしていません。

## 今の構成と、これから編集する場所

以前は、公開用の生成物を主にリポジトリへコピーしていました。今回、読みやすいRソースも同じリポジトリ内へ追加しました。

```text
gsea-balloon/
  app/
    app.R                  起動入口
    R/balloon_core.R        選択・クラスタリング・作図、バージョン番号
    R/ui.R                 画面の入力項目
    R/server.R             入力と作図・保存処理の接続
    R/export_helpers.R     PDF・表・Settings
    www/                   画面装飾と保存処理
    examples/              公開可能な合成データ
    run_app.R              ローカルShinyの起動
  tools/build_site.R       公開用ファイルの再生成
  tools/preview_site.R     ローカルでShinyliveを確認
  tests/test_features.R    合成データによる動作確認
  VERSION                  ビルド時に更新
  CHANGELOG.md             変更の説明
  app.json                 生成物。直接編集しない
  index.html / shinylive/  生成物。直接編集しない
```

今後は **このリポジトリの app/ を編集元にしてください**。以前のiCloud配布フォルダやCodex作業用コピーを別々に編集すると、どれが最新版か分からなくなります。

Gitのcommitは変更履歴の保存、GitHubへのPushはその履歴の共有、tagは特定のcommitに付ける版名、Releaseはその版の変更説明・配布場所です。mainは公開版、作業用branchは公開前の変更を試す場所として使います。

## 今回の変更を公開する

現在ローカルに残っていた未コミットの「PDF → Save」の保存修正も保持しています。今回の機能と合わせて確認してください。

1. RStudioで `app/run_app.R` を開いて Source を押し、合成例または自分のデータで動作を確認します。自分のデータはリポジトリ外から選択します。
2. 必要ならRStudioのTerminalで、リポジトリを作業フォルダにして `Rscript tests/test_features.R` を実行します。
3. 今回の公開用ファイルは再生成済みです。今後ソースを変更した際は `tools/build_site.R` を開き Source を押します。初回に必要なら Consoleで `install.packages("shinylive")` を実行します。
4. `tools/preview_site.R` をSourceし、ローカルのShinyliveを確認します。PDF → Saveの保存操作も確認します。終わったらRのStop/Escで停止します。
5. GitHub Desktopでgsea-balloonを選び、ChangesのRソースと生成物、説明書を確認します。実験データが混入していないことを確認します。
6. Summaryに `Add geneset filters and significance outlines (v1.2.0)` と書いて Commit to main、続いて Push origin を押します。
7. GitHubのPages更新完了後、公開URLを新しいウィンドウで開き、画面にVersion 1.2.0が表示されること、絞り込み、黒枠、PDF保存を確認します。Pagesの公開元は今の **main / (root)** のままで使えます。
8. 確認後、GitHubのリポジトリ画面 → Releases → Draft a new releaseで新しいtag `v1.2.0` を選び、Targetを今回のmainのcommitにします。Titleは `v1.2.0`、説明はCHANGELOGの内容を使います。Publish releaseで版として記録します。Release操作自体はPagesの公開処理ではありません。

公開前にブランチで確認する場合は、GitHub DesktopのCurrent Branch → New Branchで例 `feature/geneset-filter` を作り、未コミットの変更を新しいブランチへ移します。コミット後にPublish branch / Pushし、Pull Requestを作って差分を確認してからmainへmergeします。mainのPages公開設定なら、作業用ブランチをPushしただけでは公開サイトは更新されません。

## 次の変更からの推奨手順

1. GitHub Desktopでmainを選び、Fetch origin / Pull originで同期します。
2. 作業用branchを作成します。機能追加なら例 `feature/new-option`、修正なら例 `fix/export`。
3. app/のRコードを修正します。ファイル名を毎回v3、v4へ変える必要はありません。
4. `app/R/balloon_core.R` の `balloon_version()` とCHANGELOGを更新します。VERSIONと画面・Settingsへの版番号はビルド・実行時に反映されます。
5. テスト → ローカルShiny → build_site.R → ローカルShinyliveの順で確認します。
6. 編集したソースと生成物を同じcommitに含めます。小さな意味のある変更単位でcommitすると、問題が出た際に戻しやすくなります。
7. Push → Pull Requestで差分確認 → mainへmerge → 公開サイト確認 → tag / Release。

版番号の目安：不具合修正は1.2.1、新機能は1.3.0、互換性を壊す大きな変更は2.0.0。今回の1.2.0は提案した版名で、過去の公開commitへ勝手にtagを付けてはいません。

## 問題が出たときに戻す

GitHub DesktopのHistoryで該当commitを右クリックして **Revert Changes in Commit** を選び、打ち消しcommitをPushします。ソースと生成物が同じcommitなら、両方を戻せます。共有済みmainの履歴を書き換えるForce pushは通常不要です。古いtagを閲覧するだけでは公開サイトは戻りません。後続の変更に依存関係がある場合は、戻す範囲を確認してください。

## 今回の新しい設定

- **Geneset selection / Minimum padj ... cutoff**：各genesetについて、選択した比較のpadjの最小値がcutoff以下なら残します。どれか1比較で満たせばよく、全比較で有意という意味ではありません。
- **Top N genesets by minimum padj**：最小padjが小さい順のN件を残します。cutoffと併用した場合は、cutoff通過後に適用。同値はgeneset名で決め、最大N件です。
- 空欄は無効。表示順は元の順序またはクラスタリング結果を使います。クラスタリングは絞り込み後のデータで再計算します。
- padj欠損は最小値の計算から除外します。全比較で欠損なら、フィルターが有効な場合は除外します。0件なら理由を表示します。
- **Black outlines ... (0.5 pt)**：丸ごとのpadjが別途指定したcutoff以下なら黒の0.5 pt枠線を付けます。選択されたgenesetの丸を一律に囲む機能ではありません。
- 色はNES、サイズは−log10(padj)のままです。最小padjは統計的な有意性の指標で、|NES|の大きさによる順位ではありません。
- 自動の色・サイズ範囲は表示対象から計算します。図同士を比較する場合は範囲を固定してください。Settingsに選択条件・候補genesetの最小padj・順位・採否が記録されます。

## 将来の自動化

操作に慣れたら、GitHub Actionsで「テスト → Shinylive書き出し → Pages公開」を自動化すると、生成物を手動でコミットする手間を減らせます。その場合はPagesの公開元をGitHub Actionsへ切り替える設計にします。今回は既存の公開設定をそのまま使い、手動ビルドの仕組みを整えました。

通常のソース差分・変更履歴はGit、計算環境まで厳密に再現したい場合はR/パッケージ版と書き出したWebAssembly資産も保存します。今回の生成物をcommitに含める方式は、その版の配布ファイルを残せますが、将来の再ビルドが全く同じ依存パッケージを選ぶ保証ではありません。

公式資料：
- [GitHub Desktopのブランチ管理](https://docs.github.com/en/desktop/making-changes-in-a-branch/managing-branches-in-github-desktop)
- [GitHubのRelease管理](https://docs.github.com/en/repositories/releasing-projects-on-github/managing-releases-in-a-repository)
- [GitHub Desktopでcommitを戻す](https://docs.github.com/en/desktop/managing-commits/reverting-a-commit-in-github-desktop)
- [Shinylive書き出しとGitHub Pages](https://posit-dev.github.io/r-shinylive/)
