/**
 * <h1>GMO決済機能（LWC）コントローラークラス</h1>
 * <ul>
 * <li>Expサイト「Nippon-Foundation」の寄付情報入力画面（LWC）のコントローラー</li>
 * <li>主にGMO決済処理を担当</li>
 * </ul>
 * frogwell.horio.add.comment
 * @since 1.0
 */
public without sharing class DonationApplicationController{

    private static final String TARGET_PROFILE_NAME = 'Guest User License';
    private static final String GET_LINK_PLUS_MEMBER_JSON = '/payment/GetLinkplusUrlMember.json';
    private static final String GET_LINK_PLUS_PAYMENT_JSON = '/payment/GetLinkplusUrlPayment.json';
    // 多言語 値のため問題なし
    private static final String PAYMENT_METHOD_GINFURI_KEY = '銀行振込';
    private static final String PAYMENT_METHOD_GINFURI = PAYMENT_METHOD_GINFURI_KEY + '/郵便振替（領収書必要）';

    private static final Map<String, Map<String, String>> msgs;

    static {
        msgs = DonationApplicationUtils.getAccountMsgs();
    }

    /**
     * メールチェック処理
     * @return {List<Map<String, String>>} メールチェック結果メッセージリスト
     */
    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> getMailCheckList() {
        List<Map<String, String>> l = new List<Map<String, String>>();
        // カスタムメタデータでチェック内容を取得
        for (MailAddressRfcCheck__mdt mdt : MailAddressRfcCheck__mdt.getAll().values()) {
            if (mdt.valid__c) {
                l.add(new Map<String, String>{
                    'REGEX' => mdt.regexString__c,
                    'MSG' => System.Label.get(null, mdt.customLabelName__c)
                });    
            }
        }
        return l;
    }

    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> getMailCheckListForBank() {
        return getMailCheckList();
    }

    /**
     * ログイン
     * <p>LWCのエントリーメソッド</p>
     * @param email メールアドレス
     * @param password パスワード
     * @return ログイン成功時:リダイレクト先URL
     * frogwell.horio.add.comment
     *
     * <p>ログイン失敗時は例外をスロー</p>
     */
    @AuraEnabled
    public static String dologin(String email, String password) {
        // ログインロジックの実装
        // 例: Site.loginメソッドを使用
        String startUrl = null; // リダイレクト先URL

        PageReference pageRef = null;
        if(!Test.isRunningTest()){
           pageRef = Site.login(email, password, startUrl);
        }

        //return 'su';
         if (pageRef != null) {
             return pageRef.getUrl();
         } else {
             throw new CustomException(System.label.DonaLWC_errorLogin);
         }
    }

    /**
     * 現在の処理ユーザーをチェック
     * TODO ：判定方法はこれでよいのか。。
     * <p>LWCのエントリーメソッド</p>
     * @return GusetUserLicenseの場合=>フラグのみ、それ以外（つまりEXPユーザー)の場合User情報
     * 
     *
     * <p>ログイン失敗時は例外をスロー</p>
     */
    @AuraEnabled(cacheable=true)
    public static Object currentUserCheck() {
        System.debug('★1:UserInfo.getUserId():' + UserInfo.getUserId());
        System.debug('★1:UserInfo.getName():' + UserInfo.getName());
        // check Current User profile is Guest User License.
        if (([SELECT Id 
              FROM Profile 
              WHERE Id=:UserInfo.getProfileId() 
                AND UserLicense.name =: TARGET_PROFILE_NAME]).isEmpty()) {
            return getUserInfo(UserInfo.getUserName());
        }
        return new Map<String, Object>{'isGustUser' => true};
    }

    @AuraEnabled(cacheable=true)
    public static Object currentUserCheckForBank() {
        return currentUserCheck();
    }

    /**
     * ユーザ情報取得
     * <p>LWCのエントリーメソッド</p>
     * @param email メールアドレス
     * @return ユーザーオブジェクト
     *
     * <p>ユーザーオブジェクトには参照先の顧客（Account）、Contact(担当者)も含まれる</p>
     * <p>コミュニティユーザーに限定していない</p>
     * frogwell.horio.add.comment
     */
    @AuraEnabled(cacheable=true)
    public static User getUserInfo(String email) {
       list<user> userIn =[SELECT Id,
                                  Username,
                                  LanguageLocaleKey,
                                  ContactId,
                                  Contact.Account.Phone, 
                                  Contact.Account.PersonEmail, 
                                  Contact.Account.LastName, 
                                  Contact.Account.FirstName,
                                  Contact.Email,
                                  Contact.Account.PersonMailingState, 
                                  Contact.Account.PersonMailingCity, 
                                  Contact.LastName, 
                                  Contact.FirstName,
                                  Contact.Account.PersonMailingPostalCode, 
                                  Contact.Account.PersonMailingCountry,
                                  Contact.Account.PersonMailingStreet, 
                                  Contact.GenderIdentity,
                                  Contact.Account.Name, 
                                  Contact.Account.Email__c, 
                                  Contact.Account.ShippingState, 
                                  Contact.Account.ShippingCity,
                                  Contact.Account.ShippingPostalCode, 
                                  Contact.Account.ShippingCountry,
                                  Contact.Account.ShippingStreet, 
                                  Contact.Account.RecordType.name,
                                  Contact.Account.PersonGenderIdentity, 
                                  Contact.Account.PersonBirthdate, 
                                  Contact.Account.InformationEmail__pc,
                                  Contact.InformationEmail__c, 
                                  Contact.Birthdate, 
                                  Contact.Account.LastNameKana__pc, 
                                  Contact.Account.FirstNameKana__pc,
                                  Contact.LastNameKana__c, 
                                  Contact.FirstNameKana__c, 
                                  Contact.Account.IsRelease__c, 
                                  Contact.Account.ReleaseName__c,
                                  Contact.Account.NameDisclosureFlg__c, 
                                  Contact.Account.DisclosureName__c, 
                                  Contact.Account.NameKana__c
                            FROM User 
                            WHERE Username = :email 
                            AND ContactId != null LIMIT 1];
        if(!Test.isRunningTest()){
            return userIn[0];
        }else{
            return null;
        }
    }

    /**
     * メール存在確認
     * <p>LWCのエントリーメソッド</p>
     * @param email メールアドレス
     * @return TRUE:存在する。
     *
     * <p>コミュニティユーザーに限定している</p>
     * frogwell.horio.add.comment
     */
    @AuraEnabled(cacheable=true)
    public static Boolean isEmailExists(String email) {
        // 2024.07.26 内部ユーザーはチェック対象外
/*
        Integer count = [SELECT COUNT() 
                         FROM User 
                         WHERE Email = :email 
                           AND ContactId != null];
*/
        // 2025.08.31 チェックを行わない
/*
        Integer count = [SELECT COUNT() 
                         FROM User 
                         WHERE 	Username = :email 
                           AND ContactId != null];

        return count > 0;
*/
        return false;
    }

    //**************************************★Start決済方法の選択肢を取得*********************************************** */

    /**
     * 基金を取得
     * @param {String} fundId 基金のId
     * @return {List<Fund__c>} 基金
     */
    private static List<Fund__c> retrieveFound(String fundId) {
        return [SELECT Id, GMOShop__c ,FxMailAccountBank__c, FxEnMailAccountBank__c
                FROM Fund__c 
                WHERE Id =: fundId Limit 1];
    }

    /**
     * GMOショップを取得
     * @param shopId GMOショップID
     * @param List<String> 項目リスト
     * @return {List<GMOShop__c>} GMOショップ
     */
    private static List<GMOShop__c> retrieveShop(String shopId, List<String> paymentFieldNames) {
        String soql = 'SELECT Id ';
        for (String fieldName : paymentFieldNames) {
            soql += ', ' + fieldName;
        }
        soql += ' FROM GMOShop__c WHERE Id = :shopId LIMIT 1';

        // SOQLクエリを実行
        return Database.query(soql);
    }


    /**
     * 銀振用メッセージを取得
     * @param {String} fundId 基金のID
     * @return {Map<String, String>} メッセージ内容（英語、日本語）
     */
    @AuraEnabled(cacheable=true)
    public static Map<String, String> getFundMessage(String fundId) {
        List<Fund__c> fs = retrieveFound(fundId);
        if (fs.isEmpty()) {
            return new Map<String, String> {
                'JA' => '',
                'EN' => ''
            };
        }
        return new Map<String, String> {
            'JA' => fs.get(0).FxMailAccountBank__c,
            'EN' => fs.get(0).FxEnMailAccountBank__c
        };    
    }

    /**
     * カスタム表示ラベル
     * ※LWCが引き込んでいるカスタム表示ラベルが即時反映されないため対応
     * @param {String} fundId 基金のID
     */
    @AuraEnabled(cacheable=true)
    public static Map<String, String> getCLabels() {
        return DonationApplicationUtils.getCustomLables();    
    }

    /**
     * 決済方法の選択肢を取得
     * <p>LWCのエントリーメソッド</p>
     * @param fundId 基金ID
     * @return 決済方法の選択肢
     *
     * <p>基金が参照するGMOショップから決済方法を取得</p>
     * frogwell.horio.add.comment
     */
    @AuraEnabled(cacheable=true)
    public static Map<String, List<String>> getPaymentOptionsByFundId(String fundId) {

        // 決済方法の値 => 画面表示ラベル
        // 多言語 値のため問題なし
        Map<String, String> paymentMethodValueLable = new Map<String, String>{
            'オンライン寄付' => System.Label.DonaLWC_OnlineDonationButton,
            'GooglePay' => System.Label.DonaLWC_GooglePayButton,
            'AmazonPay' => System.Label.DonaLWC_AmazonPayButton,
            'PayPal' => System.Label.DonaLWC_PayPalButton,
            'ApplePay' => System.Label.DonaLWC_ApplePayButton,
            'd払い' => System.Label.DonaLWC_dPaymentButton,
            'payeasy' => System.Label.DonaLWC_payeasyButton,
            'auPay' => System.Label.DonaLWC_auPay,
            '口座振替' => System.Label.DonaLWC_AccountTransferButton,
            'クレジットカード' => System.Label.DonaLWC_CreditButton
        };


        List<String> paymentOptions = new List<String>();

        List<String> pCVSLnikPlus = new List<String>();

        List<String> pCCLnikPlus = new List<String>();

        List<String> pCPLnikPlus = new List<String>();

        if(String.isBlank(fundId)){
            // 基金IDが存在しない場合
            return null;
        }
        // GMOShop__c オブジェクトのチェックボックスフィールドを記述
        Map<String, Schema.SObjectField> fieldMap = Schema.SObjectType.GMOShop__c.fields.getMap();

        // 基金
        list<Fund__c> foud = retrieveFound(fundId);

        if(foud.isEmpty()){
            // 基金が存在しない場合
            return null;
        }

        // GMOショップID
        String shopId = foud[0].GMOShop__c;

        //１回寄付（ApplePay、AmazonPay、PayPal、GooglePay）
        //毎月寄付（docomo、aupay）
        List<String> paymentFieldNames = new List<String>{
           'onlinekifu__c' ,
           'recurring__c' ,
           'applepay__c',
           'gmoamazonpay__c',
           'gmopaypal__c',
           'googlepay__c',
           'googlepay_test__c',
           'dbarai__c',
           'au_pay__c',
           'accounttransfer__c'
        };

        // 
        Map<String, String> paymentCVSLinkPlus = new Map<String, String>{
            'cvs_seicomart__c' => 'logoSeikoUrl' ,
            'cvs_lawson__c' => 'logoLawsonUrl' ,
            'cvs_familymart__c' => 'logoFamilyMartUrl',
            'cvs_ministop__c' => 'logoMinistopUrl'
         };

         Map<String, String> paymentCCLinkPlus = new Map<String, String>{
            'cc_visa__c' => 'logoVisaUrl' ,
            'cc_mc__c' => 'logoMcUrl' ,
            'cc_amex__c' => 'logoAmexUrl',
            'cc_jcb__c' => 'logoJcbUrl',
            'cc_diner__c' => 'logoDinersUrl'
         };

         Map<String, String> paymentCPLinkPlus = new Map<String, String>{
            'cp_dbarai__c' => 'logoDbaraiUrl' ,
            'cp_softbank__c' => 'logoSoftbankMatometeUrl' ,
            'cp_aukantan__c' => 'logoAukantanUrl',
            'cp_payeasy__c' => 'logoPayeasyUrl',
            'cp_paypay__c' => 'logoPaypayUrl'
         };


         System.debug('◆◆◆◆◆◆◆◆◆◆◆◆:' + shopId);

         List<String> flst = new List<String>();
         flst.addAll(paymentFieldNames);
         flst.addAll(paymentCVSLinkPlus.keySet());
         flst.addAll(paymentCCLinkPlus.keySet());
         flst.addAll(paymentCPLinkPlus.keySet());

        // GMOショップを取得
        List<GMOShop__c> shop = retrieveShop(shopId, flst);

        if(shop.isEmpty()){
            //GMOショップが存在しない。
            return null;
        }

        // フィールドマップをループして、各チェックボックスフィールドに対して処理を行う
        for (String fieldName : fieldMap.keySet()) {
            Schema.SObjectField field = fieldMap.get(fieldName);
            Schema.DescribeFieldResult F = field.getDescribe();
            System.debug('★★★★field★★★★:'+fieldName);
            system.debug('Fのタイプーーーー');
            system.debug(F.getType());
            system.debug('fieldNameーーーー');
            system.debug(paymentFieldNames.contains(fieldName));
            // フィールドがチェックボックスの場合のみ処理を行う
            if (F.getType() == Schema.DisplayType.BOOLEAN ) {
                if (paymentFieldNames.contains(fieldName)) {
                    String fieldLabel = F.getLabel(); // フィールドのラベルを取得

                    // GMOShop__c レコードのフィールド値を取得（リフレクションを使用）
                    Boolean value = (Boolean)shop[0].get(fieldName);
                    System.debug('★value'+value);
    
                    // フィールドの値が true の場合、ラベルを paymentOptions に追加
                    if (value != null && value == true) {
                        if (paymentMethodValueLable.containsKey(fieldLabel)) {
                            paymentOptions.add(fieldLabel + '=' + paymentMethodValueLable.get(fieldLabel));
                        } else {
                            String apiKey = F.getName();
                            if (paymentMethodValueLable.containsKey(apiKey)) {
                                paymentOptions.add(apiKey + '=' + paymentMethodValueLable.get(apiKey));
                            } else {
                                apiKey = apiKey.replace('__c', '').replace('_', '');
                                if (paymentMethodValueLable.containsKey(apiKey)) {
                                    paymentOptions.add(apiKey + '=' + paymentMethodValueLable.get(apiKey));
                                }
                            }
                        }
                    }    
                } else if (paymentCVSLinkPlus.containsKey(fieldName)) {
                    system.debug('paymentCVSLinkPlusーーーー');
                    system.debug('★★★★fieldName:' + fieldName);

                    // GMOShop__c レコードのフィールド値を取得（リフレクションを使用）
                    Boolean value = (Boolean)shop[0].get(fieldName);
                    system.debug('★★★★★value:' + value);
    
                    // フィールドの値が true の場合、ラベルを paymentOptions に追加
                    if (value != null && value == true) {
                        system.debug('★★★★★ADD:');
                        pCVSLnikPlus.add(paymentCVSLinkPlus.get(fieldName));
                    }    
                } else if (paymentCCLinkPlus.containsKey(fieldName)) {
                    system.debug('paymentCCLinkPlusーーーー');
                    system.debug('★★★★fieldName:' + fieldName);

                    // GMOShop__c レコードのフィールド値を取得（リフレクションを使用）
                    Boolean value = (Boolean)shop[0].get(fieldName);
                    system.debug('★★★★★value:' + value);
    
                    // フィールドの値が true の場合、ラベルを paymentOptions に追加
                    if (value != null && value == true) {
                        system.debug('★★★★★ADD:');
                        pCCLnikPlus.add(paymentCCLinkPlus.get(fieldName));
                    }    
                } else if (paymentCPLinkPlus.containsKey(fieldName)) {
                    system.debug('paymentCPLinkPlusーーーー');
                    system.debug('★★★★fieldName:' + fieldName);

                    // GMOShop__c レコードのフィールド値を取得（リフレクションを使用）
                    Boolean value = (Boolean)shop[0].get(fieldName);
                    system.debug('★★★★★value:' + value);
    
                    // フィールドの値が true の場合、ラベルを paymentOptions に追加
                    if (value != null && value == true) {
                        system.debug('★★★★★ADD:');
                        pCPLnikPlus.add(paymentCPLinkPlus.get(fieldName));
                    }    
                }
            }
        }
        System.debug('★paymentOptions:' + paymentOptions);
        System.debug('★pCVSLnikPlus:'  + pCVSLnikPlus);
        System.debug('★pCCLnikPlus:'  + pCCLnikPlus);
        System.debug('★pCPLnikPlus:'  + pCPLnikPlus);
        return new Map<String, List<String>>{ 
            'paymentOptions'  => paymentOptions,
            'pCVSLnikPlus' => pCVSLnikPlus,
            'pCCLnikPlus' => pCCLnikPlus,
            'pCPLnikPlus' => pCPLnikPlus
        };
    }
    //**************************************★End決済方法の選択肢を取得*********************************************** */


    /**
     * 顧客、担当者情報を取得
     * @param fundId 基金ID
     * @return 決済方法の選択肢
     *
     * <p>コミュニティユーザー以外のメールアドレスに合致する顧客、担当者を取得</p>
     * frogwell.horio.add.comment
     *
     */
    private static Contact getExistContact(boolean isPerson, String email) {

        List<Contact> cs;
        if (isPerson) {
            // 個人取引先 念のため、設定したAccountの情報を取得
            cs = [SELECT Id,
                        AccountId,
                        Account.lastName,
                        Account.firstName,
                        Account.lastNameKana__pc,
                        Account.firstNameKana__pc,
                        Account.PersonEmail,
                        Account.Phone,
                        Account.PersonMailingState,
                        Account.PersonMailingCity,
                        Account.PersonMailingPostalCode,
                        Account.PersonMailingCountry,
                        Account.PersonMailingStreet,
                        Account.ReleaseName__c,
                        Account.IsRelease__c,
                        Account.PersonGenderIdentity,
                        Account.PersonBirthdate,
                        Account.InformationEmail__pc
                FROM Contact
                WHERE Account.IsPersonAccount =: isPerson
                AND Account.PersonEmail =: email
                AND isDonated__c = true
                AND Id NOT IN (SELECT ContactId FROM User WHERE ContactId != null) ];
            if (cs.size() == 1) {
                String[] strts = cs.get(0).Account.PersonMailingStreet == null ? new List<String>() : cs.get(0).Account.PersonMailingStreet.split(' ');
                Date bd = cs.get(0).Account.PersonBirthdate;
                String y = (bd != null) ? String.valueOf(bd.year())  : '';
                String m = (bd != null) ? String.valueOf(bd.month()).leftPad(2, '0') : '';
                String d = (bd != null) ? String.valueOf(bd.day()).leftPad(2, '0') : '';
            }
        } else {
            cs = [SELECT Id,
                        AccountId,
                        lastName,
                        firstName,
                        lastNameKana__c,
                        firstNameKana__c,
                        email,
                        phone,
                        MailingState,
                        MailingCity,
                        MailingPostalCode,
                        MailingStreet,
                        MailingCountry,
                        InformationEmail__c,
                        GenderIdentity,
                        Birthdate,
                        Account.Name,
                        Account.NameKana__c,
                        Account.DisclosureName__c,
                        Account.NameDisclosureFlg__c
            FROM Contact
            WHERE IsPersonAccount =: isPerson
            AND email =: email
            AND isDonated__c = true
            AND Id NOT IN (SELECT ContactId FROM User WHERE ContactId != null) ];
            if (cs.size() == 1) {
                String[] strts = cs.get(0).MailingStreet == null ? new List<String>() : cs.get(0).MailingStreet.split(' ');
                Date bd = cs.get(0).Birthdate;
                String y = (bd != null) ? String.valueOf(bd.year())  : '';
                String m = (bd != null) ? String.valueOf(bd.month()).leftPad(2, '0') : '';
                String d = (bd != null) ? String.valueOf(bd.day()).leftPad(2, '0') : '';
            }
        }
        // 最初の1件目を対象とする。
        //if (cs.size() > 1) {
        //    throw new CustomException(email + 'のお客様情報が複数件存在します。');
        //}
        return cs.isEmpty() ? null : cs.get(0);
    }

    /**
     * 基金を取得 (アカウント作成用)
     * @param {String} fundId 基金
     * @return {List<Fund__c>} 基金リスト
     */
    private static List<Fund__c> retrieveFoundForCA(String fundId) {
        return [SELECT Id,
                       GMOShop__r.Name,
                       GMOShop__r.ShopId__c, 
                       GMOShop__r.SnopPassword__c, 
                       GMOShop__r.ConfigID__c,
                       GMOShop__r.GuideMailSendFlag__c, 
                       GMOShop__r.ThanksMailSendFlag__c,
                       GMOShop__r.FromSendMailName__c, 
                       GMOShop__r.Address__c,
                       Name, 
                       GMOShop__r.TemplateNo__c, 
                       GMOShop__r.SiteId__c, 
                       GMOShop__r.SitePass__c
                FROM Fund__c WHERE Id =: fundId Limit 1];
    }

    /**
     * レコードタイプ取得
     * @param {String} sObjectName オブジェクト名
     * @param {String} dvName レコードタイプ名
     * @return {Id} レコードタイプID
     */
    private static Id getRecordTypeId(String sObjectName, String dvName) {
        return [SELECT Id FROM RecordType WHERE SObjectType =: sObjectName AND DeveloperName =: dvName LIMIT 1].Id;
    }

    /**
     * ユーザー取得
     * @param {String} userid ユーザーID
     * @return {User} ユーザーオブジェクト
     */
    private static User retrieveUser(String userid) {
        return [select Contact.AccountId from user Where Id = :userid limit 1];
    }


    /**
     * Account再取得
     * @param {String} newAccId 取引先Id
     * @return {Account} 取引先オブジェクト
     */
    private static Account reRetrieveAccountOnlySubSet(String newAccId) {
        return [SELECT Id, ResponsiblePerson__c, PersonContactId FROM Account WHERE Id =:newAccId limit 1];
    }

    /**
     * Account再取得
     * @param {String} newAccId 取引先Id
     * @return {Account} 取引先オブジェクト
     */
    private static Account reRetrieveAccount(String newAccId) {
        return [SELECT Id, 
                       ResponsiblePerson__c, 
                       PersonContactId,
                       PersonMailingState,
                       PersonMailingCity,
                       PersonMailingPostalCode,
                       PersonMailingCountry,
                       PersonMailingStreet,
                       InformationEmail__pc,
                       Phone,
                       ShippingState,
                       ShippingCity,
                       ShippingCountry,
                       ShippingPostalCode,
                       ShippingStreet
                FROM Account WHERE Id =:newAccId limit 1];
    }


    /**
     * Contact再取得
     * @param {String} loginCoId 取引先責任者Id
     * @return {Contact} 取引先責任者オブジェクト
     */
    private static Contact reRetrieveContactOnlyId(String loginCoId) {
        return  [SELECT Id FROM Contact WHERE Id = :loginCoId limit 1];
    }

    /**
     * Contact再取得
     * @param {String} loginCoId 取引先責任者Id
     * @return {Contact} 取引先責任者オブジェクト
     */
    private static Contact reRetrieveContact(String loginCoId) {
        return  [SELECT Id,
                        Phone,
                        MailingState,
                        MailingCity,
                        MailingCountry,
                        MailingPostalCode,
                        MailingStreet,
                        InformationEmail__c FROM Contact WHERE Id = :loginCoId limit 1];
    }

    /**
     * 顧客作成（寄付実行）
     * <p>LWCのエントリーメソッド</p>
     * @param isPerson 個人フラグ TRUE:個人
     * @param accInfo  寄付、寄付者情報
     * @param isLogin  ログイン済みフラグ TRUE:ログイン済み
     * @param amznChckSssnId amazon PayのセッションID
     * @param appletoken  apple PayのセッションID
     * @param language  言語
     * @return GMO決済画面へのURL（リンクタイプ Plus）
     *
     * <p>GMOのAPIコールし、決済画面へのURLを取得</p>
     * <p>オンライン寄付のみGMOPaymentGatewayを作成</p>
     * <p>顧客、担当者、寄付行為、毎日寄付を登録/更新<br/>
     * ・ログイン時<br/>
     * 担当者情報の寄付済をTRUEに更新、寄付行為 or 毎日寄付を作成<br/>
     * ・未ログインかつメールアドレスに合致する顧客、担当者が存在時<br/>
     * 顧客、担当者を入力内容で更新、寄付行為 or 毎日寄付を作成<br/>
     * ・未ログインかつメールアドレスに合致する顧客、担当者が存在しない<br/>
     * 顧客、担当者を入力内容で作成、寄付行為 or 毎日寄付を作成<br/>
     * </p>
     * frogwell.horio.add.comment
     *
     */
    @AuraEnabled
    public static String createAccount(Boolean isPerson, 
                                       Map<String, String> accInfo, 
                                       Boolean isLogin,
                                       String amznChckSssnId, 
                                       String appletoken,
                                       String language) {

        try {

            System.debug('★★★★★createAccount★★★★★★');
            System.debug('★isPerson:' + isPerson);
            System.debug('★accInfo:' + accInfo);
            for (String key : accInfo.keySet()) {
                System.debug('★★★:' + key + '=' + accInfo.get(key));
            }
            System.debug('★isLogin:' + isLogin);
            System.debug('★amznChckSssnId:' + amznChckSssnId);
            System.debug('★appletoken:' + appletoken);
            System.debug('★★★★★createAccount★★★★★★');
            //Account newAcc = new Account();
            //String newAccId='';
    
            // ******************** GMO 画面リンク取得 ********************************/
            String payTypeText = accInfo.get('payTypeText');
            String gpaypaymentToken = accInfo.get('paymentToken');
            
    
            system.debug('★fundId:'+accInfo.get('fundId'));
            System.debug('★payTypeText:' + payTypeText);
            System.debug('★gpaypaymentToken:' + gpaypaymentToken);
    
            String timedate = String.valueOf(System.now()).replaceAll(' ', '').replaceAll(':', '').replaceAll('-','');
    
            //基金取得
            List<Fund__c> foud = retrieveFoundForCA(accInfo.get('fundId'));
            if(payTypeText == 'GooglePay' && String.isBlank(gpaypaymentToken)) {
                return foud[0].GMOShop__r.ShopId__c 
                    + '&' + foud[0].GMOShop__r.name 
                    + '&' + GooglePaySet__c.getOrgDefaults().enviroment__c
                    + '&' + GooglePaySet__c.getOrgDefaults().merchantId__c
                    + '&' + GooglePaySet__c.getOrgDefaults().merchantName__c;
            }
    
            // 現在の日時をミリ秒単位で取得
            Long currentTimeMillis = DateTime.now().getTime();
            // ランダムな数字を追加してさらにユニーク性を高める
            Integer randomNum = Math.mod(Math.abs(Crypto.getRandomInteger()), 9999999); // 7桁のランダムな数字
    
            GMOPaymentGateway__c gmopg = new GMOPaymentGateway__c();
            if(payTypeText != PAYMENT_METHOD_GINFURI) {
                gmopg.ShopID__c = foud[0].GMOShop__r.ShopId__c;
                gmopg.ShopPass__c = foud[0].GMOShop__r.SnopPassword__c;
                gmopg.ConfigID__c = foud[0].GMOShop__r.ConfigID__c;
                gmopg.GuideMailSendFlag__c = foud[0].GMOShop__r.GuideMailSendFlag__c;
                gmopg.ThanksMailSendFlag__c = foud[0].GMOShop__r.ThanksMailSendFlag__c;
                gmopg.FromSendMailName__c = foud[0].GMOShop__r.FromSendMailName__c;
                gmopg.FromSendMailAddress__c = foud[0].GMOShop__r.Address__c;
                gmopg.SendMailAddress__c = accInfo.get('email');
                gmopg.BccSendMailAddress__c = foud[0].GMOShop__r.Address__c;
                gmopg.Overview__c = foud[0].Name;
                gmopg.CustomerName__c = accInfo.get('lastName') + accInfo.get('firstName');
                gmopg.Amount__c = integer.valueOf(accInfo.get('amount'));
                gmopg.Tax__c = 0;
                gmopg.TemplateNo__c = String.valueOf(foud[0].GMOShop__r.TemplateNo__c);
                gmopg.NumberOfDonation__c = accInfo.get('kifukaisu');
                // 27桁のユニークなコードを生成
                gmopg.Name = String.valueOf(currentTimeMillis) + String.valueOf(randomNum);
            }
            // 寄付行為レコード作成
            // FRW:24/9/3 GMOMemberID__c 追加処理
            DonationApplication__c da = new DonationApplication__c(
                Amount__c = integer.valueOf(accInfo.get('amount')),
                // 2025/09/07 日付処理は修正
                //Date__c = System.today(),
                Date__c = Date.today(),
                FundId__c = accInfo.get('fundId'),
                PaymentType__c = payTypeText.replace('(test)', ''),
                DonationReason__c =accInfo.get('donationReason')  ,
                // 領収書発行の希望を追加 BY 鈴木 2024/11/23 START
                ReceiptRequest__c =accInfo.get('receiptRequest'),
                // 領収書発行の希望を追加 BY 鈴木 2024/11/23 END
                // 2025/01/03 言語設定
                Language__c = language
            );
    
            // 公開名
            da.ReleaseName__c = accInfo.get('publicname');
            // 公開希望の対応、必ず設定
            da.isRelease__c = accInfo.get('ispublic') =='true'?true:false;
            //if (!isPerson) {
                //da.isRelease__c = accInfo.get('ispublic') =='true'?true:false;
                //da.ReceiptName__c = accInfo.get('corporationName');
            //} else {
                //da.ReceiptName__c = (accInfo.get('lastName') + '　' + accInfo.get('firstName'));
            //}
    
            if(payTypeText != PAYMENT_METHOD_GINFURI) {
                da.WebApplication__c = true;

                da.GMOMemberID__c = gmopg.Name;
                da.GmoOrderId__c = timedate;
                // 多言語対応:値なので問題なし
                da.Status__c = '仮登録';
            } else {
                // Web申し込み TURE
                da.WebApplication__c = true;
                // 多言語対応:値なので問題なし
                da.GMOResultStatus__c = '完了';
            }
    
            System.debug('★da.PaymentType__c:' + da.PaymentType__c);
    
            ContinuousDonation__c cd = new ContinuousDonation__c();
            // 2025/01/03 言語設定
            cd.Language__c = language;
            if(payTypeText != PAYMENT_METHOD_GINFURI) {
                //毎月寄付レコード作成
                // FRW:24/9/3 GMOMemberID__c 追加処理
                cd.GMOMemberID__c = gmopg.Name;
            }
            // 公開名
            cd.ReleaseName__c = accInfo.get('publicname');
            // 公開希望を設定
            cd.isRelease__c = accInfo.get('ispublic') =='true'?true:false;
            //if (!isPerson) {
            //    cd.isRelease__c = accInfo.get('ispublic') =='true'?true:false;
            //}
            
    
            List<GMOPaymentGateway__c> resultgmopg = new List<GMOPaymentGateway__c>();
            GMOHttpPostRequestHandler handler = new GMOHttpPostRequestHandler();
            Boolean isAmazonExec = false;
            // 多言語対応 値なのでこのままでよい
            if(payTypeText == 'オンライン寄付' || payTypeText == 'クレジットカード') {
    
                resultgmopg = sendRequest(new List<GMOPaymentGateway__c>{gmopg}, timedate, accInfo.get('fundId'), language);
                payTypeText = resultgmopg[0].LinkURL__c;
                da.GMOPaymethod__c = '';
            } else if(payTypeText == 'GooglePay(test)' || (payTypeText == 'GooglePay' && !String.isBlank(gpaypaymentToken))) {

                String GooglePaymentToken = '';
                if (payTypeText == 'GooglePay' && !String.isBlank(gpaypaymentToken)) {
                    GooglePaymentToken = EncodingUtil.base64Encode(Blob.valueOf(gpaypaymentToken));
                    System.debug('★GooglePaymentToken:SET:FROM GPAY:' + GooglePaymentToken);
                } else {
                    //テスト環境専用　GooglePaymentToken　カード番号：4111111111111111
                    List<StaticResource> sr = [SELECT Id, Body FROM StaticResource WHERE Name = 'GooglePayTestToken' LIMIT 1];
                    System.debug('★★★★sr:' + sr);
                    if (!sr.isEmpty()) {
                        GooglePaymentToken = sr.get(0).Body.toString();
                        System.debug('★★★★sr:Body:' + sr.get(0).Body.toString());
                    }
                    System.debug('★GooglePaymentToken:' + GooglePaymentToken);
                    if (String.isBlank(GooglePaymentToken)) {
                        GooglePaymentToken = 'ew0KICJ2ZXJzaW9uIjoiR21vTW9jayIsDQogInByb3RvY29sVmVyc2lvbiI6IkVDdjEiLA0KICJzaWduYXR1cmUiOiJNRVFDSUR4Qm9VQ29GUkdSZUxkWi9jQUJsU1NSSUtvT0VGb1UzZTI3YzE0dk1adGZBaUJ0WDNwR01FcG53Nm1TQWJuYWdDQ2dIbENrM05jRndXWUV5eElFNktHWlZBdTAwM2R1MDAzZCIsDQogInNpZ25lZE1lc3NhZ2UiOiJ7XCJlbmNyeXB0ZWRNZXNzYWdlXCI6XCJldzBLSUNBaWNHRjViV1Z1ZEUxbGRHaHZaQ0k2SWtOQlVrUWlMQTBLSUNBaWNHRjViV1Z1ZEUxbGRHaHZaRVJsZEdGcGJITWlPbnNOQ2lBZ0lDQWljR0Z1SWpvaU5ERXhNVEV4TVRFeE1URXhNVEV4TVNJc0RRb2dJQ0FnSW1WNGNHbHlZWFJwYjI1TmIyNTBhQ0k2TVRJc0RRb2dJQ0FnSW1WNGNHbHlZWFJwYjI1WlpXRnlJam95TURVd0RRb2dJSDBzRFFvZ0lDSm5ZWFJsZDJGNVRXVnlZMmhoYm5SSlpDSTZJbk52YldVdGJXVnlZMmhoYm5RdGFXUWlMQTBLSUNBaWJXVnpjMkZuWlVsa0lqb2ljMjl0WlMxdFpYTnpZV2RsTFdsa0lpd05DaUFnSW0xbGMzTmhaMlZGZUhCcGNtRjBhVzl1SWpvaU1qVTFOakV4TVRVNU9UQXdNQ0lOQ24wPVwiLFwiZXBoZW1lcmFsUHVibGljS2V5XCI6XCJCUGhWc3BuNzBaajJLa2d1OXQ4K0FwRXVVV3NJL3pvczV3aEdDUUJsZ09rdVlhZ09pczdxc3JjYlFyY3ByanZUWk8zWE9VK1FiY2MyOEZTZ3NSdGNnUUV1MDAzZFwiLFwidGFnXCI6XCJaVndsSnQ3ZFU4UGxrMCtyOHJQRjhEbVBUdkRpT0ExVUFvTmpEVitTcURFdTAwM2RcIn0iDQp9';
                    }    
                }
                System.debug('★GooglePaymentToken:' + GooglePaymentToken);
                payTypeText = handler.GooglePaysendRequest(da, GooglePaymentToken, foud[0]);
                da.GMOPaymethod__c = 'googlepay';
                da.GMOAccessID__c = handler.GMOAccessID;
                da.GMOAccessPass__c = handler.GMOAccessPass;
                if (payTypeText.contains('ErrCode')) {
                    da.GMO_Status__c = 'UNPROSESSED';
                    payTypeText = payTypeText + '&Status=UNPROSESSED';
                } else {
                    da.GMO_Status__c = 'CAPTURE';
                    payTypeText = payTypeText + '&Status=CAPTURE';
                }
                da.GMOResultStatus__c = '完了';
    
            } else if(payTypeText == 'AmazonPay') {
    
                da.GMOPaymethod__c = 'amazonpay';
                payTypeText = handler.AmazonPaysendRequest(da, foud[0], amznChckSssnId, language);
                da.GMOAccessID__c = handler.GMOAccessID;
                da.GMOAccessPass__c = handler.GMOAccessPass;
    
                isAmazonExec = true;
    
            } else if(payTypeText == 'PayPal') {
    
                da.GMOPaymethod__c = 'paypal';
                payTypeText = handler.PayPalsendRequest(da, foud[0], language);
                da.GMOAccessID__c = handler.GMOAccessID;
                da.GMOAccessPass__c = handler.GMOAccessPass;
    
            } else if(payTypeText == 'ApplePay') {
    
                String applePayToken1 = 'ewogICAgImhlYWRlciI6ewogICAgICAiZXBoZW1lcmFsUHVibGljS2V5IjogInRlc3RQdWJsaWNLZXkiLAogICAgICAicHVibGljS2V5SGFzaCI6ICJ0ZXN0S2V5SGFzaCIsCiAgICAgICJ0cmFuc2FjdGlvbklkIjogInRlc3RUcmFuc2FjdGlvbiIKICAgIH0sCiAgICAiZGF0YSI6ICJleUpoY0hCc2FXTmhkR2x2YmxCeWFXMWhjbmxCWTJOdmRXNTBUblZ0WW1WeUlqb2dJalV4TVRFeE1URXhNVEV4TVRFeE1URWlMQ0FpWVhCd2JHbGpZWFJwYjI1RmVIQnBjbUYwYVc5dVJHRjBaU0k2SUNJeU1qRXlNekVpTENBaVkzVnljbVZ1WTNsRGIyUmxJam9pTXpreUlpd2dJblJ5WVc1ellXTjBhVzl1UVcxdmRXNTBJam9pTVRBd01DSXNJQ0pqWVhKa2FHOXNaR1Z5VG1GdFpTSTZJQ0lpTENBaVpHVjJhV05sVFdGdWRXWmhZM1IxY21WeVNXUmxiblJwWm1sbGNpSTZJQ0lpTENBaWNHRjViV1Z1ZEVSaGRHRlVlWEJsSWpvaU0wUlRaV04xY21VaUxDQWljR0Y1YldWdWRFUmhkR0VpT2lCN0lDQWdJQ0p2Ym14cGJtVlFZWGx0Wlc1MFEzSjVjSFJ2WjNKaGJTSTZJQ0pFZFcxdGVVTkJWbFpCUVVGQlFVRkJRVUZCUVVGQlFVRkJRVUZCSWl3Z0lDQWdJbVZqYVVsdVpHbGpZWFJ2Y2lJZ09pQWlNRFVpSUNCOWZRbz0iLAogICAgInNpZ25hdHVyZSI6ICJ0ZXN0U2lnbmF0dXJlIiwKICAgICJ2ZXJzaW9uIjogIk1vY2siCn0KCg==';
                String applePayToken = appletoken;
                if (appletoken == 'test') {
                    StaticResource sr = [SELECT Id, Body FROM StaticResource WHERE Name = 'ApplePayTestToken' LIMIT 1];
                    applePayToken = sr.Body.toString();
                    System.debug('★applePayToken for TEST:');    
                } else if (appletoken == 'test2') {
                    applePayToken = appletoken;
                    System.debug('★applePayToken for TEST:');    
                } else {
                    System.debug('★applePayToken for NOT TEST:');    
                }
                System.debug('★applePayToken:' + applePayToken);
                da.GMOPaymethod__c = 'applepay';
                payTypeText = handler.ApplePaysendRequest(da, applePayToken, foud[0], language);
                da.GMOAccessID__c = handler.GMOAccessID;
                da.GMOAccessPass__c = handler.GMOAccessPass;
                System.debug('★applePayToken:payTypeText:' + payTypeText);
    
            } else if(payTypeText == 'payeasy') {
    
                da.GMOPaymethod__c = 'payeasy';
                payTypeText = handler.PayeasysendRequest(da, null, foud[0], accInfo.get('lastName') + accInfo.get('firstName'), accInfo.get('lastFurigana') + accInfo.get('firstFurigana'), accInfo.get('phoneNumber'));
                da.GMOAccessID__c = handler.GMOAccessID;
                da.GMOAccessPass__c = handler.GMOAccessPass;    
            // 多言語対応 値なのでこのままでよい
            } else if(payTypeText == 'd払い') {
    
                cd.GMO_Paymethod__c = 'docomo';
                payTypeText = handler.gmosendRequest(da, foud[0], language);
                cd.GMOAccessID__c = handler.GMOAccessID;
                cd.GMOAccessPass__c = handler.GMOAccessPass;
    
            //} else if(payTypeText == 'au Pay') {
            } else if(payTypeText == 'auPay') {
    
                //cd.GMO_Paymethod__c = 'au pay';
                cd.GMO_Paymethod__c = 'auPay';
                payTypeText = handler.auPaysendRequest(da, foud[0], language);
                cd.GMOAccessID__c = handler.GMOAccessID;
                cd.GMOAccessPass__c = handler.GMOAccessPass;
            // 多言語対応 値なのでこのままでよい
            } else if(payTypeText == '口座振替') {
                // 多言語対応 値なのでこのままでよい                    
                da.GMOPaymethod__c = '口座振替';
                // 現在の日時をミリ秒単位で取得
                currentTimeMillis = DateTime.now().getTime();
                // ランダムな数字を追加してさらにユニーク性を高める
                randomNum = Math.mod(Math.abs(Crypto.getRandomInteger()), 9999999); // 7桁のランダムな数字
                String accountNumber = String.valueOf(Math.mod(Math.abs(Crypto.getRandomInteger()), 9999999));
                if (accInfo.containsKey('accountNumber') && String.isNotBlank(accInfo.get('accountNumber'))) {
                    accountNumber = accInfo.get('accountNumber');
                }
                // 口座振替追加　BY林　2024/09/17　Start
                String accountType = '';
                // 多言語対応 値なのでこのままでよい
                if(accInfo.get('selectedDepositCategory') == '普通'){
                    accountType = '1';
                }else{
                    accountType = '2';
                }
                String bankCode = (accInfo.containsKey('financialinstitutioncode') && String.isNotBlank(accInfo.get('financialinstitutioncode')))?accInfo.get('financialinstitutioncode'):'';
                String branchCode = (accInfo.containsKey('branchCode') && String.isNotBlank(accInfo.get('branchCode')))?accInfo.get('branchCode'):'';
                String accountName = (accInfo.containsKey('accountKanaName') && String.isNotBlank(accInfo.get('accountKanaName')))?accInfo.get('accountKanaName'):'';
                String accountNameKanji = (accInfo.containsKey('accountName') && String.isNotBlank(accInfo.get('accountName')))?accInfo.get('accountName'):'';
                String returl = handler.creditTransferRequest(da, foud[0], cd.GMOMemberID__c, accountNumber, bankCode, branchCode, accountType, accountName, accountNameKanji, language);
                System.debug('★returl:' + returl);
                if (returl.contains(GMOHttpPostRequestHandler.KEY_ERROR_INFO)) {
                    String errorInfoCode = returl.replace(GMOHttpPostRequestHandler.KEY_ERROR_INFO + '=', '');
                    System.debug('★errorInfoCode:' + errorInfoCode);

                    if (String.isNotBlank(errorInfoCode)) {
                        List<String> ecs = errorInfoCode.split('\\|');
                        List<String> ems = new List<String>();
                        for (String ec : ecs) {
                            if (!msgs.containsKey(ec)) {
                                System.debug('★not contain');
                                throw new CustomException(errorInfoCode);    
                            } else {
                                ems.add(msgs.get(ec).values().get(0));
                            }
                        }
                        System.debug('★contain');
                        throw new CustomException(String.join(ems, '\r\n'));
                    }
                }
                // 口座振替追加　BY林　2024/09/17　End
                payTypeText = returl;
            }
    
            System.debug('★★★★★★★★★★payTypeText★★★★★:' + payTypeText);

            Boolean isExistError = false;
            String exsitErrorCode = '';
            String exsitErrorInfo = '';
            String exsitErrorResult = '';
            if (String.isNotBlank(payTypeText)) {
                List<String> rl = payTypeText.split('&');
                for (String str : rl) {
                    if (String.isNotBlank(str)) {
                        if (str.startsWith(GMOHttpPostRequestHandler.KEY_ERROR_CODE)) {
                            List<String> vl = str.split('=');
                            if (vl.size() > 1) {
                                isExistError = true;
                                exsitErrorCode = vl.get(1);
                            }                            
                        }
                        if (str.startsWith(GMOHttpPostRequestHandler.KEY_ERROR_INFO)) {
                            List<String> vl = str.split('=');
                            if (vl.size() > 1) {
                                isExistError = true;
                                exsitErrorInfo = vl.get(1);
                            }
                        }

                    }
                }
                if (!isExistError) {
                    if (accInfo.get('payTypeText') == 'PayPal') {
                        // 多言語 値のため問題なし Paypalのエラーは必ず日本語で返却される
                        if(payTypeText.contains('エラーコード/code：') || payTypeText.contains('エラー詳細コード/detail code：')) {
                            isExistError = true;
                            exsitErrorResult = payTypeText;
                        }
                    } 
                }
            }
            if (isExistError) {
                if (cd != null) {
                    if(String.isBlank(exsitErrorResult)){
                        cd.GMO_ErrCode__c = exsitErrorCode;
                        cd.GMO_ErrInfo__c = exsitErrorInfo;
                        cd.GMO_Result_Detail__c = payTypeText;
    
                    } else {
                        cd.GMO_Result_Detail__c = exsitErrorResult;
                    }
                }
                if (da != null) {
                    if(String.isBlank(exsitErrorResult)){
                        da.GMOErrCode__c = exsitErrorCode;
                        da.GMOErrInfo__c = exsitErrorInfo;
                        da.GMO_Result_Detail__c = payTypeText;
                    } else {
                        da.GMO_Result_Detail__c = exsitErrorResult;
                    }
                }
            }
            // ******************** GMO 画面リンク取得 ********************************/
    
            // ******************** Account / Contact / ContinuousDonation__c 作成****/
    
            Account newAcc = null;
            String newAccId='';
            Contact newCon = new Contact();
            Contact donatedSameContact = null;
            if(!isLogin){
    
                // レコードタイプの設定
                if (isPerson) {
                    //Date dT = Date.valueOf(accInfo.get('birthdate')),
                    newAcc = new Account(
                        // 個人のレコードタイプIDを設定
                        RecordTypeId = getRecordTypeId('Account', 'PersonAccount'),
                        PersonEmail = accInfo.get('email'),
                        LastName = accInfo.get('lastName'),
                        FirstName = accInfo.get('firstName'),
                        //ReceiptName__c = (accInfo.get('lastName') + '　' + accInfo.get('firstName')),
                        Phone = accInfo.get('phoneNumber'),
                        LastNameKana__pc = accInfo.get('lastFurigana'),
                        FirstNameKana__pc = accInfo.get('firstFurigana'),
                        PersonMailingState = accInfo.get('selectedPrefecture'),
                        PersonMailingCity = accInfo.get('city'),
                        PersonMailingPostalCode = accInfo.get('zipcode'),
                        PersonMailingCountry = accInfo.get('country'),
                        PersonMailingStreet = accInfo.get('town') + ' ' + accInfo.get('address'),
                        //ReleaseName__c = accInfo.get('publicname'),
                        language__pc = language,
                        // 公開希望
                        IsRelease__c = accInfo.get('ispublic') =='true'?true:false,
                        ReleaseName__c = accInfo.get('publicname'),
                        // 多言語対応 値なのでこのままでよい
                        PersonGenderIdentity = accInfo.get('ismale') =='true'?'男性':accInfo.get('isfemale') =='true'?'女性':'その他',
                        PersonBirthdate = date.newInstance(Integer.valueOf(accInfo.get('year')), Integer.valueOf(accInfo.get('month')), Integer.valueOf(accInfo.get('day'))),
                        //PersonBirthdate = date.parse(accInfo.get('birthdate')),
                        //PersonBirthdate= date.newinstance(dT.year(), dT.month(), dT.day()),
                        // 多言語対応 値なのでこのままでよい
                        InformationEmail__pc = accInfo.get('isemailYes') =='true'?'受け取る':'受け取らない'
                    );
                } else {
                    newAcc = new Account(
                        // 法人のレコードタイプIDを設定
                        RecordTypeId = getRecordTypeId('Account', 'corporation'),
                        // 法人の場合、名前を姓と名の組み合わせで設定
                        Name = accInfo.get('corporationName'),
                        //ReceiptName__c = accInfo.get('corporationName'),
                        NameKana__c = accInfo.get('corporationNameKana'),
                        Phone = accInfo.get('phoneNumber'),
                        Email__c = accInfo.get('email'),
                        // 共通フィールドの設定
                        ShippingState = accInfo.get('selectedPrefecture'),
                        ShippingCity = accInfo.get('city'),
                        ShippingCountry = accInfo.get('country'),
                        ShippingPostalCode = accInfo.get('zipcode'),
                        ShippingStreet = accInfo.get('town') + ' ' + accInfo.get('address'),
                        // 公開希望
                        IsRelease__c = accInfo.get('ispublic') =='true'?true:false,
                        ReleaseName__c = accInfo.get('publicname')
                        // 公開希望法人名は使用しない
                        //DisclosureName__c = accInfo.get('publicname'),
                        //ReleaseName__c = accInfo.get('publicname'),
    
                        // 法人名公開希望フラグは使用しない
                        //NameDisclosureFlg__c = accInfo.get('ispublic') =='true'?true:false,
                        // 公開
                        //isRelease__c = accInfo.get('ispublic') =='true'?true:false
                    );
                }
                // 2025.08.31 チェックを行わない
                /*
                donatedSameContact = getExistContact(isPerson, accInfo.get('email'));
                if (donatedSameContact != null) {
                    // 寄付済みの同一メールアドレスのContact/Accountあり
                    newAcc.Id = donatedSameContact.AccountId;
                }
    
                if (newAcc.Id != null) {
                    // 取引先レコードの登録
                    update newAcc;
                } else {
                    // 取引先レコードの登録
                    insert newAcc;
                }
                */
                insert newAcc;
                newAccId = newAcc.Id;
    
            } else {
                newAccId = retrieveUser(accInfo.get('userid')).Contact.AccountId;
                newAcc   = reRetrieveAccount(newAccId);
                if (isPerson) {
                    newAcc.PersonMailingState = accInfo.get('selectedPrefecture');
                    newAcc.PersonMailingCity = accInfo.get('city');
                    newAcc.PersonMailingCountry = accInfo.get('country');
                    newAcc.PersonMailingPostalCode = accInfo.get('zipcode');
                    newAcc.PersonMailingStreet = accInfo.get('town') + ' ' + accInfo.get('address');
                    // 多言語対応 値なのでこのままでよい
                    newAcc.InformationEmail__pc = accInfo.get('isemailYes') =='true'?'受け取る':'受け取らない';
                    newAcc.Phone = accInfo.get('phoneNumber');
                    // 公開希望
                    newAcc.IsRelease__c = accInfo.get('ispublic') =='true'?true:false;
                    newAcc.ReleaseName__c = accInfo.get('publicname');
                } else {
                    newAcc.ShippingState = accInfo.get('selectedPrefecture');
                    newAcc.ShippingCity = accInfo.get('city');
                    newAcc.ShippingCountry = accInfo.get('country');
                    newAcc.ShippingPostalCode = accInfo.get('zipcode');
                    newAcc.ShippingStreet = accInfo.get('town') + ' ' + accInfo.get('address');
                    newAcc.Phone = accInfo.get('phoneNumber');
                    // 公開希望
                    newAcc.IsRelease__c = accInfo.get('ispublic') =='true'?true:false;
                    newAcc.ReleaseName__c = accInfo.get('publicname');
                }
                // 情報更新
                update newAcc;
    
                // 再取得
                newAcc = reRetrieveAccountOnlySubSet(newAccId);
            }
    
            // 法人の場合、関連する取引先責任者（Contact）も作成
            String updateCoId = null;
            if (!isLogin) {
                // 未ログイン
    
                if (donatedSameContact != null) {
                    // 寄付済みの同一メールアドレスのContact/Accountあり
                    newCon.id = donatedSameContact.id;
                }
    
                if (!isPerson) {
                    // 法人
                    newCon.AccountId = newAccId; // 取引先IDを関連付け
                    newCon.LastName = accInfo.get('lastName'); // 取引先責任者の姓
                    newCon.FirstName = accInfo.get('firstName'); // 取引先責任者の名
                    newCon.LastNameKana__c = accInfo.get('lastFurigana');
                    newCon.FirstNameKana__c = accInfo.get('firstFurigana');
                    newCon.Email = accInfo.get('email'); // 取引先責任者のメールアドレス
                    newCon.Phone = accInfo.get('phoneNumber'); // 取引先責任者の電話番号
                    newCon.MailingState = accInfo.get('selectedPrefecture');
                    newCon.MailingCity = accInfo.get('city');
                    newCon.MailingCountry = accInfo.get('country');
                    newCon.MailingPostalCode = accInfo.get('zipcode');
                    newCon.MailingStreet = accInfo.get('town') + ' ' + accInfo.get('address');
                    // 多言語対応 値なのでこのままでよい
                    newCon.InformationEmail__c = accInfo.get('isemailYes') =='true'?'受け取る':'受け取らない';
                    // 法人の場合不要
                    //newCon.GenderIdentity = accInfo.get('ismale') =='true'?'男性':accInfo.get('isfemale') =='true'?'女性':'その他';
                    //newCon.Birthdate = date.newInstance(Integer.valueOf(accInfo.get('year')), Integer.valueOf(accInfo.get('month')), Integer.valueOf(accInfo.get('day')));
                    newCon.isDonated__c = true;
                    newCon.language__c = language;
                    if (newCon.id != null) {
                        // 寄付済みの同一メールアドレスのContact/Accountあり
                        update newCon;
                    } else {
                        insert newCon;
                    }
                } else {
                    // 個人
                    String cId;
                    if (newCon.id != null) {
                        // 寄付済みの同一メールアドレスのContact/Accountあり
                        cId = newCon.id;
                    } else {
                        // 新規作成した個人顧客
                        cId = reRetrieveAccount(newAccId).PersonContactId;
                    }
                    update new Contact(Id = cId, isDonated__c = true, language__c = language);
                }
            } else {
                String cid = accInfo.get('loginCoId');
                newCon = reRetrieveContact(cid);
                if (!isPerson) {
                    newCon.Phone = accInfo.get('phoneNumber'); // 取引先責任者の電話番号
                    newCon.MailingState = accInfo.get('selectedPrefecture');
                    newCon.MailingCity = accInfo.get('city');
                    newCon.MailingCountry = accInfo.get('country');
                    newCon.MailingPostalCode = accInfo.get('zipcode');
                    newCon.MailingStreet = accInfo.get('town') + ' ' + accInfo.get('address');
                    // 多言語対応 値なのでこのままでよい
                    newCon.InformationEmail__c = accInfo.get('isemailYes') =='true'?'受け取る':'受け取らない';
                }
                newCon.isDonated__c = true;
                newCon.language__c = language;
                update newCon;
                // ログイン
                newCon = reRetrieveContactOnlyId(accInfo.get('loginCoId'));    
            }
            // 多言語対応 値なのでこのままでよい
            if(accInfo.get('kifukaisu') == '毎月'){
                cd.AccountId__c = newAccId;
                cd.Amount__c = integer.valueOf(accInfo.get('amount'));
                // 2025/09/07 日付処理は修正
                //cd.Date__c = System.today();
                cd.Date__c = Date.today();
                cd.DonationReason__c = accInfo.get('donationReason');
                cd.FundId__c = accInfo.get('fundId');
                cd.OrderId__c = gmopg.Name;
                cd.Status__c = 'Continuing';
                cd.Type__c = 'Monthly1';
                cd.PaymentType__c = accInfo.get('payTypeText');
                cd.GMOAccessID__c = handler.GMOAccessID;
                cd.GMOAccessPass__c = handler.GMOAccessPass;
    
                // if ('オンライン寄付' == accInfo.get('payTypeText')) {
                //     cd.OrderId__c = gmopg.Name;
                // } else {
                //     cd.OrderId__c = da.GmoOrderId__c;
                // }
                cd.OrderId__c = da.GmoOrderId__c;
                // 領収書発行の希望を追加 BY 鈴木 2024/11/23 START
                cd.ReceiptRequest__c =accInfo.get('receiptRequest');
                // 領収書発行の希望を追加 BY 鈴木 2024/11/23 END
    
                // 毎月寄付かつ法人の場合は担当者を設定
                if (!isPerson) {
                    cd.ContactId__c = newCon.Id;
                }
                // 多言語対応 値なのでこのままでよい
                if (da.GMOPaymethod__c == '口座振替') {
                    cd.BankStartURL__c = payTypeText;
                }
                insert cd;
                // 多言語対応 値なのでこのままでよい
                if (da.GMOPaymethod__c == '口座振替') {
                    payTypeText = cd.id;
                }
            } else {
    
                da.AccountId__c = newAccId;
                // FRW:24/9/4 ContributionRepPerson__c 追加処理
                da.ContributionRepPerson__c = newCon.Id;
                da.RecordTypeId = getRecordTypeId('DonationApplication__c', 'DonationType1');
                System.debug('★da.PaymentType__c:' + da.PaymentType__c);
                if (isAmazonExec) {
                    da.AmazonExecUrl__c = payTypeText;
                }
                insert da;
    
                if (isAmazonExec) {
                    payTypeText = da.id;
                }
    
                // 1回寄付かつ法人の場合、顧客のご担当者（Account.ResponsiblePerson__c）に取引先責任者を設定
                if (!isPerson) {
                    newAcc.ResponsiblePerson__c = newCon.Id;
                    update newAcc;
    
                    Account chAcc = reRetrieveAccount(newAcc.Id);
                }
            }
    
            // ******************** Account / Contact / ContinuousDonation__c 作成****/
            if (isExistError && !payTypeText.contains('settlement-cancel')) {
                payTypeText = String.format(GMOHttpPostRequestHandler.RetCancelUrl, new List<String>{language}) + '&isNS=true&isToastError=true';
            }
            system.debug('★Last:payTypeText:' + payTypeText);
            return payTypeText;

        } catch (Exception e) {
            throw new CustomException(System.Label.DonaLWC_ErrorOccurred + '\r\n' + e.getMessage());
        }
    }

    /**
     * リンクタイプPlus実行 (決済方法：オンライン寄付)
     * <p>GMO決済画面のリンクを取得</p>
     * @param params GMOPaymentGateway__cのリスト
     * @param timedate  １回寄付の場合のOrderId
     * @return 永続化済みのGMOPaymentGateway__cのリスト
     *
     * <p>1回寄付の場合、OrderId=引数のtimedate</p>
     * <p>毎回寄付の場合、OrderId=引数のparamsの0番目要素のName=timedate</p>
     * frogwell.horio.add.comment
     *
     */
    public static List<GMOPaymentGateway__c> sendRequest(List<GMOPaymentGateway__c> params, String timedate, String recordId, String lang) {
        String langStr = (lang == 'en_US' ? 'en' : 'ja');

        String memberId = params[0].Name;

        String cancelRetUrl = GMOHttpPostRequestHandler.getBasicUrl(recordId, lang);
        String compRetUrl = String.format(GMOHttpPostRequestHandler.RetURL, new List<String>{lang});
        system.debug('★cancelRetUrl:' + cancelRetUrl);

        String json;
        String url;
        // 多言語対応 値なのでこのままでよい
        if(params[0].NumberOfDonation__c == '毎月'){

            url = System.label.GMOPAYDOMAIN + GET_LINK_PLUS_MEMBER_JSON;

            //Nameが設定されている場合はクレジットカード情報更新 miyoshi
            if(String.isBlank(memberId)){
                // ここは絶対通らない？？？
                memberId = params[0].Name;
            }
            json =
                '{' +
                    ' "configid":"' + params[0].ConfigId__c + '",' +
                    ' "member": { ' +
                        ' "MemberID": "' + memberId + '",' +
                        ' "MemberName": "' + params[0].CustomerName__c + '",' +
                        ' "Cardeditno": "' + params[0].Name + '",' +
                        ' "CompleteUrl": "' + compRetUrl + '",' +
                        ' "CancelUrl": "'  + cancelRetUrl + '"' +
                    '},' +
                    '"displaysetting": { "Lang":"' + langStr + '"}, ' + 
                    '"geturlparam": { ' +
                        '"ShopID": "' + params[0].ShopID__c + '",' +
                        '"ShopPass": "' + params[0].ShopPass__c + '",' +
                        //'"GuideMailSendFlag": "' + params[0].GuideMailSendFlag__c + '",' +
                        //'"ThanksMailSendFlag": "' + params[0].ThanksMailSendFlag__c + '",' +
                        //'"BccSendMailAddress": "' + params[0].BccSendMailAddress__c + '",' +
                        //FromメールはGMOのメールアドレスを利用するため設定しない
                        //'"FromSendMailAddress": "' + params[0].FromSendMailAddress__c + '",' +
                        //'"FromSendMailName": "' + params[0].FromSendMailName__c + '",' +
                        '"FromSendMailAddress": "",' +
                        '"FromSendMailName": "",' +
                        '"SendMailAddress": "' + params[0].SendMailAddress__c + '",' +
                        '"CustomerName": "' + params[0].CustomerName__c + '",' +
                        '"TemplateNo": "' + params[0].TemplateNo__c + '"' +
                    '}' +
                '}';
        }else{
            // 設定しない。通知されない
            //transaction.NotifyMailaddress 決済完了通知先メールアドレス

            url = System.label.GMOPAYDOMAIN + GET_LINK_PLUS_PAYMENT_JSON;

            json =
                '{' +
                    ' "configid":"' + params[0].ConfigId__c + '",' +
                    ' "transaction": { ' +
                        ' "OrderID": "' + timedate + '",' +
                        ' "Amount": "' + params[0].Amount__c + '",' +
                        ' "Tax": "' + params[0].Tax__c + '",' +
                        ' "Overview": "' + params[0].Overview__c + '",' +
                        ' "CompleteUrl": "' + compRetUrl + '",' +
                        ' "CancelUrl": "'  + cancelRetUrl + '",' +
                        //入金手続き完了通知メール送信無しフラグ
                        ' "NoCompletionEmailFlag": "1"' +
                    '},' +
                    '"displaysetting": { "Lang":"' + langStr + '"}, ' + 
                    '"geturlparam": { ' +
                        '"ShopID": "' + params[0].ShopID__c + '",' +
                        '"ShopPass": "' + params[0].ShopPass__c + '",' +
                        //'"GuideMailSendFlag": "' + params[0].GuideMailSendFlag__c + '",' +
                        //'"ThanksMailSendFlag": "' + params[0].ThanksMailSendFlag__c + '",' +
                        //'"BccSendMailAddress": "' + params[0].BccSendMailAddress__c + '",' +
                        //FromメールはGMOのメールアドレスを利用するため設定しない
                        //'"FromSendMailAddress": "' + params[0].FromSendMailAddress__c + '",' +
                        //'"FromSendMailName": "' + params[0].FromSendMailName__c + '",' +
                        '"FromSendMailAddress": "",' +
                        '"FromSendMailName": "",' +
                        '"SendMailAddress": "' + params[0].SendMailAddress__c + '",' +
                        '"CustomerName": "' + params[0].CustomerName__c + '",' +
                        '"TemplateNo": "' + params[0].TemplateNo__c + '"' +
                    '}' +
                '}';
        }
        HttpRequest req = new HttpRequest();
        req.setEndpoint(url);
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json');
        req.setBody(json);
        system.debug('★request json:' + json);
        Http http = new Http();
        HttpResponse res = http.send(req);
        //system.debug('レスポンスの結果');
        //system.debug(System.JSON.deserializeUntyped(res.getBody()));
        // system.debug((String)res.get('errInfo'));
        List<String> ret = new List<String>();
        if (res.getStatusCode() == 200) {
           Map<String, Object> parsedResponse = (Map<String, Object>)System.JSON.deserializeUntyped(res.getBody());
           // LinkUrlを取得
           params[0].LinkURL__c = (String)parsedResponse.get('LinkUrl');

           System.debug('★res.getBody() : ' + res.getBody());
        } else {
           params[0].LinkURL__c = 'Error: ' + res.getStatus();

           System.debug('★Error res.getBody() : ' + res.getBody());
        }
        insert params;
        return params;
    }

    /**
     * 寄付のきっかけを取得
     * <p>LWCのエントリーメソッド</p>
     * @return 寄付行為の寄付のきっかけ項目の選択リスト値を返却
     *
     * frogwell.horio.add.comment
     *
     */
    @AuraEnabled(cacheable=true)
    public static Map<String, List<Map<String, String>>> getDonationReasons() {
        List<Map<String, String>> reasons = new List<Map<String, String>>();
        // DonationReason__c フィールドの選択リスト値を取得
        Schema.DescribeFieldResult field = DonationApplication__c.DonationReason__c.getDescribe();
        for (Schema.PicklistEntry entry : field.getPicklistValues()) {
            
            reasons.add(new Map<String, String>{
                'label'=>entry.getLabel(),
                'value'=>entry.getValue()
            });
        }

        List<Map<String, String>> prefectures = new List<Map<String, String>>();
        field = VendingMachine__c.StateInstaller__c.getDescribe();
        for (Schema.PicklistEntry entry : field.getPicklistValues()) {
            String label = entry.getLabel().substring(entry.getLabel().indexOf('.') + 1);
            String valKey = entry.getLabel().substring(0, entry.getLabel().indexOf('.') );
            prefectures.add(new Map<String, String>{
                'label'=>label,
                'value'=>valKey
            });
        }
        return new Map<String, List<Map<String, String>>> {
            'reasons' => reasons,  
            'prefectures' => prefectures
        } ;
    }

    @AuraEnabled(cacheable=true)
    public static Map<String, List<Map<String, String>>> getDonationReasonsForBank() {
        return getDonationReasons();
    }

/*
    @AuraEnabled
    public static Map<String, Object> applePayStartSession(String validationurl) {
        System.debug('★validationURL:' + validationurl);
        String resbody =  GMOHttpPostRequestHandler.sendAppleHttpRequestForApple(validationurl, new Map<String, String>{
            'merchantIdentifier' => 'merchant.FRW',
            'displayName'=> 'donationapplication',
            'initiative'=> 'web',
            'initiativeContext'=> 'nippon-foundation--dona1.sandbox.my.salesforce-sites.com'
        });
        System.debug('★resBody:' + resbody);
        return (Map<String, Object>) JSON.deserializeUntyped(resbody);
    }
*/

    /**
     * Apple Payのセッションを取得する。
     * @param {String} validationurl 
     * @return {Map<String, Object> } 
     */
    @AuraEnabled
    public static Map<String, Object> applePayStartSession(String validationurl) {
        String domainStr = System.label.SITESDOMAIN.replace('https://','');
        ApplePaySetting__c apSet = ApplePaySetting__c.getOrgDefaults();
        System.debug('★validationURL:' + validationurl);
        String resbody =  GMOHttpPostRequestHandler.sendAppleHttpRequestForApple(validationurl, new Map<String, String>{
            'merchantIdentifier' => apSet.merchantIdentifier__c,
            'displayName'=> apSet.displayName__c,
            'initiative'=> apSet.initiative__c,
            'initiativeContext'=> domainStr
        });
        return (Map<String, Object>) JSON.deserializeUntyped(resbody);
    }
    // カスタム例外クラス（オプショナル）
    public class CustomException extends Exception {}
}