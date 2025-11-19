# QuarterlyReportSummaryController

## 1. 概要
QuarterlyReportSummaryController クラスは、FiscalYear__c を起点に四半期および通期の入出金を集計し、FiscalYear__c と FundFiscalYear__c の各種集計項目を更新するフロー呼び出し用ユーティリティです。

## 2. 基本情報
* **クラス名:** QuarterlyReportSummaryController
* **アクセス修飾子:** public
* **関連オブジェクト:** FiscalYear__c, FundFiscalYear__c, FundTransaction__c
* **対応するDMLイベント:** なし（InvocableMethod）
* **主な外部クラスの呼び出し:** なし

## 2.1 内部クラス (Inner Classes)
* **クラス名:** Params
  * **アクセス修飾子:** public
  * **説明:** フローから渡される対象年度と集計期間（月数）を受け取るデータ転送用クラス。
  * **変数:** recordId（対象 FiscalYear__c）、terms（集計対象月数）

---

## 3. メソッド一覧
| メソッド名 | 修飾子 | 引数 | 戻り値 | 説明 |
| :--- | :--- | :--- | :--- | :--- |
| `QuarterlyReportSummary` | `public` `static` | `List<Params> params` | `List<String>` | 指定した年度の FundTransaction__c を集計し、FiscalYear__c / FundFiscalYear__c を更新して処理結果メッセージを返す。 |

---

## 4. 詳細設計

### 4.1 QuarterlyReportSummary メソッド
1. `params[0].recordId` から対象 FiscalYear__c を取得し、紐づく FundFiscalYear__c を一括取得して Map 化する。
2. `params[0].terms`（3/6/9/12 ヵ月）に合わせて Q1～Q4 の日付範囲を計算し、各四半期の開始/終了日文字列を組み立てる。
3. FundTransaction__c を 17 種類の種別（前年度繰越、寄付金収入 Q1～Q4、返還金、振替入金、雑収入、決定事業 Q1～Q4、決定前/既決定事業、振替出金、事業外手数料、雑支出、次年度繰越など）に分けて SOQL で取得する。各クエリでは FundFiscalYear__c の年度や基金状態、SlipCreatedDate__c などでフィルタする。
4. FiscalYear__c の集計フィールドと FundFiscalYear__c ごとの集計値を初期化し、取得済みトランザクションをカテゴリごとにループして Amount1__c / Amount2__c を加算する。四半期単位のカテゴリは `params[0].terms` に応じて処理を限定する。
5. 各 FundTransaction__c の `ChkBox__c` フラグを false に戻し、更新対象リスト `updateFundTransaction` に追加して後続処理に備える（2025/10/2 時点では FundTransaction 更新はコメントアウト）。
6. すべてのカテゴリ集計が完了したら FiscalYear__c と FundFiscalYear__c を update し、成功メッセージを返却する。例外が発生した場合は catch で失敗メッセージを返す。

---

## 5. エラー処理
* 全体処理を try-catch で囲み、例外発生時は `'集計処理が失敗しました: ' + e.getMessage()` を返却する。
* FundTransaction 更新はコメントアウトされており、誤った更新を避けている。
* 集計ループ中での個別エラーハンドリングはなく、異常があれば catch ブロックでまとめて検知する設計になっている。
