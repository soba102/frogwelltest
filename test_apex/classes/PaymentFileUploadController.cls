/**
 * <h1>入金CSVアップロード処理</h1>
 * <ul>
 * <li>フローから呼び出される前提</li>
 * <li>ContentVersionを抽出し処理する。</li>
 * <li>複数ファイル対応可能</li>
 * <li>行分割は「\n」。ただし「\r\n」を「\n」に変換</li>
 * <li>行分割をsplitで処理すると、Regex too complexが発生するので、行分割文字までを切り出す方法で処理</li>
 * <li>列分割は「,」。ただし「"」は削除して扱う</li>
 * <li>CSV規格 RFC4180との違い</li>
 * <li>データ値として「"」を扱えない</li>
 * <li>データ値として「,」を扱えない</li>
 * <li>データ値として「\r\n」、「\n」を扱えない</li>
 * </ul>
 * frogwell.horio.add.comment
 * @since 1.0
 */
public class PaymentFileUploadController {
    static String YUCHO = 'ゆうちょ';
    static String MITSUBISHI = '三菱UFJ';
    static String OVERSEA = '海外送金';
    static INTEGER numberOfLimit = Integer.valueOf(Label.PAYMENT_CSV_IMPORT_LIMIT);
    // 改行コード CRLF
    private static String CRLF = '\r\n';
    // 改行コード LF
    private static String LF = '\n';
    public class Params {
        @InvocableVariable(label='recordId' required=true)
        public String recordId;

        @InvocableVariable(label='contentVersionId' required=true)
        public String contentVersionId;
    }
    /**
        @fileType
        GMO決済
        PayPal
        ゆうちょ
        現金書留
        ROBOT PAYMENT
        ヤフー
        銀行振込
        郵便振替
        海外送金
        贖罪
        自販機
        TF金属換金
        遺贈
    **/
    @InvocableMethod(label='入金ファイルアップロード' description='パラメータ１：入金データID　パラメータ２：ContentDocumentID')
    public static List<String> paymentFileUpload(List<Params> params) {
        try {
            //基金の取得
            Map<String, Fund__c> fundMap = new Map<String, Fund__c>();
            for(Fund__c item : [SELECT Name,AccountNumberVirtual__c FROM Fund__c WHERE AccountNumberVirtual__c != null]){
                fundMap.put(item.AccountNumberVirtual__c,item);
            }
            //2024.09.26 ゆうちょフォーマット変更
            //ゆうちょ基金の取得
            Map<String, Fund__c> fundyMap = new Map<String, Fund__c>();
            for(Fund__c item2 : [SELECT Name,YuchoDirectAccountNumber__c  FROM Fund__c WHERE YuchoDirectAccountNumber__c != null]){
                String raw = item2.YuchoDirectAccountNumber__c;
                if (raw != null && raw.length() >= 6) {
                    fundyMap.put(raw.right(6), item2);
                }
            }

            List<String> ids = params[0].contentVersionId.removeStart('[').removeEnd(']').split(',');

            //2024.09.26 複数ファイル不可
            List<ContentVersion> cvList = [SELECT ContentDocumentId, VersionData FROM ContentVersion WHERE Id IN :ids];
            if(cvList.size() == 0){
                throw new HandledException ('ファイルがアップロードされていません。ファイルをアップロードして下さい。');
            }
            else if(cvList.size() > 1){
                throw new HandledException ('一度に登録できるのは1ファイルのみです。');
            }else{

                List<PaymentDetail__c> pdList = new List<PaymentDetail__c>();
                String type = '';

                //2024.09.26 複数ファイル不可
                for(ContentVersion cv : cvList){
                //for(ContentVersion cv : [SELECT ContentDocumentId, VersionData FROM ContentVersion WHERE Id in :ids]){
                    String csvData = cv.VersionData.toString();
                    // 改行コードを変換
                    csvData = csvData.replace(CRLF, LF);
                    List<String> rows = csvData.split(LF);
                    Integer rowNumber = 1;
                    
                    //2024.09.26 ゆうちょフォーマット変更
                    //ヘッダー処理
                    Integer headerRowNumber = 1;
                    boolean yuchoFlg = false;
                    String yuchoFundName = '';
                    for (String headerRow : rows) {
                        List<String> headerFields = headerRow.split(',');
                        if(headerRowNumber == 1){
                            if(headerFields[0].replace('"', '') == '1'){
                                type = MITSUBISHI;
                                break;
                            }else if(headerFields[0].replace('"', '') == 'お客さま口座情報'){
                                yuchoFlg = true;
                            }else if(headerFields[0].replace('"', '') == '取引銀行番号'){
                                type = OVERSEA;
                                break;
                            }else{
                                throw new HandledException ('ファイルフォーマットエラー');
                            }
                        }else if(headerRowNumber == 4){
                            if(yuchoFlg == true && headerFields[0].replace('"', '').length() > 8 && headerFields[0].replace('"', '').left(8) == 'お客さま口座番号'){
                                type = YUCHO;
                                //ゆうちょダイレクト口座番号に一致する基金取得
                                if(fundyMap.get(headerFields[0].replace('"', '').right(6)) != null){
                                    yuchoFundName = fundyMap.get(headerFields[0].replace('"', '').right(6)).Name;
                                }
                                break;
                            }else{
                                throw new HandledException ('ファイルフォーマットエラー');
                            }
                        }
                        System.debug('yuchoFundName: ' + yuchoFundName);
                        headerRowNumber++;
                    }
                    
                    Boolean isContinue = true;
                    while (isContinue) {
                        Integer firstLFps = csvData.indexOf(LF);
                        String row = '';
                        if (firstLFps < 0 ) {
                            if (String.isBlank(csvData)) {
                                isContinue = false;
                                break;    
                            } else {
                                row = csvData;
                                csvData = '';
                            }
                        } else {
                            row = csvData.substring(0, firstLFps);
                            csvData = csvData.substring(firstLFps + 1);
                            System.debug('row:' + row);
                        }
                        //カンマ区切り
                        List<String> fields = row.split(',');

                        //2024.09.26 ゆうちょフォーマット変更
                        /*if(rowNumber == 1){
                            if(fields[0].replace('"', '') == '1'){
                                type = MITSUBISHI;
                            }else if(fields[0].replace('"', '') == 'お客さま口座情報'){
                                type = YUCHO;
                            }else if(fields[0].replace('"', '') == '取引銀行番号'){
                                type = OVERSEA;
                            }else{
                                throw new HandledException ('ファイルフォーマットエラー');
                            }
                        }*/

                        if(type == YUCHO){
                            if(rowNumber > 8){
                                String dateString = fields[0].replace('"', '');
                                Integer year = Integer.valueOf(dateString.substring(0, 4));
                                Integer month = Integer.valueOf(dateString.substring(4, 6));
                                Integer day = Integer.valueOf(dateString.substring(6, 8));
                                //2024.09.26 ゆうちょフォーマット変更
                                PaymentDetail__c pd = new PaymentDetail__c(
                                    Payment__c = params[0].recordId
                                    ,LowData__c = row
                                    ,Date__c = Date.newInstance(year, month, day)
                                    ,Amount__c = Decimal.valueOf(fields[3].replace('"', ''))
                                    ,Remarks__c = fields[6].replace('"', '') + ' ' + fields[7].replace('"', '')
                                    ,Fund__c = yuchoFundName
                                );
                                pdList.add(pd);
                            }
                        }
                        else if(type == MITSUBISHI){
                            if(fields[0].replace('"', '') == '2'){
                                String dateString = ''; 
                                if (!String.isBlank(fields[2].replace('"', ''))) {
                                    dateString = fields[2].replace('"', ''); // fields2取引日が空白でない場合はField2をセット
                                } 
                                if (String.isBlank(fields[2].replace('"', '')) &&!String.isBlank(fields[1].replace('"', ''))) {
                                    dateString = fields[1].replace('"', '');  // fields2取引日 が Blank かつ fields1 指定日が空白でない場合は fields1 をセット
                                } else if (String.isBlank(fields[2].replace('"', '')) && String.isBlank(fields[1].replace('"', ''))) {
                                                            return new List<String>{'ファイルのアップロードに失敗しました: ' + rowNumber + '行目の入金日が空です。'}; // エラー
                                                        }
                                // ピリオドで分割
                                String[] dateParts = dateString.split('\\.');
                                // 各部分を整数に変換
                                Integer year = Integer.valueOf(dateParts[0]);
                                Integer month = Integer.valueOf(dateParts[1]);
                                Integer day = Integer.valueOf(dateParts[2]);
                                // Date オブジェクトの作成
                                Date myDate = Date.newInstance(year, month, day);
                                String fundName = '';

                                //if(fundMap.get(fields[7].replace('"', '')) != null){
                                //    fundName = fundMap.get(fields[7].replace('"', '')).Name;
                                //}
                                String cleanedField7 = fields[7].replace('"', '');
                                if (String.isBlank(cleanedField7) || cleanedField7.length() == 10) {
                                String fundKey = String.isBlank(cleanedField7) ? cleanedField7 : cleanedField7.substring(3);
                                fundName = fundMap.get(fundKey)?.Name; 
                                 }
                                PaymentDetail__c pd = new PaymentDetail__c(
                                    Payment__c = params[0].recordId
                                    ,LowData__c = row
                                    ,Date__c = Date.newInstance(year, month, day)
                                    ,Amount__c = Decimal.valueOf(fields[9].replace('"', ''))
                                    ,Remarks__c = fields[4].replace('"', '')
                                    ,Fund__c = fundName
                                );
                                pdList.add(pd);
                            }
                        }
                        else if(type == OVERSEA){
                            if(rowNumber > 1 && fields.size() >= 10){
                                
                                fields = row.split('","');
                                
                                String dateString = fields[5].replace('"', '');
                                // ピリオドで分割
                                String[] dateParts = dateString.split('\\.');
                                // 各部分を整数に変換
                                Integer year = Integer.valueOf(dateParts[0]);
                                Integer month = Integer.valueOf(dateParts[1]);
                                Integer day = Integer.valueOf(dateParts[2]);
                                // Date オブジェクトの作成
                                Date myDate = Date.newInstance(year, month, day);
                                System.debug(Decimal.valueOf(fields[145].replace('"', '')));
                                PaymentDetail__c pd = new PaymentDetail__c(
                                    Payment__c = params[0].recordId
                                    ,LowData__c = row
                                    ,Date__c = Date.newInstance(year, month, day)
                                    ,Amount__c = Decimal.valueOf(fields[145].replace('"', ''))
                                    ,Remarks__c = fields[10].replace('"', '')
                                );
                                pdList.add(pd);
                            }
                        }
                        rowNumber++;
                        if(pdList.size() > numberOfLimit){
                            return new List<String>{'インポートできる上限件数' + numberOfLimit + '件を越えています。'};
                        }
                    }
                    System.debug('rowNumber:' + rowNumber);
                }
                if(pdList.isEmpty()){
                    return new List<String>{'インポート対象のデータがありません。'};
                }else{
                    //ファイルタイプの設定
                    Payment__c p = [SELECT Type__c FROM Payment__c WHERE id = :params[0].recordId];
                    p.Type__c = type;
                    update p;
                    //入金明細の登録
                    insert pdList;
                    return new List<String>{pdList.size() + '件のデータインポートに成功しました。'};
                }
            }
        } catch (Exception e) {
            return new List<String>{'ファイルのアップロードに失敗しました: ' + e.getMessage()};
        }
    }
}