# FileUploadController

## 1. 概要
FileUploadController クラスは、フローから渡される ContentVersion を解析し、対象レコード種別に応じて CSV データを各種明細オブジェクトへ取り込む汎用アップロードコンポーネントです。

## 2. 基本情報
* **クラス名:** FileUploadController
* **アクセス修飾子:** public（sharing 未指定）
* **関連オブジェクト:** ContentVersion, VendingMachinePayment__c, VendingMachineDonationDetails__c, DonationCollectionAgency__c, DonationCollectionAgencyDetail__c, GMOUpload__c, GMOUploadDetail__c, DonationApplication__c, Account, VendingMachine__c
* **対応するDMLイベント:** なし（InvocableMethod）
* **主な外部クラスの呼び出し:** HandledException

## 2.1 内部クラス (Inner Classes)
* **クラス名:** Params
  * **アクセス修飾子:** public
  * **説明:** フローから渡されるレコード ID、ContentVersion ID、ファイル種別などを保持するデータ転送用クラス。
  * **変数:** recordId, contentVersionId, filePicklistName, fromDate, toDate

---

## 3. メソッド一覧
| メソッド名 | 修飾子 | 引数 | 戻り値 | 説明 |
| :--- | :--- | :--- | :--- | :--- |
| `FileUpload` | `public` `static` | `List<Params> params` | `List<String>` | ContentVersion を解析し、対象 SObject に応じた取込処理を実行して成功/失敗メッセージを返す。 |

---

## 4. 詳細設計

### 4.1 FileUpload メソッド
1. ContentVersion ID リストを分解し、1 ファイルのみアップロードされているか検証する。複数または未指定の場合は `HandledException` を送出する。
2. ContentVersion からタイトル・拡張子・データを取得し、対象レコード ID の SObjectType から処理分岐する。
3. **VendingMachinePayment__c 向け処理**
   1. 関連する VendingMachine__c をベンダー別に読み込み、識別子とレコード ID のマップを作成する。
   2. CSV 3 行目以降を解析し、識別番号・設置場所・単価・本数・予定額などを `VendingMachineDonationDetails__c` に変換する。
   3. 重複識別子や金額 0 円行をスキップし、予定額が正のレコードのみ insert して成功件数を返す。
4. **DonationCollectionAgency__c 向け処理**
   1. CSV から突合キーとメールアドレスの一覧を作成し、Account をキー・メール別に事前取得する。
   2. 1 行ごとに `DonationCollectionAgencyDetail__c` を生成し、MatchingKey__c またはメールの一意性に応じて Account を紐づける。金額が 0 円の行はエラーとして中断する。
   3. 明細を一括 insert し、件数メッセージを返却する。
5. **GMOUpload__c 向け処理**
   1. `params[0].filePicklistName`（docomo、aupay、クレジットカード、口座振替、マルチ取引など）と CSV タイトルの整合性をチェックし、行データから GMO 取引 ID／自動売上 ID／メンバー ID／オーダー ID を収集する。
   2. 収集したキーで DonationApplication__c を検索し、寄付行為ごとにキーとのマップと重複キーセットを構築する。GMOUpload__c の種別や明細アップロード日も更新する。
   3. 各行を GMOUploadDetail__c に保存しつつ、ファイル種別ごとに処理を分岐（処理1:docomo、処理2:auPay、処理3:自動売上クレカ、処理4:口座振替、処理5:マルチ取引）。
      * オーダー ID 未登録時は CSV から組み立てた ID を DonationApplication__c に設定し、取引日・決済日・ステータス・エラーコード・各種メモ項目を更新する。
      * 既に異なるオーダー ID が登録されている場合は GMOUploadDetail__c に「エラー」結果を残し、同一オーダー ID であれば「取込済」とする。
      * 決済種別に応じて AccessStatus__c（課金済み、支払停止、審査中 など）を補正するほか、PaymentUnitID__c や GMOUpload__c.Amount__c の累計を更新する。
   4. すべての明細を insert し、重複排除のため DonationApplication__c / GMOUpload__c をセット化して一括 update する。明細件数をレスポンスとして返す。
6. どの分岐にも該当しない場合や insert 件数が 0 件の場合は「データインポートは実行されませんでした。」を返す。

---

## 5. エラー処理
* ファイル未選択・複数選択・金額 0 円・ファイル種別不一致などのビジネスエラーは `HandledException` で明示的に通知する。
* `try-catch` で全体を囲み、予期せぬ例外は `'ファイルのアップロードに失敗しました: ' + e.getMessage()` を返却する。
* GMO 取込ではキー重複を `DuplicateKey_Set` で検知し、GMOUploadDetail__c.OverallResult__c にエラー種別を設定して記録する。
