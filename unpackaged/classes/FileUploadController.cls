/**
 * <h1>汎用ファイルアップロード処理クラス</h1>
 * <ul>
 * <li></li>
 * </ul>
 **/
public class FileUploadController {
    public class Params {
        @InvocableVariable(label='recordId' required=true)
        public String recordId;

        @InvocableVariable(label='contentVersionId' required=true)
        public String contentVersionId;

        @InvocableVariable(label='filePicklistName' required=true)
        public String filePicklistName;        

        @InvocableVariable(label='fromDate')
        public Date fromDate;

        @InvocableVariable(label='toDate')
        public Date toDate;     
    }

    /**
     * アップロード処理
     * <p>フローからのエントリーポイント</p>
     * @param params アップロードファイル情報
     * frogwell.horio.add.comment
     *
     * <p>失敗時は例外をスロー</p>
     **/
    @InvocableMethod(label='ファイルアップロード' description='パラメータ１：対象オブジェクトデータID　パラメータ２：ContentVersionID')
    public static List<String> FileUpload(List<Params> params) {
        try{
            List<String> ids = params[0].contentVersionId.removeStart('[').removeEnd(']').split(',');
            List<ContentVersion> cv = [SELECT ContentDocumentId, VersionData,Title,FileExtension FROM ContentVersion WHERE Id IN :ids];

            if(cv.size() == 0){
                throw new HandledException ('ファイルがアップロードされていません。ファイルをアップロードして下さい。');
            }
            else if(cv.size() > 1){
                throw new HandledException ('一度に登録できるのは1ファイルのみです。');
            }
            else{
                String csvTitle = cv[0].Title;  //csvファイル名
                String FileExtension = cv[0].FileExtension;  //csvファイル拡張子
                String csvData = cv[0].VersionData.toString(); //csvファイル内データ
                Schema.sObjectType entityType = Id.valueOf(params[0].recordId).getSObjectType();
                Set<String> duplicateKeyList = new Set<String>();
                Set<String> duplicateMailList = new Set<String>();
                
                List<String> rows = csvData.split('\n');

                if(entityType == VendingMachinePayment__c.sObjectType){
                    system.debug('###振込予定データインポートStart');
                    VendingMachinePayment__c vmp = [SELECT Id, AccountId__c FROM VendingMachinePayment__c WHERE Id =: params[0].recordId limit 1];
                    List<VendingMachineDonationDetails__c> vmddList = new List<VendingMachineDonationDetails__c>();   
                    List<VendingMachine__c> vmList = [SELECT Id, IdentificationId__c FROM VendingMachine__c WHERE IdentificationId__c != null and (VenderAccountId__c =: vmp.AccountId__c or VenderAccountId__c = null)];
                    Map<String,Id> vmMap = new Map<String,Id>();
                    for(VendingMachine__c vm : vmList){
                        if(vmMap.containsKey(vm.IdentificationId__c)){
                            duplicateKeyList.add(vm.IdentificationId__c);
                        }
                        else{
                            vmMap.put(vm.IdentificationId__c, vm.Id);
                        }
                    }
                    Integer rowNumber = 1;
                    Integer error = 0;
                    for (String row : rows) {
                        //カンマ区切り
                        List<String> fields = row.split(',');

                        //3行目からループスタート
                        if(rowNumber > 2){

                            VendingMachineDonationDetails__c vmdd = new VendingMachineDonationDetails__c();
                            vmdd.VendingMachinePaymentId__c = params[0].recordId;

                            vmdd.IdentificationId__c = fields[1];
                            vmdd.LocationNameInsert__c = fields[2];

                            try{
                                vmdd.UnitPrice__c = Decimal.valueOf(fields[3]);
                            } catch  (Exception e) {
                                continue;
                            } //単価へ代入  
                            
                            try{
                                vmdd.NumberOfPieces__c = Decimal.valueOf(fields[4]);
                            } catch  (Exception e) {
                                continue;
                            } //本数へ代入                                                       
                            
                            try{
                                vmdd.ExpectedPaymentAmount__c = Decimal.valueOf(fields[5]);
                            } catch  (Exception e) {
                                continue;
                            }

                            vmdd.Memo__c = fields[6];
    
                            if(String.isNotBlank(fields[0])){
                                if(!duplicateKeyList.contains(fields[0]) && vmMap.containsKey(fields[0])){
                                    vmdd.VendingMachineId__c = vmMap.get(fields[0]);
                                }
                            }
                            if(Decimal.valueOf(fields[5]) > 0){ //入金予定額が1以上のものを対象としてリストに追加
                                vmddList.add(vmdd);
                            }
                        }
                        rowNumber++;
                    }
                    if(vmddList.size() > 0){
                        insert vmddList;
                        return new List<String>{vmddList.size() + '件のデータインポートに成功しました。'};
                    }

                }
                else if(entityType == DonationCollectionAgency__c.sObjectType){
                    system.debug('###集金代行型寄付データインポートStart');
                    
                    //csvファイルに含まれている突合キーリスト
                    List<String> matchingKeyList = new List<String>();
                    //csvファイルに含まれているメールアドレスリスト                    
                    List<String> mailList = new List<String>();
                    
                    //取得するAccount件数を最小限にする為、事前に各リストを作成
                    Integer rowNumber = 1;
                    for (String row : rows) {
                        List<String> fields = row.split(',');
                        if(rowNumber > 1){
                            if(Decimal.valueOf(fields[3]) == 0){
                                throw new HandledException ('金額が0円のレコードが含まれています。');
                            }                            
                            if(String.isNotBlank(fields[0])){
                                    matchingKeyList.add(fields[0]);
                            }
                            if(String.isNotBlank(fields[2])){
                                    mailList.add(fields[2]);
                            }
                        }
                        rowNumber++;
                    }
                                        
                    List<DonationCollectionAgencyDetail__c> dcadList = new List<DonationCollectionAgencyDetail__c>();
                    //List<Account> accKeyList = [SELECT Id, MatchingKey__c FROM Account WHERE MatchingKey__c != null];
                    List<Account> accKeyList = [SELECT Id, MatchingKey__c FROM Account WHERE MatchingKey__c IN: matchingKeyList];
                    //List<Account> accMailList = [SELECT Id, PersonEmail FROM Account WHERE PersonEmail != null];
                    List<Account> accMailList = [SELECT Id, PersonEmail FROM Account WHERE PersonEmail IN: mailList];
                    system.debug('###accKeyList: ' + accKeyList.size() + ' , accMailList: ' + accMailList.size());

                    Map<String,Id> accKeyMap = new Map<String,Id>();
                    Map<String,Id> accMailMap = new Map<String,Id>();
                    
                    for(Account acc : accKeyList){
                        if(accKeyMap.containsKey(acc.MatchingKey__c)){
                            duplicateKeyList.add(acc.MatchingKey__c); 
                        }
                        else{
                            accKeyMap.put(acc.MatchingKey__c, acc.Id);
                        }
                    }
                    for(Account acc : accMailList){
                        if(accMailMap.containsKey(acc.PersonEmail)){
                            duplicateMailList.add(acc.PersonEmail); 
                        }
                        else{
                            accMailMap.put(acc.PersonEmail, acc.Id);
                        }
                    }
                    
                    rowNumber = 1;
                    for (String row : rows) {
                        //カンマ区切り
                        List<String> fields = row.split(',');
                        if(rowNumber > 1){
                            /*
                            if(Decimal.valueOf(fields[3]) == 0){
                                throw new HandledException ('金額が0円のレコードが含まれています。');
                            }
                            */
                            DonationCollectionAgencyDetail__c dcad = new DonationCollectionAgencyDetail__c();
                            dcad.DonationCollectionAgency__c = params[0].recordId;
                            dcad.MatchingKey__c = fields[0];
                            dcad.Donor__c = fields[1];
                            dcad.Mail__c = fields[2];
                            dcad.Amount__c = Decimal.valueOf(fields[3]);
                            dcad.ApplicationDate__c = Date.valueOf(fields[4]);
                            dcad.Memo__c = fields[5];
                            
                            if(String.isNotBlank(fields[0]) && accKeyMap.containsKey(fields[0]) && !duplicateKeyList.contains(fields[0])){
                                    dcad.AccountId__c = accKeyMap.get(fields[0]);
                            }
                            else if(String.isNotBlank(fields[2]) && accMailMap.containsKey(fields[2]) && !duplicateMailList.contains(fields[2])){
                                    dcad.AccountId__c = accMailMap.get(fields[2]);
                            }
                            
                            dcadList.add(dcad);
                        }
                        rowNumber++;
                    }
                    if(dcadList.size() > 0){
                        insert dcadList;
                        return new List<String>{dcadList.size() + '件のデータインポートに成功しました。'};
                    }
                }
                //*********************************GMO取込Start*********************************  
                else if(entityType == GMOUpload__c.sObjectType){
                    system.debug('###GMO取込データインポートStart');
                    //csvファイルのfield設定用
                    List<String> torihikiIdList = new List<String>();
                    List<String> orderIdList = new List<String>();
                    List<String> autoSalesIdList = new List<String>();
                    List<String> memberIdList = new List<String>();


                    Map<String,Id> torihikiIdMap = new Map<String,Id>(); //Map(GMO取引ID、寄付行為Id)
                    Map<String,Id> autoIdMap = new Map<String,Id>(); //Map(自動売上ID、寄付行為Id)
                    Map<String,Id> orderIdMap = new Map<String,Id>(); //Map(オーダーID、寄付行為Id)
                    Map<String,Id> memberIdMap = new Map<String,Id>(); //Map(メンバーID、寄付行為Id)
                    
                    Map<String,Id> duplicateFxOrderIdMap = new Map<String,Id>(); //Map(FxOrderId、寄付行為Id)　FxOrderId重複確認用Map                   

                    List<GMOUpload__c> gmoListUpd = new List<GMOUpload__c>(); //GMO取込
                    List<GMOUploadDetail__c> gmodlListInsert = new List<GMOUploadDetail__c>(); //GMO取込明細
                    List<DonationApplication__c> daListUpd = new List<DonationApplication__c>(); //寄付行為更新用

                    System.debug('★csvTitle'+csvTitle);
                    //取引IDを基に寄付行為を設定
                    // カンマ区切りで列を分割                   
                    for (Integer i = 0; i < rows.size(); i++) {
                        String row = rows[i].trim();
                        // カンマ区切りで列を分割
                        List<String> fields = row.split(',');
                        //docomoファイルの場合
                        if(params[0].filePicklistName == 'docomo'){
                            if(!csvTitle.contains('Docomo')){
                                return new List<String>{'選択されたファイル取込名とアップロードファイル名が一致していません。'};
                            }else if(String.isNotBlank(fields[10])){
                                torihikiIdList.add(fields[10].replace('"',''));
                            }    
                        }
                        //auPayファイルの場合
                        if(params[0].filePicklistName == 'aupay'){
                            if(!csvTitle.contains('Au')){
                                return new List<String>{'選択されたファイル取込名とアップロードファイル名が一致していません。'};
                            }else if(String.isNotBlank(fields[11])){
                                torihikiIdList.add(fields[11].replace('"',''));
                            }
                        }
                        //自動売上(クレジットカード)ファイルの場合
                        if(params[0].filePicklistName == 'クレジットカード'){
                            if(!csvTitle.contains('CreditRe')){
                                return new List<String>{'選択されたファイル取込名とアップロードファイル名が一致していません。'};
                            }else if(String.isNotBlank(fields[1])){
                                autoSalesIdList.add(fields[1].replace('"',''));
                            }
                        }
                        //自動売上(口座振替)ファイルの場合
                        if(params[0].filePicklistName == '口座振替'){
                            if(!csvTitle.contains('SelectTrade')){
                                return new List<String>{'選択されたファイル取込名とアップロードファイル名が一致していません。'};
                            }else if(String.isNotBlank(fields[7])){
                                memberIdList.add(fields[7].replace('"',''));
                            }
                        }
                        //マルチ取引ファイルの場合
                        if(params[0].filePicklistName == 'マルチ取引'){
                            if(!csvTitle.contains('Multi')){
                                return new List<String>{'選択されたファイル取込名とアップロードファイル名が一致していません。'};
                            }else if(String.isNotBlank(fields[1])){
                                orderIdList.add(fields[1].replace('"',''));
                            }
                        }
                    }

                    //GMO取込取得
                    GMOUpload__c gmo = [SELECT Id,FileType__c,DetailUploadDate__c,Amount__c FROM GMOUpload__c WHERE Id =:params[0].recordId];                   
                    //寄付行為取得（取引ID）
                    List<DonationApplication__c> daTorihikiList = [SELECT Id,GMOAccessID__c,GmoOrderId__c,Checked__c,
                                                                          AccessStatus__c,AccessResult__c,AccessErrInfo__c 
                                                                     FROM DonationApplication__c 
                                                                    WHERE (AccessResult__c = null OR AccessResult__c='その他') 
                                                                      AND GMOAccessID__c IN :torihikiIdList AND Date__c >=: params[0].fromDate AND Date__c <=: params[0].toDate ];
                    //寄付行為取得（自動売上ID）
                    List<DonationApplication__c> daAutoList = [SELECT Id,GmoAutomaticSalesId__c,GMOAccessID__c,GmoOrderId__c,Checked__c,
                                                                      AccessStatus__c,AccessResult__c,AccessErrInfo__c 
                                                                 FROM DonationApplication__c 
                                                                WHERE (AccessResult__c = null OR AccessResult__c='その他') 
                                                                  AND GmoAutomaticSalesId__c IN :autoSalesIdList AND Date__c >=: params[0].fromDate AND Date__c <=: params[0].toDate  ];
                    //寄付行為取得（オーダーID）
                    List<DonationApplication__c> daOrderList = [SELECT Id,GMOAccessID__c,GmoOrderId__c,Checked__c,
                                                                       AccessStatus__c,PaymentUnitID__c,FxOrderId__c
                                                                  FROM DonationApplication__c 
                                                                 WHERE FxOrderId__c IN :orderIdList AND Date__c >=: params[0].fromDate AND Date__c <=: params[0].toDate ];
                    //寄付行為取得（メンバーID）
                    List<DonationApplication__c> daMemberList = [SELECT Id,GmoAutomaticSalesId__c,GMOAccessID__c,GmoOrderId__c,Checked__c,
                                                                        AccessStatus__c,AccessResult__c,GMOMemberID__c,AccessErrInfo__c 
                                                                   FROM DonationApplication__c 
                                                                  WHERE (AccessResult__c = null OR AccessResult__c='その他') 
                                                                    AND GmoMemberId__c IN :memberIdList AND Date__c >=: params[0].fromDate AND Date__c <=: params[0].toDate  ];               
                    
                    System.debug('★daTorihikiList'+daTorihikiList);
                    System.debug('★daAutoList'+daAutoList);
                    System.debug('★daOrderList'+daOrderList);
                    System.debug('★daMemberList'+daMemberList);

                    //重複確認用Set //Fix:24/11/21
                    Set<String> DuplicateKey_Set = new Set<String>();

                    //Map(GMO取引ID、寄付行為Id)を設定 //重複不可
                    for(DonationApplication__c da : daTorihikiList){
                        String daKey = da.GMOAccessID__c;
                        if (!torihikiIdMap.containsKey(daKey)) {
                            torihikiIdMap.put(daKey,da.Id);
                        }
                        else {
                            DuplicateKey_Set.add(daKey);
                        }
                    }

                    //Map(自動売上ID、寄付行為Id)を設定 //重複不可
                    for(DonationApplication__c da : daAutoList){
                        String daKey = da.GmoAutomaticSalesId__c;
                        if (!torihikiIdMap.containsKey(daKey)) {
                            torihikiIdMap.put(daKey,da.Id);
                        }
                        else {
                            DuplicateKey_Set.add(daKey);
                        }
                    }

                    //Map(オーダーID、寄付行為Id)を設定
                    for(DonationApplication__c da : daOrderList){
                        String daKey = da.FxOrderId__c;
                        if (!torihikiIdMap.containsKey(daKey)) {
                            torihikiIdMap.put(daKey,da.Id);
                        }
                        else {
                            DuplicateKey_Set.add(daKey);
                        }
                    }

                    //Map(メンバーID、寄付行為Id)を設定 //重複不可
                    for(DonationApplication__c da : daMemberList){
                        String daKey = da.GmoMemberId__c;
                        if (!torihikiIdMap.containsKey(daKey)) {
                            torihikiIdMap.put(daKey,da.Id);
                        }
                        else {
                            DuplicateKey_Set.add(daKey);
                        }
                    }

                    //GMO取込を設定
                    gmo.FIleType__c = params[0].filePicklistName;   //20241005 修正
                    gmo.DetailUploadDate__c = Date.today();

                    //取り込むデータを一つの項目にまとめる
                    String allDataInOneField = '';
                    //csvをループ
                    for (Integer i = 0; i < rows.size(); i++) {
                        //各行を追加                     
                        allDataInOneField = rows[i] + '\n';

                        //GMO取込明細
                        GMOUploadDetail__c gmod = new GMOUploadDetail__c();
                        gmod.GMOUpload__c = params[0].recordId;
                        gmod.DetailData__c = allDataInOneField;
                        //【分岐④】キーが見つからない
                        if (daTorihikiList.isEmpty() && daAutoList.isEmpty() && daOrderList.isEmpty() && daMemberList.isEmpty()) {
                            System.debug('All lists are empty.');
                            gmod.OverallResult__c = 'エラー'; // 集計結果はエラー
                        }                        
                        else{
                        
                            //カンマ区切り
                            List<String> fields = allDataInOneField.split(',');

                            //取引IDで取得した寄付行為がある場合
                            if(daTorihikiList.size() > 0){
                                //寄付行為Listをループ
                                for(DonationApplication__c daInsert : daTorihikiList){
                                    /**処理１：docomo**/
                                    if(fields[10].replace('"','')==daInsert.GMOAccessID__c){
                                        //入金済False
                                        if(daInsert.Checked__c == false){
                                            //重複確認処理 //Fix:24/11/21
                                            String daKey = daInsert.GMOAccessID__c;
                                            if (DuplicateKey_Set.contains(daKey)) {
                                                gmod.OverallResult__c = '寄付行為重複エラー'; // 集計結果はエラー
                                                continue;
                                            }                                            
                                            //【分岐①】オーダーID未登録
                                            if(String.isBlank(daInsert.GmoOrderId__c)){
                                                daInsert.GmoOrderId__c = fields[1].replace('"','')+'_'+fields[2].replace('"','');//寄付行為のオーダーIDを更新
                                                daInsert.AccessErrInfo__c = fields[16].replace('"',''); //Fix：24/11/20：AccessErrInfo__cに情報を反映

                                                daInsert.DocomoSettlementCode__c = fields[8].replace('"','');

                                                // add start 2025/7/22 Akiyama  文字列長チェック追加
                                                    // daInsert.TranDate__c = Date.newInstance(Integer.valueOf(fields[17].replace('"','').substring(0,4)), Integer.valueOf(fields[17].replace('"','').substring(4,6)), Integer.valueOf(fields[17].replace('"','').substring(6,8)));
                                                    // daInsert.Date__c = Date.newInstance(Integer.valueOf(fields[17].replace('"','').substring(0,4)), Integer.valueOf(fields[17].replace('"','').substring(4,6)), Integer.valueOf(fields[17].replace('"','').substring(6,8)));
                                                String csvField17 = fields[17].replace('"','');
                                                if(String.isNotBlank(csvField17) && csvField17.length() >= 8){
                                                    daInsert.TranDate__c = Date.newInstance(Integer.valueOf(csvField17.replace('"','').substring(0,4)), Integer.valueOf(csvField17.replace('"','').substring(4,6)), Integer.valueOf(csvField17.replace('"','').substring(6,8)));
                                                    daInsert.Date__c = Date.newInstance(Integer.valueOf(csvField17.replace('"','').substring(0,4)), Integer.valueOf(csvField17.replace('"','').substring(4,6)), Integer.valueOf(csvField17.replace('"','').substring(6,8)));
                                                }
                                                // add end 2025/7/22

                                                daInsert.GMOErrCode__c = fields[15].replace('"','');
                                                daInsert.GMOErrInfo__c = fields[16].replace('"','');
                                                
                                                gmod.DonationApplication__c = torihikiIdMap.get(daInsert.GMOAccessID__c);//寄付行為を紐づけ
                                                gmod.OverallResult__c = '成功'; //集計結果は成功                                                
                                            }else{
                                                //オーダーID登録済み
                                                //【分岐➂】同一オーダーID登録済
                                                if(daInsert.GmoOrderId__c == fields[1].replace('"','')+'_'+fields[2].replace('"','')){
                                                    gmod.DonationApplication__c = torihikiIdMap.get(daInsert.GMOAccessID__c);//寄付行為を紐づけ
                                                    gmod.OverallResult__c = '取込済'; //集計結果は取込済
                                                }else{
                                                    //【分岐②】異なるオーダーID登録済
                                                    gmod.DonationApplication__c = torihikiIdMap.get(daInsert.GMOAccessID__c);//寄付行為を紐づけ
                                                    gmod.OverallResult__c = 'エラー'; //集計結果はエラー
                                                }                                        
                                            }
                                            //取引状態設定
                                            daInsert.AccessStatus__c = fields[3].replace('"','');
                                            if(fields[3].replace('"','') == 'SALES'){
                                                daInsert.AccessStatus__c = '課金済み';
                                            }
                                        }
                                    }
                                    /**処理２：AuPay**/
                                    if(fields[11].replace('"','')==daInsert.GMOAccessID__c){
                                        //入金済False
                                        if(daInsert.Checked__c == false){
                                            //重複確認処理 //Fix:24/11/21
                                            String daKey = daInsert.GMOAccessID__c;
                                            if (DuplicateKey_Set.contains(daKey)) {
                                                gmod.OverallResult__c = '寄付行為重複エラー'; // 集計結果はエラー
                                                continue;
                                            }
                                            //【分岐①】オーダーID未登録
                                            if(String.isBlank(daInsert.GmoOrderId__c)){
                                                daInsert.GmoOrderId__c = fields[1].replace('"','')+'_'+fields[2].replace('"','');//寄付行為のオーダーIDを更新
                                                daInsert.AccessErrInfo__c = fields[19].replace('"',''); //Fix：24/11/20：AccessErrInfo__cに情報を反映

                                                daInsert.AuPayInfoNo__c = fields[9].replace('"','');

                                                // add start 2025/7/22 Akiyama  文字列長チェック追加
                                                    // daInsert.TranDate__c = Date.newInstance(Integer.valueOf(fields[20].replace('"','').substring(0,4)), Integer.valueOf(fields[20].replace('"','').substring(4,6)), Integer.valueOf(fields[20].replace('"','').substring(6,8)));
                                                    // daInsert.Date__c = Date.newInstance(Integer.valueOf(fields[20].replace('"','').substring(0,4)), Integer.valueOf(fields[20].replace('"','').substring(4,6)), Integer.valueOf(fields[20].replace('"','').substring(6,8)));
                                                String csvField20 = fields[20].replace('"','');
                                                if(String.isNotBlank(csvField20) && csvField20.length() >= 8){
                                                    daInsert.TranDate__c = Date.newInstance(Integer.valueOf(csvField20.replace('"','').substring(0,4)), Integer.valueOf(csvField20.replace('"','').substring(4,6)), Integer.valueOf(csvField20.replace('"','').substring(6,8)));
                                                    daInsert.Date__c = Date.newInstance(Integer.valueOf(csvField20.replace('"','').substring(0,4)), Integer.valueOf(csvField20.replace('"','').substring(4,6)), Integer.valueOf(csvField20.replace('"','').substring(6,8)));
                                                }
                                                // add end 2025/7/22

                                                daInsert.GMOErrCode__c = fields[18].replace('"','');
                                                daInsert.GMOErrInfo__c = fields[19].replace('"','');
                                                
                                                gmod.DonationApplication__c = torihikiIdMap.get(daInsert.GMOAccessID__c);//寄付行為を紐づけ
                                                gmod.OverallResult__c = '成功'; //集計結果は成功
                                                
                                                
                                            }else{
                                                //オーダーID登録済み
                                                //【分岐➂】同一オーダーID登録済
                                                if(daInsert.GmoOrderId__c == fields[1].replace('"','')+'_'+fields[2].replace('"','')){
                                                    gmod.DonationApplication__c = torihikiIdMap.get(daInsert.GMOAccessID__c);//寄付行為を紐づけ
                                                    gmod.OverallResult__c = '取込済'; //集計結果は取込済
                                                }else{
                                                    //【分岐②】異なるオーダーID登録済
                                                    gmod.DonationApplication__c = torihikiIdMap.get(daInsert.GMOAccessID__c);//寄付行為を紐づけ
                                                    gmod.OverallResult__c = 'エラー'; //集計結果はエラー
                                                }
                                            }
                                            //取引状態設定
                                            daInsert.AccessStatus__c = fields[4].replace('"','');
                                            if(fields[4].replace('"','') == 'SALES'){
                                                daInsert.AccessStatus__c = '課金確定';
                                            }
                                            if(fields[4].replace('"','') == 'CAPTURE'){
                                                daInsert.AccessStatus__c = '課金成功';
                                            }
                                        }
                                    }
                                    //更新用寄付行為を設定
                                    daListUpd.add(daInsert);
                                } 
                            }

                            //自動売上IDで取得した寄付行為がある場合
                            if(daAutoList.size() > 0){
                                //寄付行為Listをループ
                                for(DonationApplication__c daInsert : daAutoList){
                                    /**処理３：自動売上(クレジットカード)**/
                                    if(fields[1].replace('"','')==daInsert.GmoAutomaticSalesId__c && csvTitle.contains('CreditRe')){
                                        //入金済False
                                        if(daInsert.Checked__c == false){
                                            //重複確認処理 //Fix:24/11/21
                                            String daKey = daInsert.GmoAutomaticSalesId__c;
                                            if (DuplicateKey_Set.contains(daKey)) {
                                                gmod.OverallResult__c = '寄付行為重複エラー'; // 集計結果はエラー
                                                continue;
                                            }                                            
                                            //【分岐①】オーダーID未登録
                                            if(String.isBlank(daInsert.GmoOrderId__c)){
                                                daInsert.GmoOrderId__c = fields[3].replace('"','');//寄付行為のオーダーIDを更新
                                                daInsert.AccessErrInfo__c = fields[8].replace('"',''); //Fix：24/11/20：AccessErrInfo__cに情報を反映
                                                
                                                // add start 2025/7/22 Akiyama  文字列長チェック追加
                                                    // daInsert.Date__c = Date.newInstance(Integer.valueOf(fields[2].replace('"','').substring(0,4)), Integer.valueOf(fields[2].replace('"','').substring(4,6)), Integer.valueOf(fields[2].replace('"','').substring(6,8)));
                                                    // daInsert.TranDate__c = Date.newInstance(Integer.valueOf(fields[10].replace('"','').substring(0,4)), Integer.valueOf(fields[10].replace('"','').substring(4,6)), Integer.valueOf(fields[10].replace('"','').substring(6,8)));
                                                String csvField2 = fields[2].replace('"','');
                                                if(String.isNotBlank(csvField2) && csvField2.length() >= 8){
                                                    daInsert.Date__c = Date.newInstance(Integer.valueOf(csvField2.replace('"','').substring(0,4)), Integer.valueOf(csvField2.replace('"','').substring(4,6)), Integer.valueOf(csvField2.replace('"','').substring(6,8)));
                                                }
                                                String csvField10 = fields[10].replace('"','');
                                                if(String.isNotBlank(csvField10) && csvField10.length() >= 8){
                                                    daInsert.TranDate__c = Date.newInstance(Integer.valueOf(csvField10.replace('"','').substring(0,4)), Integer.valueOf(csvField10.replace('"','').substring(4,6)), Integer.valueOf(csvField10.replace('"','').substring(6,8)));
                                                }
                                                // add end 2025/7/22

                                                daInsert.GMOErrCode__c = fields[7].replace('"','');
                                                daInsert.GMOErrInfo__c = fields[8].replace('"','');
                                                
                                                gmod.DonationApplication__c = torihikiIdMap.get(daInsert.GmoAutomaticSalesId__c);//寄付行為を紐づけ
                                                gmod.OverallResult__c = '成功'; //集計結果は成功 
                                            }else{
                                                //オーダーID登録済み
                                                //【分岐➂】同一オーダーID登録済
                                                if(daInsert.GmoOrderId__c == fields[3].replace('"','')){
                                                    gmod.DonationApplication__c = torihikiIdMap.get(daInsert.GmoAutomaticSalesId__c);//寄付行為を紐づけ
                                                    gmod.OverallResult__c = '取込済'; //集計結果は取込済
                                                }else{
                                                    //【分岐②】異なるオーダーID登録済
                                                    gmod.DonationApplication__c = torihikiIdMap.get(daInsert.GmoAutomaticSalesId__c);//寄付行為を紐づけ
                                                    gmod.OverallResult__c = 'エラー'; //集計結果はエラー
                                                }        
                                            }
                                            //取引状態設定
                                            daInsert.AccessStatus__c = fields[4].replace('"','');
                                            if(fields[4].replace('"','') == 'INVALID'){
                                                daInsert.AccessStatus__c = '課金不可';
                                            }
                                        }
                                    }
                                    //更新用寄付行為を設定
                                    daListUpd.add(daInsert);
                                }   
                            }
                            //メンバーIDで取得した寄付行為がある場合
                            if(daMemberList.size() > 0){
                                //寄付行為Listをループ
                                for(DonationApplication__c daInsert : daMemberList){                                
                                    /**処理４：自動売上（口座振替）**/
                                    if(fields[7].replace('"','')==daInsert.GmoMemberId__c && csvTitle.contains('SelectTrade')){
                                        //入金済False
                                        if(daInsert.Checked__c == false){
                                            //重複確認処理 //Fix:24/11/21
                                            String daKey = daInsert.GmoMemberId__c;
                                            if (DuplicateKey_Set.contains(daKey)) {
                                                gmod.OverallResult__c = '寄付行為重複エラー'; // 集計結果はエラー
                                                continue;
                                            }                                                                                        
                                            //【分岐①】オーダーID未登録
                                            if(String.isBlank(daInsert.GmoOrderId__c)){
                                                daInsert.GmoOrderId__c = fields[1].replace('"','');//寄付行為のオーダーIDを更新
                                                daInsert.AccessErrInfo__c = fields[16].replace('"',''); //Fix：24/11/20：AccessErrInfo__cに情報を反映

                                                // add start 2025/7/22 Akiyama  文字列長チェック追加
                                                    // daInsert.Date__c = Date.newInstance(Integer.valueOf(fields[30].replace('"','').substring(0,4)), Integer.valueOf(fields[30].replace('"','').substring(4,6)), Integer.valueOf(fields[30].replace('"','').substring(6,8)));
                                                    // daInsert.TranDate__c = Date.newInstance(Integer.valueOf(fields[13].replace('"','').substring(0,4)), Integer.valueOf(fields[13].replace('"','').substring(4,6)), Integer.valueOf(fields[13].replace('"','').substring(6,8)));
                                                String csvField30 = fields[30].replace('"','');
                                                if(String.isNotBlank(csvField30) && csvField30.length() >= 8){
                                                    daInsert.Date__c = Date.newInstance(Integer.valueOf(csvField30.replace('"','').substring(0,4)), Integer.valueOf(csvField30.replace('"','').substring(4,6)), Integer.valueOf(csvField30.replace('"','').substring(6,8)));
                                                }
                                                String csvField13 = fields[13].replace('"','');
                                                if(String.isNotBlank(csvField13) && csvField13.length() >= 8){
                                                    daInsert.TranDate__c = Date.newInstance(Integer.valueOf(csvField13.replace('"','').substring(0,4)), Integer.valueOf(csvField13.replace('"','').substring(4,6)), Integer.valueOf(csvField13.replace('"','').substring(6,8)));
                                                }
                                                // add end 2025/7/22

                                                daInsert.GMOErrCode__c = fields[15].replace('"','');
                                                daInsert.GMOErrInfo__c = fields[16].replace('"','');

                                                gmod.DonationApplication__c = torihikiIdMap.get(daInsert.GmoMemberId__c);//寄付行為を紐づけ
                                                gmod.OverallResult__c = '成功'; //集計結果は成功 
                                            }else{
                                                //オーダーID登録済み
                                                //【分岐➂】同一オーダーID登録済
                                                if(daInsert.GmoOrderId__c == fields[1].replace('"','')){
                                                    gmod.DonationApplication__c = torihikiIdMap.get(daInsert.GmoMemberId__c);//寄付行為を紐づけ
                                                    gmod.OverallResult__c = '取込済'; //集計結果は取込済
                                                }else{
                                                    //【分岐②】異なるオーダーID登録済
                                                    gmod.DonationApplication__c = torihikiIdMap.get(daInsert.GmoMemberId__c);//寄付行為を紐づけ
                                                    gmod.OverallResult__c = 'エラー'; //集計結果はエラー
                                                }        
                                            }
                                            //取引状態設定
                                            daInsert.AccessStatus__c = fields[14].replace('"','');
                                            if(fields[14].replace('"','') == 'CANCEL'){
                                                daInsert.AccessStatus__c = '請求取消';
                                            }
                                            if(fields[14].replace('"','') == 'PAYFAIL'){
                                                daInsert.AccessStatus__c = '請求失敗';
                                            }
                                        }
                                    }
                                    //更新用寄付行為を設定
                                    daListUpd.add(daInsert);
                                }   
                            }
                            //オーダーIDで取得した寄付行為がある場合
                            if(daOrderList.size() > 0){
                                //寄付行為Listをループ
                                for(DonationApplication__c daInsert : daOrderList){
                                    /**処理５：マルチ取引**/
                                    if(fields[1].replace('"','')==daInsert.FxOrderId__c){
                                        //入金済False
                                        if(daInsert.Checked__c == false){
                                            //重複確認処理
                                            if (DuplicateKey_Set.contains(daInsert.FxOrderId__c)) {
                                                gmod.OverallResult__c = '寄付行為重複エラー'; // 集計結果はエラー
                                                gmod.ResultNote__c = 'マルチ取引用オーダーIDが合致する寄付行為が複数有り';
                                                continue;
                                            }
                                            //20241005 PaymentUnitID__cがブランクの場合にファイル名を設定
                                            if(String.isBlank(daInsert.PaymentUnitID__c)){
                                                //daInsert.PaymentUnitID__c = csvTitle;
                                                daInsert.PaymentUnitID__c = fields[0].replace('"','') +'_'+ String.valueOf(params[0].toDate.year()) + String.valueOf(params[0].toDate.month()).leftPad(2, '0')  + String.valueOf(params[0].toDate.day()).leftPad(2, '0');
                                                IF(fields[4].contains('"')){
                                                    //Fix:24/11/20: 累計処理に変更
                                                    gmo.Amount__c = gmo.Amount__c != null ? gmo.Amount__c + Integer.valueOf(fields[4].replace('"','')) : Integer.valueOf(fields[4].replace('"',''));
                                                }else{
                                                    //Fix:24/11/20: 累計処理に変更
                                                    gmo.Amount__c = gmo.Amount__c != null ? gmo.Amount__c + Integer.valueOf(fields[4]) : Integer.valueOf(fields[4]);
                                                }
                                            }

                                            //オーダーID登録済み
                                            //【分岐➂】同一オーダーID登録済
                                            if(!String.isBlank(daInsert.FxOrderId__c) && daInsert.FxOrderId__c == fields[1].replace('"','')){
                                                gmod.DonationApplication__c = torihikiIdMap.get(daInsert.FxOrderId__c);//寄付行為を紐づけ
                                                gmod.OverallResult__c = '取込済'; //集計結果は取込済                                            
                                            }
                                                            
                                            //取引状態設定
                                            daInsert.AccessStatus__c = fields[2].replace('"','');
                                            //決済手段 &&　取得状態で判定 
                                            if(fields[3].replace('"','') == 'コンビニ' && fields[2].replace('"','') == 'CANCEL'){
                                                daInsert.AccessStatus__c = '支払停止';
                                            }
                                            if(fields[3].replace('"','') == 'auかんたん継続' && fields[2].replace('"','') == 'CANCEL'){
                                                daInsert.AccessStatus__c = '継続課金解約';
                                            }
                                            if(fields[3].replace('"','') == '払込票' && fields[2].replace('"','') == 'PAYSUCCESS'){
                                                daInsert.AccessStatus__c = '入金';
                                            }
                                            if(fields[3].replace('"','') == 'FamiPay' && fields[2].replace('"','') == 'PAYSUCCESS'){
                                                daInsert.AccessStatus__c = '決済成功';
                                            }
                                            if(fields[3].replace('"','') == '口座直結決済' && fields[2].replace('"','') == 'CAPTURE'){
                                                daInsert.AccessStatus__c = '決済成功';
                                            }
                                            if(fields[3].replace('"','') == 'ソフトバンク継続'){
                                                if(fields[2].replace('"','') == 'PAYFAIL'){
                                                    daInsert.AccessStatus__c = '継続課金登録失敗';
                                                }
                                                if(fields[2].replace('"','') == 'CANCEL'){
                                                    daInsert.AccessStatus__c = '継続課金解約';
                                                }
                                            }
                                            if(fields[3].replace('"','') == 'Amazon Pay'){
                                                if(fields[2].replace('"','') == 'AUTHPROCESS'){
                                                    daInsert.AccessStatus__c = '認証中';
                                                }
                                                if(fields[2].replace('"','') == 'REQRETURN'){
                                                    daInsert.AccessStatus__c = '返品受付';
                                                }
                                            }
                                            if(fields[3].replace('"','') == '多通貨クレジットカード'){
                                                if(fields[2].replace('"','') == 'AUTHENTICATED'){
                                                    daInsert.AccessStatus__c = '要求成功';
                                                }
                                                if(fields[2].replace('"','') == 'REQCAPTURE'){
                                                    daInsert.AccessStatus__c = '即時売上要求中';
                                                }
                                                if(fields[2].replace('"','') == 'CANCEL'){
                                                    daInsert.AccessStatus__c = '取消';
                                                }
                                            }
                                            if(fields[3].replace('"','') == '後払い'){
                                                if(fields[2].replace('"','') == 'AUTHPROCESS'){
                                                    daInsert.AccessStatus__c = '審査中';
                                                }
                                                if(fields[2].replace('"','') == 'AUTH'){
                                                    daInsert.AccessStatus__c = '審査 OK';
                                                }
                                                if(fields[2].replace('"','') == 'SALES'){
                                                    daInsert.AccessStatus__c = '立替払対象';
                                                }
                                            }
                                        }
                                    }
                                    
                                    //更新用寄付行為を設定
                                    daListUpd.add(daInsert);
                                }   
                            }
                        }
                        
                        //更新用GMO取込を設定
                        gmodlListInsert.add(gmod);
                        //更新用GMO取込明細を設定
                        gmoListUpd.add(gmo);
                    }

                    if(gmodlListInsert.size() > 0){
                        //GMO取込明細更新
                        insert gmodlListInsert;

                        //寄付行為更新
                        if(daListUpd.size() > 0){
                            Set<DonationApplication__c> daSet = new Set<DonationApplication__c>();
                            List<DonationApplication__c> daUpdAll = new List<DonationApplication__c>(); 
                            daSet.addAll(daListUpd);
                            daUpdAll.addAll(daSet);
                            update daUpdAll;
                        }

                        //GMO取込更新
                        if(gmoListUpd.size() > 0){
                            Set<GMOUpload__c> gmoSet = new Set<GMOUpload__c>();
                            List<GMOUpload__c> gmoUpdAll = new List<GMOUpload__c>(); 
                            gmoSet.addAll(gmoListUpd);
                            gmoUpdAll.addAll(gmoSet);
                            update gmoUpdAll;
                        }
                        return new List<String>{gmodlListInsert.size() + '件のデータインポートに成功しました。'};
                    }
                }
                //*********************************GMO取込End********************************* 
            }
            return new List<String>{'データインポートは実行されませんでした。'};
                
        } catch (Exception e) {
            return new List<String>{'ファイルのアップロードに失敗しました: ' + e.getMessage()};
        }
    }
}