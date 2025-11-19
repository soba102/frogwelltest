# PaymentFileUploadController

## 1. 概要
PaymentFileUploadController クラスは、入金データ（CSV）をフローから受け取り、入金種別ごとに PaymentDetail__c を生成し、寄付行為や基金情報と照合して入金管理を行うためのユーティリティです。

## 2. 基本情報
* **クラス名:** PaymentFileUploadController
* **アクセス修飾子:** public（sharing 未指定）
* **関連オブジェクト:** Fund__c, Payment__c, PaymentDetail__c, ContentVersion
* **対応するDMLイベント:** なし（InvocableMethod）
* **主な外部クラスの呼び出し:** HandledException

## 2.1 内部クラス (Inner Classes)
* **クラス名:** Params
  * **アクセス修飾子:** public
  * **説明:** フローから受け取る Payment レコードと ContentVersion ID を保持する引数クラス。
  * **変数:** recordId（Payment__c など）、contentVersionId（ContentVersion ID リスト文字列）

---

## 3. メソッド一覧
| メソッド名 | 修飾子 | 引数 | 戻り値 | 説明 |
| :--- | :--- | :--- | :--- | :--- |
| `paymentFileUpload` | `public` `static` | `List<Params> params` | `List<String>` | ContentVersion から CSV を読み込み、入金種別ごとに PaymentDetail__c を生成して結果メッセージを返す。 |

---

## 4. 詳細設計

### 4.1 paymentFileUpload メソッド
1. Fund__c の仮想口座番号およびゆうちょ口座番号をマップ化し、ContentVersion ID リストを解析する。複数ファイルや未アップロードの場合は `HandledException` をスローする。
2. ContentVersion のバイナリを文字列化し、CRLF→LF へ統一した後、ヘッダー行を解析してファイル種別（ゆうちょ、三菱UFJ、海外送金など）を判定する。
3. ゆうちょデータの場合は 8 行目以降を日付・金額・備考列に変換し、ゆうちょ基金マップから Fund 名を補完して PaymentDetail__c を作成する。
4. 三菱UFJ（銀行振込）データでは取引日列を解析し、Fund__c の仮想口座番号と一致する基金名を特定しながら PaymentDetail__c を生成し、必要に応じてエラーを返す。
5. OVERSEA などその他のファイルでは行ごとの日付や金額、摘要を読み取り、PaymentDetail__c に生データ（LowData__c）とともに格納する。読み込み上限数 `PAYMENT_CSV_IMPORT_LIMIT` を超える場合は途中で break する。
6. 最終的に生成された PaymentDetail__c を一括 insert し、完了件数メッセージを返却する。作成件数が 0 件の場合は「データインポートは実行されませんでした。」を返す。

---

## 5. エラー処理
* 入力チェック（未アップロード・複数ファイル）やフォーマット判定失敗時は `HandledException` を投げ、フローでメッセージを提示する。
* 全体処理は try-catch で囲み、予期せぬ例外は `'ファイルのアップロードに失敗しました: ' + e.getMessage()` を返す。
* CSV 行読み取り中は改行ごとの while で制御し、異常行を検知した場合は即時にエラーメッセージを返却する。
