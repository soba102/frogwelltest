# DonationReceiptIssuedSendEmailHandler

## 1. 概要
DonationReceiptIssuedSendEmailHandler クラスは、寄付行為（DonationApplication__c）に領収証ファイル（ContentDocumentLink）がリンクされた際に必要な項目更新と通知メール送信を行うトリガーハンドラクラスです。

## 2. 基本情報
* **クラス名:** DonationReceiptIssuedSendEmailHandler
* **アクセス修飾子:** public（sharing 未指定）
* **関連オブジェクト:** ContentDocumentLink, DonationApplication__c, User, OrgWideEmailAddress, ChatterPostEvent__e
* **対応するDMLイベント:** after insert（ContentDocumentLink トリガー想定）
* **主な外部クラスの呼び出し:** DonationReceiptIssuedSendEmailQueueable（内部クラス）, EventBus, Messaging

## 2.1 内部クラス (Inner Classes)
* **クラス名:** DonationReceiptIssuedSendEmailQueueable
  * **アクセス修飾子:** private
  * **説明:** 領収証メール送信と寄付行為更新を非同期で実行する Queueable クラス。
  * **変数:** donaAppIds（メール送信対象寄付行為 ID リスト）

---

## 3. メソッド一覧
| メソッド名 | 修飾子 | 引数 | 戻り値 | 説明 |
| :--- | :--- | :--- | :--- | :--- |
| `afterCreateReceipt` | `public` `static` | `List<Id> newConDocLinkIds, System.TriggerOperation operationType` | `void` | ContentDocumentLink 作成後に寄付行為を更新し、メール送信対象を Queueable に渡す。 |
| `DonationReceiptIssuedSendEmailQueueable` (constructor) | `public` | `List<Id> prmDonaAppIds` |  | 寄付行為 ID リストを保持する Queueable のコンストラクタ。 |
| `execute` | `public` `void` | `QueueableContext context` | `void` | 領収証ダウンロードメールを送信し、送信済み日時やエラーチャターを更新する。 |
| `createMailBody` | `private` | `DonationApplication__c dona, User user, Boolean isJapanese` | `String` | 受信者言語に応じたメール本文を生成する。 |

---

## 4. 詳細設計

### 4.1 afterCreateReceipt メソッド
1. TriggerOperation が AFTER_INSERT の場合のみ処理を実行する。
2. ContentDocumentLink を取得し、リンク先が DonationApplication__c のものだけをマップ化する。
3. 寄付行為をまとめて取得し、領収証希望・マイページダウンロード等の条件を満たすものに対して `ContentsDocumentID__c`、`IsReoutput__c`、`isTrueReceiptRequest__c` を更新する。マイページダウンロード希望時は ContentDocumentLink.Visibility を `AllUsers` に変更する。
4. 条件を満たし未送信の寄付行為 ID をリスト化し、DonationReceiptIssuedSendEmailQueueable を enqueue する。
5. DML は Database.update を部分成功モードで実行し、エラーは `System.debug` へ記録する。

### 4.2 DonationReceiptIssuedSendEmailQueueable.execute メソッド
1. 受け取った寄付行為 ID で DonationApplication__c を再取得し、Checked__c や ReceiptRequest__c などの条件を再確認する。
2. 寄付者 Account/Contact から Community ユーザー（プロファイル: ★一般寄付者）を検索し、ContactId をキーとしたユーザーマップを構築する。Org Wide Email Address（System.Label.DonaMail）も取得する。
3. 寄付者ごとに送信先と使用言語を判定し、`createMailBody` で本文を作成する。Org Wide Email を差出人に設定し、Messaging.SingleEmailMessage を生成する。
4. `Messaging.sendEmail` の結果を解析し、成功した寄付行為には `ReceiptSendMaiDateTime__c` を現在日時で更新、失敗したものは ChatterPostEvent__e（結果通知グループ）を EventBus.publish で通知する。
5. 有効ユーザーや送信元が存在しない場合も ChatterPostEvent__e を発行してオペレーション結果を共有する。

### 4.3 createMailBody メソッド
1. 寄付者のレコードタイプ（個人 / 法人）に応じて宛名を作成し、氏名欠落時のフォールバックを実装する。
2. 日本語・英語それぞれでテンプレートを組み立て、受付番号・金額・支払方法・決済日・基金名を埋め込む。
3. System.Label.CommunityURL と BR を用いてマイページ URL や問い合わせ先情報を本文に含める。
4. 寄付行為の属性が null の場合は空文字に置き換え、`format()` を利用して金額を整形する。

---

## 5. エラー処理
* afterCreateReceipt／Queueable いずれも try-catch はないが、Database.update の結果ループでエラー詳細を `System.debug` に出力する。
* メール送信は try-catch で保護されており、例外発生時にはデバッグ出力とともに処理を継続する。
* 有効ユーザーや送信元がないケースは ChatterPostEvent__e を発行して管理者に通知する。
