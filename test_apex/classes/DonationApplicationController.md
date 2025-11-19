# DonationApplicationController

## 1. 概要
DonationApplicationController クラスは、Nippon-Foundation サイトの寄付 LWC から呼び出されるサーバーサイドコントローラーであり、ログイン、ユーザー／寄付情報取得、決済手段の提示、寄付申込（GMO 決済連携含む）など広範な機能を提供します。

## 2. 基本情報
* **クラス名:** DonationApplicationController
* **アクセス修飾子:** public without sharing
* **関連オブジェクト:** User, Contact, Account, Fund__c, GMOShop__c, MailAddressRfcCheck__mdt, GMOPaymentGateway__c, DonationApplication__c, ContinuousDonation__c, FundTransaction__c, ContentVersion, GooglePaySet__c, ApplePaySetting__c など
* **対応するDMLイベント:** なし（LWC/Flow からの直接呼び出し）
* **主な外部クラスの呼び出し:** DonationApplicationUtils, GMOHttpPostRequestHandler, Site, GooglePaySet__c, ApplePaySetting__c, System.Label, Custom Metadata など

## 2.1 内部クラス (Inner Classes)
* **クラス名:** CustomException
  * **アクセス修飾子:** public
  * **説明:** LWC にビジネスエラーを伝えるための独自例外。
  * **変数:** なし

---

## 3. メソッド一覧
| メソッド名 | 修飾子 | 引数 | 戻り値 | 説明 |
| :--- | :--- | :--- | :--- | :--- |
| `getMailCheckList` | `public` `static` | なし | `List<Map<String,String>>` | カスタムメタデータからメール正規表現とメッセージを取得する。 |
| `getMailCheckListForBank` | `public` `static` | なし | `List<Map<String,String>>` | 銀行寄付画面向けに `getMailCheckList` を委譲する。 |
| `dologin` | `public` `static` | `String email, String password` | `String` | Site.login を用いた LWC ログイン処理。 |
| `currentUserCheck` | `public` `static` | なし | `Object` | 実行ユーザーがゲストかどうかを判定し、必要に応じてユーザー情報を返す。 |
| `currentUserCheckForBank` | `public` `static` | なし | `Object` | 銀行寄付画面向けに `currentUserCheck` を委譲する。 |
| `getUserInfo` | `public` `static` | `String email` | `User` | 指定メールアドレスのユーザーと関連コンタクト情報を取得する。 |
| `isEmailExists` | `public` `static` | `String email` | `Boolean` | コミュニティユーザーの存在チェック（現在は常に false）。 |
| `retrieveFound` | `private` `static` | `String fundId` | `List<Fund__c>` | Fund__c と関連 GMO 項目を取得する。 |
| `retrieveShop` | `private` `static` | `String shopId, List<String> paymentFieldNames` | `List<GMOShop__c>` | 指定フィールドを含む GMOShop__c を動的 SOQL で取得する。 |
| `getFundMessage` | `public` `static` | `String fundId` | `Map<String,String>` | 基金の日本語／英語メッセージ（FxMailAccountBank フィールド）を返す。 |
| `getCLabels` | `public` `static` | なし | `Map<String,String>` | DonationApplicationUtils からカスタムラベルを取得する。 |
| `getPaymentOptionsByFundId` | `public` `static` | `String fundId` | `Map<String,List<String>>` | 指定基金の GMO ショップ設定から利用可能な決済手段リストを組み立てる。 |
| `getExistContact` | `private` `static` | `Boolean isPerson, String email` | `Contact` | 寄付経験のある既存コンタクトを検索する。 |
| `retrieveFoundForCA` | `private` `static` | `String fundId` | `List<Fund__c>` | 寄付申込処理向けに GMO ショップ情報を含む基金を取得する。 |
| `getRecordTypeId` | `private` `static` | `String sObjectName, String dvName` | `Id` | 指定オブジェクト・開発名のレコードタイプ ID を返す。 |
| `retrieveUser` | `private` `static` | `String userid` | `User` | User から Contact.AccountId を取得する。 |
| `reRetrieveAccountOnlySubSet` | `private` `static` | `String newAccId` | `Account` | Account の一部項目のみ再取得する。 |
| `reRetrieveAccount` | `private` `static` | `String newAccId` | `Account` | 住所や情報配信設定を含めて Account を再取得する。 |
| `reRetrieveContactOnlyId` | `private` `static` | `String loginCoId` | `Contact` | Contact ID のみを取得する。 |
| `reRetrieveContact` | `private` `static` | `String loginCoId` | `Contact` | 住所・メール情報を含む Contact を再取得する。 |
| `createAccount` | `public` `static` | `Boolean isPerson, Map<String,String> accInfo, Boolean isLogin, String amznChckSssnId, String appletoken, String language` | `String` | 寄付者の Account/Contact/寄付申込（DonationApplication__c, ContinuousDonation__c）を作成・更新し、GMO 決済 URL や ID を返す。 |
| `sendRequest` | `public` `static` | `List<GMOPaymentGateway__c> params, String timedate, String recordId, String lang` | `List<GMOPaymentGateway__c>` | GMO LinkPlus API に POST し、決済画面 URL を取得して GMOPaymentGateway__c を保存する。 |
| `getDonationReasons` | `public` `static` | なし | `Map<String,List<Map<String,String>>>` | 寄付理由と都道府県リストをピックリストから構築する。 |
| `getDonationReasonsForBank` | `public` `static` | なし | `Map<String,List<Map<String,String>>>` | 銀行寄付画面向けに `getDonationReasons` を委譲する。 |
| `applePayStartSession` | `public` `static` | `String validationurl` | `Map<String,Object>` | Apple Pay セッションを開始するための HTTP リクエストを送信し、レスポンスを返す。 |

---

## 4. 詳細設計

### 4.1 getMailCheckList / getMailCheckListForBank
1. `MailAddressRfcCheck__mdt` の全件を取得し、`valid__c` が true のレコードのみ正規表現とカスタムラベルを `List<Map<String,String>>` に追加する。
2. `getMailCheckListForBank` は `getMailCheckList` を呼び出す薄いラッパーである。

### 4.2 dologin
1. LWC から渡されたメールアドレスとパスワードを用い、`Site.login` でログインを試行する（テスト時はスキップ）。
2. ログイン成功時は `PageReference` の URL を返し、失敗時は `CustomException` でラベル `DonaLWC_errorLogin` を送出する。

### 4.3 currentUserCheck / currentUserCheckForBank
1. `UserInfo.getProfileId()` を用いて、現在のユーザーが Guest User License プロファイルかどうかを判定する。
2. ゲストユーザーでなければ `getUserInfo(UserInfo.getUserName())` を返し、ゲストの場合は `{'isGustUser' => true}` マップを返す。
3. 銀行寄付向けメソッドは単純に結果を委譲する。

### 4.4 getUserInfo
1. Username（メールアドレス）で User を取得し、Contact/Account に関する住所・公開情報・性別等の詳細項目を JOIN する。
2. テスト実行時は null を返し、本番では最初の結果を返す。

### 4.5 isEmailExists
1. かつてはコミュニティユーザー存在チェックを行っていたが、現在はコメントアウトされ常に `false` を返す。

### 4.6 retrieveFound / retrieveFoundForCA
1. 基金 ID を基に Fund__c と GMOShop__c のキー項目を取得する。`retrieveFoundForCA` は決済で必要な ShopId/Pass/ConfigID/メール設定等を含む拡張版である。

### 4.7 retrieveShop
1. 引数で渡されたフィールド名リストを用いて SOQL を文字列連結し、GMOShop__c を動的クエリで取得する。

### 4.8 getFundMessage
1. `retrieveFound` の結果を基に、基金の日本語・英語メッセージを Map 形式で返す。該当基金がない場合は空文字を返す。

### 4.9 getCLabels
1. `DonationApplicationUtils.getCustomLables()` を呼び、LWC が参照するカスタムラベル辞書を返却する。

### 4.10 getPaymentOptionsByFundId
1. フロント表示ラベルと値のマッピングを定義し、基金 ID から GMO ショップ ID を取得する。
2. GMOShop__c の Boolean 項目を describe して、真の決済手段を `paymentOptions` に追加する。同時に CVS／クレカ／キャリア決済向けに LinkPlus ロゴ URL リストも作成する。
3. 該当基金やショップが見つからない場合は null を返し、最後に 4 種類のリストを Map で返却する。

### 4.11 getExistContact
1. 個人顧客か法人かで参照する Contact 条件を分け、`isDonated__c = true` かつユーザー化されていないレコードを検索する。
2. 取得した住所・生年月日などを元に処理（現在は変数計算のみ）し、該当レコードを返す。

### 4.12 getRecordTypeId / retrieveUser / reRetrieveAccount / reRetrieveContact 系
1. `getRecordTypeId` は RecordType をクエリして ID を返すユーティリティ。
2. `retrieveUser` は User から Contact.AccountId を取り出す。
3. `reRetrieveAccountOnlySubSet`／`reRetrieveAccount` は Account の再取得に使い分け、住所や公開情報を再反映する。
4. `reRetrieveContactOnlyId`／`reRetrieveContact` は Contact 情報を最小限または住所付きで再取得する補助メソッドである。

### 4.13 createAccount
1. 画面入力 `accInfo` を解析し、基金・決済方法・Google/Amazon/Apple Pay トークン等を取得する。GooglePay トークンが未指定かつ GooglePay 選択時はショップ情報を返して終了する。
2. Fund__c から GMO ショップ情報を取得し、`GMOPaymentGateway__c` を生成。決済方法ごとに ShopID/Pass、メール設定、OrderId（現在時刻＋乱数）、決済金額などを設定する。
3. 寄付行為（DonationApplication__c）と毎月寄付（ContinuousDonation__c）を構築し、支払い手段ごとの条件（GooglePay/AmazonPay/PayPal/ApplePay/payeasy/d払い/auPay/口座振替/銀行振込）で GMO API を呼び出す。`GMOHttpPostRequestHandler` を利用して AccessID/AccessPass・Link URL・決済状態を取得する。
4. ログイン有無と個人/法人別に Account/Contact を新規作成または更新し、公開可否や住所、情報メール希望を反映する。未ログインで既存顧客がある場合は上書き更新する。
5. 1 回寄付時は DonationApplication__c を insert、毎月寄付時は ContinuousDonation__c と DonationApplication__c を insert する。必要に応じて ResponsiblePerson__c や AmazonExecUrl__c を更新する。
6. GMO API 呼び出し後に取得した URL／ID を返し、例外発生時は `CustomException` で LWC へメッセージを返す。

### 4.14 sendRequest
1. LinkPlus（オンライン寄付）用に JSON ペイロードを構築し、毎月寄付か一回寄付かで API エンドポイントを切り替える。
2. Cancel URL や完了 URL を多言語対応で組み立て、`Http` で POST する。
3. 正常応答時は LinkUrl を GMOPaymentGateway__c に格納し、エラー時はステータス文字列を保持する。
4. 送信した GMOPaymentGateway__c を insert し、呼び出し元に返却する。

### 4.15 getDonationReasons / getDonationReasonsForBank
1. `DonationApplication__c.DonationReason__c` のピックリスト値をループし、`{label, value}` の Map リストを作成する。
2. `VendingMachine__c.StateInstaller__c` から都道府県選択肢を生成し、ラベル（「01.北海道」→「北海道」）と値を分割して返す。
3. `getDonationReasonsForBank` は同じ結果を返すラッパーである。

### 4.16 applePayStartSession
1. ApplePaySetting__c と System.Label.SITESDOMAIN から各種認証情報を取得する。
2. `GMOHttpPostRequestHandler.sendAppleHttpRequestForApple` を呼び出し、validation URL へ POST してセッション情報を取得する。
3. JSON レスポンスを Map<String,Object> にデシリアライズして返却する。

---

## 5. エラー処理
* 主要メソッド（dologin, createAccount, sendRequest など）は CustomException または try-catch で制御し、ユーザーに表示するラベルを含むメッセージを返している。
* `Site.login` や GMO API 呼び出しは null チェックを行い、失敗時に例外を送出する。
* 各種 DML 操作では insert/update 前に必須値を準備し、例外時には `CustomException` を用いて LWC に表示させる設計になっている。
