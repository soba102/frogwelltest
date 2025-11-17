global class MonthlyDonationCreationBatch implements Database.Batchable<SObject>, Schedulable, Database.Stateful {
    
    // 各バッチ実行間で値を保持するためのインスタンス変数
    private RecordType donationRecordType;
    
    /**
     * Schedulableインターフェースのexecuteメソッド
     */
    global void execute(SchedulableContext sc) {
        // バッチサイズは必要に応じて設定（例：200件ずつ処理）
        Database.executeBatch(this, 200);
    }
    
    /**
     * Batchableインターフェースのstartメソッド
     */
    global Database.QueryLocator start(Database.BatchableContext bc) {
        donationRecordType = [
            SELECT Id, Name
            FROM RecordType
            WHERE SobjectType = 'DonationApplication__c' 
              AND DeveloperName = 'DonationType2'
            LIMIT 1
        ];
        
        // ContinuousDonationItem__cレコードのうち、Status__cが'Reservation'のものを対象とする
        String query = 'SELECT Amount__c, ContinuousDonationItem__c.Date__c, ContinuousDonationId__c, ContinuousDonationId__r.AccountId__c, ContinuousDonationId__r.ContactId__c, ContinuousDonationId__r.DonationReason__c, ContinuousDonationId__r.FundId__c, ContinuousDonationId__r.GMOAccessID__c, ContinuousDonationId__r.GMOAccessPass__c, ContinuousDonationId__r.GMOMemberID__c, ContinuousDonationId__r.GMO_Paymethod__c, ContinuousDonationId__r.GmoAutomaticSalesId__c, ContinuousDonationId__r.ReceiptRequest__c, PaymentType__c ' +
                    // add start 25/8/29 Akiyama 毎月寄付.公開希望と公開名を取得
                        ', ContinuousDonationId__r.IsRelease__c, ContinuousDonationId__r.ReleaseName__c ' + 
                    // add end 25/8/29
                    // add start 25/9/16 Akiyama 毎月寄付.寄付者.レコードタイプを取得
                        ', ContinuousDonationId__r.AccountId__r.RecordType.DeveloperName ' + 
                    // add end 25/9/16
                       'FROM ContinuousDonationItem__c ' +
                       'WHERE Status__c = \'Reservation\''+
                       ' AND Date__c <= TODAY ' ;
        return Database.getQueryLocator(query);
    }
    
    /**
     * Batchableインターフェースのexecuteメソッド
     */
    global void execute(Database.BatchableContext bc, List<ContinuousDonationItem__c> donationItems) {
        if (donationItems.isEmpty()) {
            return;
        }
        
        List<ContinuousDonationItem__c> newDonationItems = new List<ContinuousDonationItem__c>();
        List<DonationApplication__c> newDonations = new List<DonationApplication__c>();
        
        for (ContinuousDonationItem__c item : donationItems) {
            // Date__cがnullの場合は処理をスキップ
            if (item.Date__c == null) {
                continue;
            }
            
            // 現在のレコードの日付から翌月の1日を算出
            Date nextMonthDate = Date.newInstance(item.Date__c.year(), item.Date__c.month(), 1).addMonths(1);
            
            // 次月のContinuousDonationItem__cを作成
            newDonationItems.add(new ContinuousDonationItem__c(
                Amount__c = item.Amount__c,
                ContinuousDonationId__c = item.ContinuousDonationId__c,
                PaymentType__c = item.PaymentType__c,
                Date__c = nextMonthDate,
                Status__c = 'Reservation'
            ));
            
            // 対応するDonationApplication__cを作成
            newDonations.add(new DonationApplication__c(
                AccountId__c = item.ContinuousDonationId__r.AccountId__c,
                Amount__c = item.Amount__c,
                ContactId__c = item.ContinuousDonationId__r.ContactId__c,
                // mod start 25/9/16 Akiyama 毎月寄付.寄付者.レコードタイプが個人以外のみGMO決済者にセット
                // add start 25/9/10 Akiyama GMO決済者にもセット
                    // ContributionRepPerson__c = item.ContinuousDonationId__r.ContactId__c,
                ContributionRepPerson__c = (item.ContinuousDonationId__r.AccountId__r.RecordType.DeveloperName == 'PersonAccount') ? null : item.ContinuousDonationId__r.ContactId__c,
                // add end 25/9/10
                // mod end 25/9/16
                ContinuousDonationId__c = item.ContinuousDonationId__c,
                Date__c = item.Date__c,
                DonationReason__c = item.ContinuousDonationId__r.DonationReason__c,
                DonationType__c = donationRecordType.Name,
                FundId__c = item.ContinuousDonationId__r.FundId__c,
                GMOAccessID__c = item.ContinuousDonationId__r.GMOAccessID__c,
                GMOAccessPass__c = item.ContinuousDonationId__r.GMOAccessPass__c,
                GMOMemberID__c = item.ContinuousDonationId__r.GMOMemberID__c,
                GMOPaymethod__c = item.ContinuousDonationId__r.GMO_Paymethod__c,
                GmoAutomaticSalesId__c = item.ContinuousDonationId__r.GmoAutomaticSalesId__c,
                PaymentType__c = item.PaymentType__c,
                ReceiptRequest__c = item.ContinuousDonationId__r.ReceiptRequest__c,
                // add start 25/8/29 Akiyama  公開希望と公開名も、毎月寄付からコピーする
                IsRelease__c = item.ContinuousDonationId__r.IsRelease__c,
                ReleaseName__c = item.ContinuousDonationId__r.ReleaseName__c,
                // add end 25/8/29
                RecordTypeId = donationRecordType.Id
            ));
            
            // 現在のアイテムは処理済みとする
            item.Status__c = 'Processed';
        }
        
        // 新規ContinuousDonationItem__cの挿入
        if (!newDonationItems.isEmpty()) {
            try {
                insert newDonationItems;
            } catch (DmlException e) {
                System.debug(e.getMessage());
            }
        }
        
        // 新規DonationApplication__cの挿入
        if (!newDonations.isEmpty()) {
            try {
                insert newDonations;
            } catch (DmlException e) {
                System.debug(e.getMessage());
            }
        }
        
        // 処理済みのContinuousDonationItem__cレコードの更新
        try {
            update donationItems;
        } catch (DmlException e) {
            System.debug(e.getMessage());
        }
    }
    
    /**
     * Batchableインターフェースのfinishメソッド
     */
    global void finish(Database.BatchableContext bc) {
    }
}