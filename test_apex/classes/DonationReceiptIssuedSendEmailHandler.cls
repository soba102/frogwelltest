/**
 * @description コンテンツドキュメントリンクの作成をトリガーに寄付行為情報を収集し、寄付者に対して領収証ダウンロード発行メールを送信するクラス。
 * @author FRW Akiyama
 * @date 2025/8/20
 */
public class DonationReceiptIssuedSendEmailHandler {

    /**
     * @param newConDocLinkIds ・・・ コンテンツドキュメントリンクIdリスト
     * @param operationType ・・・ 操作種別 AFTER_INSERTのみ許可
     */
    public static void afterCreateReceipt(List<Id> newConDocLinkIds, System.TriggerOperation operationType){
        
        System.debug('------------- DonationReceiptIssuedSendEmailHandler.afterCreateReceipt : START -------------');
        if(operationType == System.TriggerOperation.AFTER_INSERT){

            // 寄付行為 更新リスト
            List<DonationApplication__c> donaAppListForUpd = new List<DonationApplication__c>();
            // コンテンツドキュメントリンク 更新リスト
            List<ContentDocumentLink> conDocLinkListForUpd = new List<ContentDocumentLink>();
            // メール送信対象 寄付行為Idリスト（Queueableへ渡す）
            List<Id> donaAppIdListForSendEmail = new List<Id>();

            // 寄付行為のレコードタイプを取得（一般寄付・毎月寄付）
            Set<Id> targetRecordTypeIds = new Set<Id>();
            for(RecordType rt : [
                    SELECT Id, DeveloperName 
                    FROM RecordType 
                    WHERE SobjectType = 'DonationApplication__c' 
                    AND DeveloperName IN ('DonationType1', 'DonationType2')
            ]){
                targetRecordTypeIds.add(rt.Id);
            }

            // コンテンツドキュメントリンクを取得
            List<ContentDocumentLink> conDocLinkList = [
                    SELECT Id, LinkedEntityId, ContentDocumentId, ShareType, Visibility 
                    FROM ContentDocumentLink 
                    WHERE Id IN :newConDocLinkIds
            ];

            //マップ化（key:リンク済みエンティティId(寄付行為Id)、value:コンテンツドキュメントリンク）
            Map<Id, ContentDocumentLink> conDocLinkMap = new Map<Id, ContentDocumentLink>();
            for(ContentDocumentLink conDocLink : conDocLinkList){
                if(conDocLink.LinkedEntityId != null && conDocLink.LinkedEntityId.getSObjectType() == DonationApplication__c.SObjectType){
                    conDocLinkMap.put(conDocLink.LinkedEntityId, conDocLink);
                }
            }

            // 寄付行為を取得・マップ化
            Map<Id, DonationApplication__c> donaAppMap = new Map<Id, DonationApplication__c>([
                    SELECT Id, 
                                Name, 
                                ContentsDocumentID__c, 
                                IsReoutput__c, 
                                ReceiptRequest__c, 
                                isTrueCreateReceipt__c, 
                                isTrueReceiptRequest__c, 
                                ReceiptSendMaiDateTime__c, 
                                MigrationData__c, 
                                RecordTypeId 
                    FROM DonationApplication__c 
                    WHERE Id IN :conDocLinkMap.keySet() 
                    AND isTrueCreateReceipt__c = true 
                    AND isTrueReceiptRequest__c = true 
                    AND MigrationData__c != 'JUMP' 
            ]);
            
            if(!donaAppMap.isEmpty() && donaAppMap.size() > 0){

                for(DonationApplication__c dona : donaAppMap.values()){
                    // 寄付行為更新値をセット
                    if(conDocLinkMap.containsKey(dona.Id)){
                        dona.ContentsDocumentID__c = conDocLinkMap.get(dona.Id).ContentDocumentId;
                    }
                    dona.IsReoutput__c = (dona.ReceiptRequest__c == 'マイページからダウンロード') ? false : true;
                    dona.isTrueReceiptRequest__c = false;
                    donaAppListForUpd.add(dona);
                    // コンテンツドキュメントリンク更新値をセット
                    if(dona.ReceiptRequest__c == 'マイページからダウンロード'){
                        if(conDocLinkMap.containsKey(dona.Id)){
                            conDocLinkMap.get(dona.Id).Visibility = 'AllUsers';
                            conDocLinkListForUpd.add(conDocLinkMap.get(dona.Id));
                        }
                    }
                    // メール送信対象
                    if(dona.ReceiptRequest__c == 'マイページからダウンロード' && dona.ReceiptSendMaiDateTime__c == null && targetRecordTypeIds.contains(dona.RecordTypeId)){
                        // 寄付行為Idをリストに詰める
                        donaAppIdListForSendEmail.add(dona.Id);
                    }
                }

                // 寄付行為を更新
                if(!donaAppListForUpd.isEmpty()){
                    List<Database.SaveResult> updResults = Database.update(donaAppListForUpd, false);
                    for(Database.SaveResult result : updResults){
                        if(!result.isSuccess()){
                            for(Database.Error err : result.getErrors()){
                                System.debug('寄付行為更新エラー DonationReceiptIssuedSendEmailHandler.afterCreateReceipt : ' + err.getMessage());
                            }
                        }
                    }
                }

                // コンテンツドキュメントリンクを更新
                if(!conDocLinkListForUpd.isEmpty()){
                    List<Database.SaveResult> updResults = Database.update(conDocLinkListForUpd, false);
                    for(Database.SaveResult result : updResults){
                        if(!result.isSuccess()){
                            for(Database.Error err : result.getErrors()){
                                System.debug('コンテンツドキュメントリンク更新エラー DonationReceiptIssuedSendEmailHandler.afterCreateReceipt : ' + err.getMessage());
                            }
                        }
                    }
                }

                System.debug('メール送信対象 寄付行為Id カウント : ' + donaAppIdListForSendEmail.size() + ' 件');
                // メール送信キューに追加
                if(!donaAppIdListForSendEmail.isEmpty()){
                    System.enqueueJob(new DonationReceiptIssuedSendEmailQueueable(donaAppIdListForSendEmail));
                }
            } else {
                System.debug('DonationReceiptIssuedSendEmailHandler.afterCreateReceipt : 該当する寄付行為なし');
            }
        }
        System.debug('------------- DonationReceiptIssuedSendEmailHandler.afterCreateReceipt : END -------------');
    }


    // 非同期内部クラス
    private class DonationReceiptIssuedSendEmailQueueable implements Queueable{
        
        private List<Id> donaAppIds;
        // コンストラクタ
        public DonationReceiptIssuedSendEmailQueueable(List<Id> prmDonaAppIds) {
            this.donaAppIds = prmDonaAppIds;
        }

        public void execute(QueueableContext context){

            System.debug('------------- DonationReceiptIssuedSendEmailQueueable.execute : START -------------');

            // メール件名
            final String mailSubjectJp = '寄付領収証発行のお知らせ(日本財団)';
            final String mailSubjectEn = 'Notice of Receipt Issuance（The Nippon Foundation）';

            // 寄付行為を取得
            List<DonationApplication__c> donaAppList = [
                    SELECT Id, 
                                Name, 
                                Checked__c, 
                                ContentsDocumentID__c, 
                                FundId__c, 
                                FundId__r.Name, 
                                FundId__r.NameEnglish__c, 
                                AccountId__c, 
                                AccountId__r.RecordTypeId, 
                                AccountId__r.RecordType.DeveloperName, 
                                AccountId__r.Name, 
                                AccountId__r.FirstName, 
                                AccountId__r.LastName, 
                                ContributionRepPerson__c, 
                                ContributionRepPerson__r.LastName, 
                                ContributionRepPerson__r.FirstName, 
                                ContributionRepPerson__r.Name, 
                                ContactId__c, 
                                ContactId__r.LastName, 
                                ContactId__r.FirstName, 
                                ContactId__r.Name, 
                                Amount__c, 
                                Date__c, 
                                FxViewPaymentType__c, 
                                FxViewPaymentTypeEn__c, 
                                isTrueCreateReceipt__c, 
                                ReceiptRequest__c, 
                                ReceiptSendMaiDateTime__c, 
                                MigrationData__c 
                    FROM DonationApplication__c 
                    WHERE Id IN :donaAppIds 
                    AND Checked__c = true 
                    AND ReceiptRequest__c = 'マイページからダウンロード' 
                    AND ContentsDocumentID__c != '' AND ContentsDocumentID__c != null 
                    AND isTrueCreateReceipt__c = true 
                    AND ReceiptSendMaiDateTime__c = null 
                    AND MigrationData__c != 'JUMP' 
            ];

            if(donaAppList.isEmpty()){
                System.debug('DonationReceiptIssuedSendEmailQueueable.execute : 該当する寄付行為なし');
                return;
            }
            
            // ユーザーを取得する為に、寄付行為.担当者/GMO決済者のIdを取得
            List<Id> contactIdList = new List<Id>();
            if(!donaAppList.isEmpty()){
                for(DonationApplication__c dona : donaAppList){
                    Id contactId = (dona.AccountId__r.RecordType.DeveloperName == 'PersonAccount') ? dona.ContactId__c : dona.ContributionRepPerson__c;
                    contactIdList.add(contactId);
                }
            }

            // マップ（key:担当者Id、value:ユーザー）
            Map<Id, User> userMap = new Map<Id, User>();
            // プロファイルを取得（★一般寄付者）
            Profile prf = [SELECT Id, Name FROM Profile WHERE Name = '★一般寄付者' LIMIT 1];
            if(prf != null){
                Id prfId = prf.Id;
                // ユーザーを取得
                List<User> userList = [
                        SELECT Id, 
                                    Email, 
                                    LanguageLocaleKey, 
                                    IsActive, 
                                    ContactId, 
                                    ProfileId 
                        FROM User 
                        WHERE ContactId IN :contactIdList 
                        AND IsActive = true 
                        AND ProfileId = :prfId 
                ];
                for(User u : userList){
                    userMap.put(u.ContactId, u);
                }
            }

            // 送信元アドレスを取得
            String donaMail =  System.Label.DonaMail;
            OrgWideEmailAddress owea = [SELECT Id, Address FROM OrgWideEmailAddress WHERE Address = :donaMail LIMIT 1];
            // 通知プラットフォームイベントリスト
            List<ChatterPostEvent__e> eventList = new List<ChatterPostEvent__e>();
            // メール送信不可寄付行為Noリスト
            List<String> donaAppNameList = new List<String>();

            if(owea != null){
                Id fromAddressId = owea.Id;
                List<Messaging.SingleEmailMessage> sendEmailList = new List<Messaging.SingleEmailMessage>();
                Map<Messaging.SingleEmailMessage, DonationApplication__c> emailWhatIdMap = new Map<Messaging.SingleEmailMessage, DonationApplication__c>();
                
                if(!userMap.isEmpty() && userMap.size() > 0){
                    // メール生成
                    for(DonationApplication__c dona : donaAppList){

                        // 有効ユーザーなし
                        if(!userMap.containsKey(dona.ContactId__c) && !userMap.containsKey(dona.ContributionRepPerson__c)){
                            System.debug('有効ユーザーなし : ' + dona.Name);
                            ChatterPostEvent__e event = new ChatterPostEvent__e(
                                ParentId__c = dona.Id, 
                                GroupName__c = '結果通知', 
                                BodyText__c = '領収証ダウンロードメール送信不可' + '\r\n' + '有効ユーザーなし' + '\r\n' + dona.Name 
                            );
                            eventList.add(event);
                            continue;
                        }

                        User targetUser;
                        List<String> userEmailAddress = new List<String>();
                        String mailSubject = '';
                        String mailBody = '';

                        // メール受信者
                        if(dona.AccountId__r.RecordType.DeveloperName == 'PersonAccount'){
                            // 寄付者が個人
                            if(userMap.containsKey(dona.ContactId__c)){
                                targetUser = userMap.get(dona.ContactId__c);
                            }
                        } else {
                            // 寄付者が個人以外
                            if(userMap.containsKey(dona.ContributionRepPerson__c)){
                                targetUser = userMap.get(dona.ContributionRepPerson__c);
                            }
                        }

                        if(targetUser != null){
                            // メールアドレス・件名・本文
                            userEmailAddress.add(targetUser.Email);
                            if(targetUser.LanguageLocaleKey == 'ja'){
                                // 日本語
                                mailSubject = mailSubjectJp;
                                mailBody = createMailBody(dona, targetUser, true);
                            } else {
                                // 日本語以外
                                mailSubject = mailSubjectEn;
                                mailBody = createMailBody(dona, targetUser, false);
                            }

                            Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
                            mail.setToAddresses(userEmailAddress);
                            mail.setSubject(mailSubject);
                            mail.setPlainTextBody(mailBody);
                            mail.setOrgWideEmailAddressId(fromAddressId);
                            mail.setWhatId(dona.Id);
                            sendEmailList.add(mail);
                            emailWhatIdMap.put(mail, dona);
                        }
                    }
                    
                    // メール送信
                    if(!sendEmailList.isEmpty()){
                        try{
                            System.debug('メール送信開始 メール送信件数 カウント : ' + sendEmailList.size() + ' 件');
                            List<Messaging.SendEmailResult> sendEmailResults = Messaging.sendEmail(sendEmailList, false);
                            List<DonationApplication__c> donaAppListAfterSendForUpd = new List<DonationApplication__c>();
                            
                            // メール送信結果
                            for(Integer i = 0; i < sendEmailResults.size(); i++){
                                Messaging.SendEmailResult result = sendEmailResults[i];
                                Messaging.SingleEmailMessage sentEmail = sendEmailList[i];
                                DonationApplication__c whatIdDonaApp = emailWhatIdMap.get(sentEmail);
                                
                                if(result.isSuccess()){
                                    // 成功
                                    System.debug('領収証ダウンロードメール送信成功 : ' + whatIdDonaApp.Name);
                                    //whatIdDonaApp.ReceiptSendMaiDateTime__c = System.now();
                                    whatIdDonaApp.ReceiptSendMaiDateTime__c = Datetime.now();
                                    donaAppListAfterSendForUpd.add(whatIdDonaApp);
                                } else {
                                    // 失敗
                                    System.debug('領収証ダウンロードメール送信失敗 : ' + whatIdDonaApp.Name);
                                    String errTargetId = '';
                                    String errText = '';
                                    for (Messaging.SendEmailError err : result.getErrors()) {
                                        errTargetId = err.getTargetObjectId();
                                        errText = err.getMessage();                                        
                                    }
                                    ChatterPostEvent__e event = new ChatterPostEvent__e(
                                        ParentId__c = whatIdDonaApp.Id, 
                                        GroupName__c = '結果通知', 
                                        BodyText__c = '領収証ダウンロードメール送信失敗' + '\r\n' + whatIdDonaApp.Name + ' : ' + errTargetId + '\r\n' + errText
                                    );
                                    eventList.add(event);
                                }
                            }

                            // 寄付行為を更新
                            if(!donaAppListAfterSendForUpd.isEmpty()){
                                List<Database.SaveResult> updResultsAfterSend = Database.update(donaAppListAfterSendForUpd, false);
                                for(Database.SaveResult updResult : updResultsAfterSend){
                                    if(!updResult.isSuccess()){
                                        for(Database.Error err : updResult.getErrors()){
                                            System.debug('領収証ダウンロードメール送信後寄付行為更新エラー : ' + err.getMessage());
                                        }
                                    }
                                }
                            }
                            
                        } catch(Exception ex){
                            System.debug('領収証ダウンロードメール送信処理エラー : ' + ex.getMessage());                            
                        }
                    }
                } else {
                    // 全寄付行為有効ユーザーなし
                    for(DonationApplication__c dona : donaAppList){
                        System.debug('全寄付行為有効ユーザーなし : ' + dona.Name);
                        ChatterPostEvent__e event = new ChatterPostEvent__e(
                            ParentId__c = dona.Id, 
                            GroupName__c = '結果通知', 
                            BodyText__c = '領収証ダウンロードメール送信不可' + '\r\n' + '有効ユーザーなし' + '\r\n' + dona.Name 
                        );
                        eventList.add(event);
                    }     
                }
            } else {
                // 送信元アドレスなし
                for(DonationApplication__c dona : donaAppList){
                    System.debug('送信元アドレスなし : ' + dona.Name);
                    ChatterPostEvent__e event = new ChatterPostEvent__e(
                        ParentId__c = dona.Id, 
                        GroupName__c = '結果通知', 
                        BodyText__c = '領収証ダウンロードメール送信不可' + '\r\n' + '送信元アドレスなし' + '\r\n' + dona.Name 
                    );
                    eventList.add(event);
                }
            }

            // 通知プラットフォームイベント発行
            if(!eventList.isEmpty()){
                System.debug('通知プラットフォームイベント発行 カウント : ' + eventList.size() + ' 件');
                EventBus.publish(eventList);
            }

            System.debug('------------- DonationReceiptIssuedSendEmailQueueable.execute : END -------------');
        }

        /**
         * メール本文作成
         * @param dona ・・・ 寄付行為
         * @param user ・・・ 受信者ユーザー
         * @param isJapanese ・・・ 日本語:true、日本語以外:false
         */
        private String createMailBody(DonationApplication__c dona, User user, Boolean isJapanese){
            
            String originalBR = System.Label.BR;
            String addressee = '';
            String mailBody = '';

            // add start 25/9/12 Akiyama 念のためNullチェック
            String communityURL = String.isNotBlank(System.Label.CommunityURL) ? System.Label.CommunityURL + '/s/' : '';
            String formatDate = String.isNotBlank(String.valueOf(dona.Date__c)) ? String.valueOf(dona.Date__c.year()) + '-' + String.valueOf(dona.Date__c.month()) + '-' + String.valueOf(dona.Date__c.day()) : '';
            String fundName = String.isNotBlank(dona.FundId__r.Name) ? dona.FundId__r.Name : '';
            String fundNameEn = String.isNotBlank(dona.FundId__r.NameEnglish__c) ? dona.FundId__r.NameEnglish__c : '';
            String amount = String.isNotBlank(String.valueOf(dona.Amount__c)) ? dona.Amount__c.format() : '';
            String fxViewPaymentType = String.isNotBlank(dona.FxViewPaymentType__c) ? dona.FxViewPaymentType__c : '';
            String fxViewPaymentTypeEn = String.isNotBlank(dona.FxViewPaymentTypeEn__c) ? dona.FxViewPaymentTypeEn__c : '';
            // add end 25/9/12

            // String communityURL = System.Label.CommunityURL;
            // String formatDate = String.valueOf(dona.Date__c.year()) + '-' + String.valueOf(dona.Date__c.month()) + '-' + String.valueOf(dona.Date__c.day());

            if(isJapanese){
                // 日本語

                // add start 25/9/12 Akiyama nullチェックを追加
                // 宛名
                if(dona.AccountId__r.RecordType.DeveloperName == 'PersonAccount'){
                    // 個人
                    if(String.isBlank(dona.AccountId__r.LastName) || String.isBlank(dona.AccountId__r.FirstName)){
                        // 性/名いずれかが空
                        addressee = dona.AccountId__r.Name;
                    } else {
                        // 性/名どちらもあり
                        addressee = dona.AccountId__r.LastName + dona.AccountId__r.FirstName;
                    }
                } else {
                    // 個人以外
                    if(String.isNotBlank(dona.ContributionRepPerson__c) && String.isNotBlank(dona.ContributionRepPerson__r.LastName)){
                        // GMO決済者.性あり
                        addressee = dona.AccountId__r.Name + originalBR.replace('_','') + dona.ContributionRepPerson__r.LastName;
                    } else {
                        // GMO決済者.性なし
                        addressee = dona.AccountId__r.Name + originalBR.replace('_','') + dona.ContributionRepPerson__r.Name;
                    }
                }
                // 本文
                mailBody = addressee + ' 様' + '\r\n\r\n' + 
                                    'この度は' + fundName + 'へご寄付いただき誠にありがとうございます。' + '\r\n' + 
                                    'ご寄付の領収証がダウンロード可能になりました。' + '\r\n' + 
                                    'ご登録のマイページにてご確認ください。' + '\r\n\r\n' + 
                                    'マイページログインはこちら' + '\r\n' + 
                                    communityURL + '\r\n\r\n' + 
                                    '【受付詳細】━━━━━━━━━━━━━━━━━━━━━━━' + '\r\n' + 
                                    '【受付番号　　】' + dona.Name + '\r\n' + 
                                    '【決済金額　　】' + '¥' + amount + '\r\n' + 
                                    '【お支払方法　】' + fxViewPaymentType + '\r\n' + 
                                    '【決済日　　　】' + formatDate + '\r\n' + 
                                    '【寄付基金名　】' + fundName + '\r\n' + 
                                    '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━' + '\r\n\r\n' + 
                                    '改めまして、今回のあたたかなご支援に心より御礼申し上げます。' + '\r\n' + 
                                    '今後とも、日本財団へのご理解とご支援を宜しくお願いいたします。' + '\r\n\r\n' + 
                                    '━【お問合せ先】━━━━━━━━━━━━━━━━━━━━━━' + '\r\n' + 
                                    '日本財団　寄付総合窓口' + '\r\n' + 
                                    '〒107-8404　東京都港区赤坂１－２－２' + '\r\n' + 
                                    '電話 :0120-533-236（平日09：00～17：00）' + '\r\n' + 
                                    'メール:kifu@ps.nippon-foundation.or.jp' + '\r\n' + 
                                    '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━';
                // add end 25/9/12

                // del start 25/9/12　Akiyama
                    // addressee = (dona.AccountId__r.RecordType.DeveloperName == 'PersonAccount') ? 
                    //                     dona.AccountId__r.LastName + dona.AccountId__r.FirstName : 
                    //                     dona.AccountId__r.Name + originalBR.replace('_','') + dona.ContributionRepPerson__r.LastName;
                    // mailBody = addressee + ' 様' + '\r\n\r\n' + 
                    //                     'この度は' + dona.FundId__r.Name + 'へご寄付いただき誠にありがとうございます。' + '\r\n' + 
                    //                     'ご寄付の領収証がダウンロード可能になりました。' + '\r\n' + 
                    //                     'ご登録のマイページにてご確認ください。' + '\r\n\r\n' + 
                    //                     'マイページログインはこちら' + '\r\n' + 
                    //                     communityURL + '/s/' + '\r\n\r\n' + 
                    //                     '【受付詳細】━━━━━━━━━━━━━━━━━━━━━━━' + '\r\n' + 
                    //                     '【受付番号　　】' + dona.Name + '\r\n' + 
                    //                     '【決済金額　　】' + '¥' + dona.Amount__c.format() + '\r\n' + 
                    //                     '【お支払方法　】' + dona.FxViewPaymentType__c + '\r\n' + 
                    //                     '【決済日　　　】' + formatDate + '\r\n' + 
                    //                     '【寄付基金名　】' + dona.FundId__r.Name + '\r\n' + 
                    //                     '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━' + '\r\n\r\n' + 
                    //                     '改めまして、今回のあたたかなご支援に心より御礼申し上げます。' + '\r\n' + 
                    //                     '今後とも、日本財団へのご理解とご支援を宜しくお願いいたします。' + '\r\n\r\n' + 
                    //                     '━【お問合せ先】━━━━━━━━━━━━━━━━━━━━━━' + '\r\n' + 
                    //                     '日本財団　寄付総合窓口' + '\r\n' + 
                    //                     '〒107-8404　東京都港区赤坂１－２－２' + '\r\n' + 
                    //                     '電話 :0120-533-236（平日09：00～17：00）' + '\r\n' + 
                    //                     'メール:kifu@ps.nippon-foundation.or.jp' + '\r\n' + 
                    //                     '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━';
                // del end 25/9/12

            } else {
                // 日本語以外

                // add start 25/9/12 Akiyama nullチェックを追加
                // 宛名
                if(dona.AccountId__r.RecordType.DeveloperName == 'PersonAccount'){
                    // 個人
                    if(String.isBlank(dona.AccountId__r.LastName) || String.isBlank(dona.AccountId__r.FirstName)){
                        // 性/名いずれかが空
                        addressee = dona.AccountId__r.Name;
                    } else {
                        // 性/名どちらもあり
                        addressee = dona.AccountId__r.FirstName + ' ' + dona.AccountId__r.LastName;
                    }
                } else {
                    // 個人以外
                    if(String.isNotBlank(dona.ContributionRepPerson__c) && String.isNotBlank(dona.ContributionRepPerson__r.LastName)){
                        // GMO決済者.姓あり
                        addressee = dona.AccountId__r.Name + originalBR.replace('_','') + dona.ContributionRepPerson__r.LastName;
                    } else {
                        // GMO決済者.性なし
                        addressee = dona.AccountId__r.Name + originalBR.replace('_','') + dona.ContributionRepPerson__r.Name;
                    }
                }
                // 本文
                mailBody = 'Dear ' + addressee + ',' + '\r\n\r\n' + 
                                    'Thank you for your donation to ' + fundNameEn + '.' + '\r\n' + 
                                    'Your donation receipt is now available for download.' + '\r\n' + 
                                    'Please check your registered My Page.' + '\r\n\r\n' + 
                                    'Click here to log in to My Page' + '\r\n' + 
                                    communityURL + '\r\n\r\n' + 
                                    '【Reception details】━━━━━━━━━━━━━━━━━━━━━━━' + '\r\n' + 
                                    '【Reception number】' + dona.Name + '\r\n' + 
                                    '【Amount of payment 】' + '¥' + amount + '\r\n' + 
                                    '【Method of payment 】' + fxViewPaymentTypeEn + '\r\n' + 
                                    '【Date of payment 】' + formatDate + '\r\n' + 
                                    '【Name of donation fund 】' + fundNameEn + '\r\n' +
                                    '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━' + '\r\n\r\n' + 
                                    'Once again, we would like to thank you from the bottom of our hearts for your warm support.' + '\r\n' + 
                                    '━ [Contact] ━━━━━━━━━━━━━━━━━━━━━━' + '\r\n' + 
                                    'The Nippon Foundation Donation Desk' + '\r\n' + 
                                    '1-2-2 Akasaka, Minato-ku, Tokyo 107-8404' + '\r\n' + 
                                    'Phone: 0120-533-236 (weekdays 09:00-17:00)' + '\r\n' + 
                                    'Email: kifu@ps.nippon-foundation.or.jp' + '\r\n\r\n' + 
                                    '-Please contact us with your [Reception number] when making an enquiry.' + '\r\n\r\n' + 
                                    '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━';
                // add end 25/9/12

                // del start 25/9/12 Akiyama
                    // addressee = (dona.AccountId__r.RecordType.DeveloperName == 'PersonAccount') ? 
                    //                     dona.AccountId__r.FirstName + ' ' + dona.AccountId__r.LastName : 
                    //                     dona.AccountId__r.Name + originalBR.replace('_','') + dona.ContributionRepPerson__r.LastName;
                    // mailBody = 'Dear' + addressee + ',' + '\r\n\r\n' + 
                    //                     'Thank you for your donation to ' + dona.FundId__r.NameEnglish__c + '.' + '\r\n' + 
                    //                     'Your donation receipt is now available for download.' + '\r\n' + 
                    //                     'Please check your registered My Page.' + '\r\n\r\n' + 
                    //                     'Click here to log in to My Page' + '\r\n' + 
                    //                     communityURL + '/s/' + '\r\n\r\n' + 
                    //                     '【Reception details】━━━━━━━━━━━━━━━━━━━━━━━' + '\r\n' + 
                    //                     '【Reception number】' + dona.Name + '\r\n' + 
                    //                     '【Amount of payment 】' + '¥' + dona.Amount__c.format() + '\r\n' + 
                    //                     '【Method of payment 】' + dona.FxViewPaymentTypeEn__c + '\r\n' + 
                    //                     '【Date of payment 】' + formatDate + '\r\n' + 
                    //                     '【Name of donation fund 】' + dona.FundId__r.NameEnglish__c + '\r\n' +
                    //                     '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━' + '\r\n\r\n' + 
                    //                     'Once again, we would like to thank you from the bottom of our hearts for your warm support.' + '\r\n' + 
                    //                     '━ [Contact] ━━━━━━━━━━━━━━━━━━━━━━' + '\r\n' + 
                    //                     'The Nippon Foundation Donation Desk' + '\r\n' + 
                    //                     '1-2-2 Akasaka, Minato-ku, Tokyo 107-8404' + '\r\n' + 
                    //                     'Phone: 0120-533-236 (weekdays 09:00-17:00)' + '\r\n' + 
                    //                     'Email: kifu@ps.nippon-foundation.or.jp' + '\r\n\r\n' + 
                    //                     '-Please contact us with your [Reception number] when making an enquiry.' + '\r\n\r\n' + 
                    //                     '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━';
                // del end 25/9/12

            }
            return mailBody;
        }
    }
}