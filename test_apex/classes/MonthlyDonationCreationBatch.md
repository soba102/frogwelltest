# MonthlyDonationCreationBatch

## 1. 概要
MonthlyDonationCreationBatch クラスは、毎月寄付（ContinuousDonation__c）に紐づく予約済み明細を定期的に実行し、翌月分の明細と寄付行為（DonationApplication__c）を自動生成・更新するバッチ兼スケジュールジョブです。

## 2. 基本情報
* **クラス名:** MonthlyDonationCreationBatch
* **アクセス修飾子:** global（sharing 未指定） / Database.Batchable, Schedulable, Database.Stateful 実装
* **関連オブジェクト:** RecordType, ContinuousDonationItem__c, ContinuousDonation__c, DonationApplication__c
* **対応するDMLイベント:** なし（バッチ/スケジュール処理）
* **主な外部クラスの呼び出し:** なし

## 2.1 内部クラス (Inner Classes)
特になし

---

## 3. メソッド一覧
| メソッド名 | 修飾子 | 引数 | 戻り値 | 説明 |
| :--- | :--- | :--- | :--- | :--- |
| `execute` | `global` `void` | `SchedulableContext sc` | `void` | スケジュール起動時にバッチを実行する。 |
| `start` | `global` `Database.QueryLocator` | `Database.BatchableContext bc` | `Database.QueryLocator` | ContinuousDonationItem__c の予約済み明細を抽出し、寄付行為用レコードタイプを取得する。 |
| `execute` | `global` `void` | `Database.BatchableContext bc, List<ContinuousDonationItem__c> donationItems` | `void` | 対象明細から翌月分の明細と寄付行為を生成し、既存明細のステータスを更新する。 |
| `finish` | `global` `void` | `Database.BatchableContext bc` | `void` | バッチ完了後の後処理。現状は処理なし。 |

---

## 4. 詳細設計

### 4.1 execute (SchedulableContext) メソッド
1. Schedulable インターフェースから呼び出され、`Database.executeBatch(this, 200)` で本バッチを起動する。
2. バッチサイズは 200 件に固定されており、他の初期化処理は行わない。

### 4.2 start メソッド
1. RecordType から `DonationApplication__c` の `DonationType2`（毎月寄付）レコードタイプを取得し、インスタンス変数に保持する。
2. ContinuousDonationItem__c を対象に、`Status__c = 'Reservation'` かつ `Date__c <= TODAY` のレコードを SOQL で抽出する。
3. 対象クエリには、寄付行為生成に必要な各種参照項目（Account、Contact、Fund、GMO関連フィールド、公開情報など）を含め、`Database.getQueryLocator` を返す。

### 4.3 execute (Batch) メソッド
1. 渡された donationItems が空の場合は即終了する。
2. 各明細について、`Date__c` が null ならスキップし、翌月1日を算出して新規 `ContinuousDonationItem__c`（予約状態）を作成する。
3. 同時に `DonationApplication__c` を作成する。元の毎月寄付に紐づく Account/Contact、公開設定、GMO 各種 ID、支払方法、ReceiptRequest__c を引き継ぎ、法人の場合のみ `ContributionRepPerson__c` を設定する。
4. 現在処理中の明細は `Status__c = 'Processed'` に更新する。
5. 生成した明細・寄付行為をそれぞれ一括 insert する。DML 例外は try-catch で補足し、`System.debug` にログする。
6. 最後に、処理済みの元明細を一括 update する。エラーは同様にデバッグ出力する。

### 4.4 finish メソッド
1. バッチ終了後に呼ばれるが、現状は特別な処理を実装していない。

---

## 5. エラー処理
* insert/update ごとに try-catch (DmlException) を設置し、例外メッセージを `System.debug` 出力している。
* 明細が空の場合は即 return することで無駄な DML を防止している。
