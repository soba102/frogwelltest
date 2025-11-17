public class QuarterlyReportSummaryController {

    public class Params {
        @InvocableVariable(label='recordId' required=true)
        public String recordId;
        
        @InvocableVariable(label='terms' required=true)
        public Integer terms;
        
    }

    @InvocableMethod(label='四半期報告書集計' description='パラメータ１：対象オブジェクトデータID　パラメータ２：集計期間')
    public static List<String> QuarterlyReportSummary(List<Params> params) {
        try{
            //対象年度取得
            FiscalYear__c targetFiscalYear = [SELECT Id, Name, Status__c, FromDate__c, ToDate__c FROM FiscalYear__c WHERE Id =: params[0].recordId limit 1];

            //基金一覧取得
            List<FundFiscalYear__c> fundFiscalYearList = [SELECT Id, Name, FundId__c,
                                                           SummaryDate__c, SummaryTermFrom__c, AmountCarryForwardLastYear__c, 
                                                           DonationIncomeQ1_1__c, DonationIncomeQ1_2__c, DonationIncomeQ2_1__c, DonationIncomeQ2_2__c,
                                                           DonationIncomeQ3_1__c, DonationIncomeQ3_2__c, DonationIncomeQ4_1__c, DonationIncomeQ4_2__c,
                                                           Refund_1__c, Refund_2__c, TransferDeposit1__c, TransferDeposit2__c, MiscellaneousIncome1__c, MiscellaneousIncome2__c,
                                                           DecisionBusinessQ1_1__c, DecisionBusinessQ1_2__c, DecisionBusinessQ2_1__c, DecisionBusinessQ2_2__c,
                                                           DecisionBusinessQ3_1__c, DecisionBusinessQ3_2__c, DecisionBusinessQ4_1__c, DecisionBusinessQ4_2__c,
                                                           BeforeDecisionBusiness1__c, BeforeDecisionBusiness2__c,
                                                           AlreadyDecidedBusiness1__c, AlreadyDecidedBusiness2__c, TransferWithdrawal1__c, TransferWithdrawal2__c,
                                                           PaymentOfVariousNonBusinessFees1__c, PaymentOfVariousNonBusinessFees2__c, 
                                                           MiscellaneousExpenses1__c, MiscellaneousExpenses2__c, AmountCarryForwardNextYear__c
                                                    FROM FundFiscalYear__c WHERE FiscalYearId__c =: targetFiscalYear.Id];

            //集計期間を定義
            Date SummaryTermsFrom = targetFiscalYear.FromDate__c; 
            Date SummaryTermsTo = (Date.newInstance(((targetFiscalYear.FromDate__c).addMonths(params[0].terms)).year(), ((targetFiscalYear.FromDate__c).addMonths(params[0].terms)).month(), 1) - 1);
            String SummaryTermsFromString = String.valueOf(SummaryTermsFrom); 
            String SummaryTermsToString = String.valueOf(SummaryTermsTo);

            String SummaryTermsFromQ1String = String.valueOf(targetFiscalYear.FromDate__c); 
            String SummaryTermsToQ1String = String.valueOf((Date.newInstance(((targetFiscalYear.FromDate__c).addMonths(3)).year(), ((targetFiscalYear.FromDate__c).addMonths(3)).month(), 1) - 1));
            String SummaryTermsFromQ2String = String.valueOf((Date.newInstance(((targetFiscalYear.FromDate__c).addMonths(3)).year(), ((targetFiscalYear.FromDate__c).addMonths(3)).month(), 1)));
            String SummaryTermsToQ2String = String.valueOf((Date.newInstance(((targetFiscalYear.FromDate__c).addMonths(6)).year(), ((targetFiscalYear.FromDate__c).addMonths(6)).month(), 1) - 1));
            String SummaryTermsFromQ3String = String.valueOf((Date.newInstance(((targetFiscalYear.FromDate__c).addMonths(6)).year(), ((targetFiscalYear.FromDate__c).addMonths(6)).month(), 1)));
            String SummaryTermsToQ3String = String.valueOf((Date.newInstance(((targetFiscalYear.FromDate__c).addMonths(9)).year(), ((targetFiscalYear.FromDate__c).addMonths(9)).month(), 1) - 1));
            String SummaryTermsFromQ4String = String.valueOf((Date.newInstance(((targetFiscalYear.FromDate__c).addMonths(9)).year(), ((targetFiscalYear.FromDate__c).addMonths(9)).month(), 1)));
            String SummaryTermsToQ4String = String.valueOf(targetFiscalYear.ToDate__c);

            /*
                集計する基金入出金データ取得
            */
            //前年度繰越額
            String query1 = 'SELECT Id, Name, Status__c, Amount__c, Amount1__c, Amount2__c, FundFiscalYearId__c, ChkBox__c'
                           +' FROM FundTransaction__c'
                           +' WHERE RecordType.DeveloperName = \'CarriedOverFromPreviousFiscalYear\' and TypeDetail__c = \'1. 前年度繰越額\' AND Status__c = \'Processed\' AND FurikaeInFund__c = False' 
                           +' AND FundFiscalYearId__r.FiscalYearId__c = \'' + targetFiscalYear.Id + '\'';
                
            List<FundTransaction__c> AmountCarryForwardLastYear = database.query(query1);

            //寄付金収入額　Q1
            String query2 = 'SELECT Id, Name, Status__c, Amount__c, Amount1__c, Amount2__c, FundFiscalYearId__c, ChkBox__c'
                           +' FROM FundTransaction__c' 
                           +' WHERE RecordType.DeveloperName = \'DepositSlip\' and TypeDetail__c = \'2.1. 寄付金収入額\' AND Status__c = \'Processed\' AND FurikaeInFund__c = False AND FundFiscalYearId__r.FundId__r.Status__c NOT IN (\'終了\', \'ドラフト\')'
                           +' AND SlipCreatedDate__c >= ' + SummaryTermsFromQ1String + 'and SlipCreatedDate__c <=' + SummaryTermsToQ1String ;
            List<FundTransaction__c> DonationIncomeQ1 = database.query(query2);

            //寄付金収入額　Q2
            String query3 = 'SELECT Id, Name, Status__c, Amount__c, Amount1__c, Amount2__c, FundFiscalYearId__c, ChkBox__c'
                           +' FROM FundTransaction__c' 
                           +' WHERE RecordType.DeveloperName = \'DepositSlip\' and TypeDetail__c = \'2.1. 寄付金収入額\' AND Status__c = \'Processed\' AND FurikaeInFund__c = False AND FundFiscalYearId__r.FundId__r.Status__c NOT IN (\'終了\', \'ドラフト\')' 
                           +' AND SlipCreatedDate__c >= ' + SummaryTermsFromQ2String + 'and SlipCreatedDate__c <=' + SummaryTermsToQ2String ;
            
            List<FundTransaction__c> DonationIncomeQ2 = database.query(query3);

            //寄付金収入額　Q3
            String query4 = 'SELECT Id, Name, Status__c, Amount__c, Amount1__c, Amount2__c, FundFiscalYearId__c, ChkBox__c'
                           +' FROM FundTransaction__c' 
                           +' WHERE RecordType.DeveloperName = \'DepositSlip\' and TypeDetail__c = \'2.1. 寄付金収入額\' AND Status__c = \'Processed\' AND FurikaeInFund__c = False AND FundFiscalYearId__r.FundId__r.Status__c NOT IN (\'終了\', \'ドラフト\')' 
                           +' AND SlipCreatedDate__c >= ' + SummaryTermsFromQ3String + 'and SlipCreatedDate__c <=' + SummaryTermsToQ3String ;
            
            List<FundTransaction__c> DonationIncomeQ3 = database.query(query4);

            //寄付金収入額　Q4
            String query5 = 'SELECT Id, Name, Status__c, Amount__c, Amount1__c, Amount2__c, FundFiscalYearId__c, ChkBox__c'
                           +' FROM FundTransaction__c' 
                           +' WHERE RecordType.DeveloperName = \'DepositSlip\' and TypeDetail__c = \'2.1. 寄付金収入額\' AND Status__c = \'Processed\' AND FurikaeInFund__c = False AND FundFiscalYearId__r.FundId__r.Status__c NOT IN (\'終了\', \'ドラフト\')' 
                           +' AND SlipCreatedDate__c >= ' + SummaryTermsFromQ4String + 'and SlipCreatedDate__c <=' + SummaryTermsToQ4String ;
            
            List<FundTransaction__c> DonationIncomeQ4 = database.query(query5);
            
            //返還金
            String query6 = 'SELECT Id, Name, Status__c, Amount__c, Amount1__c, Amount2__c, FundFiscalYearId__c, ChkBox__c'
                           +' FROM FundTransaction__c' 
                           +' WHERE RecordType.DeveloperName = \'DepositSlip\' and TypeDetail__c = \'2.2. 返還金\' AND Status__c = \'Processed\' AND FurikaeInFund__c = False AND FundFiscalYearId__r.FundId__r.Status__c NOT IN (\'終了\', \'ドラフト\')' 
                           +' AND SlipCreatedDate__c >= ' + SummaryTermsFromString + 'and SlipCreatedDate__c <=' + SummaryTermsToString 
                           +' ORDER BY Date__c ASC, Name ASC';
            
            List<FundTransaction__c> Refund = database.query(query6);
            
            //振替入金
            String query7 = 'SELECT Id, Name, Status__c, Amount__c, Amount1__c, Amount2__c, FundFiscalYearId__c, ChkBox__c'
                           +' FROM FundTransaction__c' 
                           +' WHERE RecordType.DeveloperName = \'DepositSlip\' and TypeDetail__c = \'2.3. 振替入金\' AND Status__c = \'Processed\' AND FurikaeInFund__c = False AND FundFiscalYearId__r.FundId__r.Status__c NOT IN (\'終了\', \'ドラフト\')' 
                           +' AND SlipCreatedDate__c >= ' + SummaryTermsFromString + 'and SlipCreatedDate__c <=' + SummaryTermsToString 
                           +' ORDER BY Date__c ASC, Name ASC';
            
            List<FundTransaction__c> TransferDeposit = database.query(query7);
            
            //雑収入
            String query8 = 'SELECT Id, Name, Status__c, Amount__c, Amount1__c, Amount2__c, FundFiscalYearId__c, ChkBox__c'
                           +' FROM FundTransaction__c' 
                           +' WHERE RecordType.DeveloperName = \'DepositSlip\' and TypeDetail__c = \'2.4. 雑収入\' AND Status__c = \'Processed\' AND FurikaeInFund__c = False AND FundFiscalYearId__r.FundId__r.Status__c NOT IN (\'終了\', \'ドラフト\')' 
                           +' AND SlipCreatedDate__c >= ' + SummaryTermsFromString + 'and SlipCreatedDate__c <=' + SummaryTermsToString 
                           +' ORDER BY Date__c ASC, Name ASC';
                
            List<FundTransaction__c> MiscellaneousIncome = database.query(query8);
            
            //決定事業　Q1
            String query9 = 'SELECT Id, Name, Status__c, Amount__c, Amount1__c, Amount2__c, FundFiscalYearId__c, ChkBox__c'
                           +' FROM FundTransaction__c' 
                           +' WHERE RecordType.DeveloperName = \'WithdrawalSlip\' and TypeDetail__c = \'3.1. 決定事業\' AND Status__c = \'Reservation\' AND FurikaeInFund__c = False AND LinkCategory__c = \'四半期報告\' AND FundFiscalYearId__r.FundId__r.Status__c NOT IN (\'終了\', \'ドラフト\')' 
                           +' AND SlipCreatedDate__c >= ' + SummaryTermsFromQ1String + 'and SlipCreatedDate__c <=' + SummaryTermsToQ1String 
                           +' ORDER BY Date__c ASC, Name ASC';
            
            List<FundTransaction__c> DecisionBusinessQ1 = database.query(query9);

            //決定事業　Q2
            String query10 = 'SELECT Id, Name, Status__c, Amount__c, Amount1__c, Amount2__c, FundFiscalYearId__c, ChkBox__c'
                           +' FROM FundTransaction__c' 
                           +' WHERE RecordType.DeveloperName = \'WithdrawalSlip\' and TypeDetail__c = \'3.1. 決定事業\' AND Status__c = \'Reservation\' AND FurikaeInFund__c = False AND LinkCategory__c = \'四半期報告\' AND FundFiscalYearId__r.FundId__r.Status__c NOT IN (\'終了\', \'ドラフト\')' 
                           +' AND SlipCreatedDate__c >= ' + SummaryTermsFromQ2String + 'and SlipCreatedDate__c <=' + SummaryTermsToQ2String 
                           +' ORDER BY Date__c ASC, Name ASC';
            
            List<FundTransaction__c> DecisionBusinessQ2 = database.query(query10);

            //決定事業　Q3
            String query11 = 'SELECT Id, Name, Status__c, Amount__c, Amount1__c, Amount2__c, FundFiscalYearId__c, ChkBox__c'
                           +' FROM FundTransaction__c' 
                           +' WHERE RecordType.DeveloperName = \'WithdrawalSlip\' and TypeDetail__c = \'3.1. 決定事業\' AND Status__c = \'Reservation\' AND FurikaeInFund__c = False AND LinkCategory__c = \'四半期報告\' AND FundFiscalYearId__r.FundId__r.Status__c NOT IN (\'終了\', \'ドラフト\')' 
                           +' AND SlipCreatedDate__c >= ' + SummaryTermsFromQ3String + 'and SlipCreatedDate__c <=' + SummaryTermsToQ3String 
                           +' ORDER BY Date__c ASC, Name ASC';
                
            List<FundTransaction__c> DecisionBusinessQ3 = database.query(query11);

            //決定事業　Q4
            String query12 = 'SELECT Id, Name, Status__c, Amount__c, Amount1__c, Amount2__c, FundFiscalYearId__c, ChkBox__c'
                           +' FROM FundTransaction__c' 
                           +' WHERE RecordType.DeveloperName = \'WithdrawalSlip\' and TypeDetail__c = \'3.1. 決定事業\' AND Status__c = \'Reservation\' AND FurikaeInFund__c = False AND LinkCategory__c = \'四半期報告\' AND FundFiscalYearId__r.FundId__r.Status__c NOT IN (\'終了\', \'ドラフト\')' 
                           +' AND SlipCreatedDate__c >= ' + SummaryTermsFromQ4String + 'and SlipCreatedDate__c <=' + SummaryTermsToQ4String 
                           +' ORDER BY Date__c ASC, Name ASC';
                
            List<FundTransaction__c> DecisionBusinessQ4 = database.query(query12);
                        
            //既決定事業
            String query13 = 'SELECT Id, Name, Status__c, Amount__c, Amount1__c, Amount2__c, FundFiscalYearId__c, ChkBox__c'
                           +' FROM FundTransaction__c' 
                           +' WHERE RecordType.DeveloperName = \'WithdrawalSlip\' and TypeDetail__c = \'3.3. 既決定事業\' AND Status__c = \'Reservation\' AND FurikaeInFund__c = False AND LinkCategory__c = \'四半期報告\' AND FundFiscalYearId__r.FundId__r.Status__c NOT IN (\'終了\', \'ドラフト\')' 
                           +' AND SlipCreatedDate__c >= ' + SummaryTermsFromString + 'and SlipCreatedDate__c <=' + SummaryTermsToString 
                           +' ORDER BY Date__c ASC, Name ASC';
                
            List<FundTransaction__c> AlreadyDecidedBusiness = database.query(query13);
                        
            //振替出金
            String query14 = 'SELECT Id, Name, Status__c, Amount__c, Amount1__c, Amount2__c, FundFiscalYearId__c, ChkBox__c'
                           +' FROM FundTransaction__c' 
                           +' WHERE RecordType.DeveloperName = \'WithdrawalSlip\' and TypeDetail__c = \'3.6. 振替出金\' AND Status__c = \'Processed\' AND FurikaeInFund__c = False AND FundFiscalYearId__r.FundId__r.Status__c NOT IN (\'終了\', \'ドラフト\')' 
                           +' AND SlipCreatedDate__c >= ' + SummaryTermsFromString + 'and SlipCreatedDate__c <=' + SummaryTermsToString 
                           +' ORDER BY Date__c ASC, Name ASC';
                
            List<FundTransaction__c> TransferWithdrawal = database.query(query14);
            
            
            //事業外各種手数料支払い
            String query15 = 'SELECT Id, Name, Status__c, Amount__c, Amount1__c, Amount2__c, FundFiscalYearId__c, ChkBox__c'
                           +' FROM FundTransaction__c' 
                           +' WHERE RecordType.DeveloperName = \'WithdrawalSlip\' and TypeDetail__c = \'3.4. 事業外各種手数料支払い\' AND Status__c = \'Reservation\' AND FurikaeInFund__c = False AND LinkCategory__c IN (\'四半期報告\', \'手数料見込\') AND FundFiscalYearId__r.FundId__r.Status__c NOT IN (\'終了\', \'ドラフト\')' 
                           +' AND SlipCreatedDate__c >= ' + SummaryTermsFromString + 'and SlipCreatedDate__c <=' + SummaryTermsToString ;
            
            List<FundTransaction__c> PaymentOfVariousNonBusinessFees = database.query(query15);      
            
            
            //雑支出
            String query16 = 'SELECT Id, Name, Status__c, Amount__c, Amount1__c, Amount2__c, FundFiscalYearId__c, ChkBox__c'
                           +' FROM FundTransaction__c' 
                        // mod start 25/9/9 Akiyama
                        //    +' WHERE RecordType.DeveloperName = \'WithdrawalSlip\' and TypeDetail__c = \'3.7. 雑支出\' AND Status__c = \'Processed\' AND FurikaeInFund__c = False AND FundFiscalYearId__r.FundId__r.Status__c NOT IN (\'終了\', \'ドラフト\')' 
                           +' WHERE RecordType.DeveloperName = \'WithdrawalSlip\' and TypeDetail__c = \'3.7. 雑支出\' AND Status__c IN (\'Processed\', \'Reservation\') AND FurikaeInFund__c = False AND FundFiscalYearId__r.FundId__r.Status__c NOT IN (\'終了\', \'ドラフト\')' 
                        // mod end 25/9/9
                           +' AND SlipCreatedDate__c >= ' + SummaryTermsFromString + 'and SlipCreatedDate__c <=' + SummaryTermsToString 
                           +' ORDER BY Date__c ASC, Name ASC';
                
            List<FundTransaction__c> MiscellaneousExpenses = database.query(query16);
            
            
            //次年度繰越額
            String query17 = 'SELECT Id, Name, Status__c, Amount__c, Amount1__c, Amount2__c, FundFiscalYearId__c, ChkBox__c'
                           +' FROM FundTransaction__c' 
                           +' WHERE RecordType.DeveloperName = \'CarriedOverToNextFiscalYear\' and TypeDetail__c = \'4. 次年度繰越額\' AND Status__c = \'Processed\' AND FurikaeInFund__c = False' 
                           +' AND SlipCreatedDate__c >= ' + SummaryTermsFromString + 'and SlipCreatedDate__c <=' + SummaryTermsToString ;
            
            List<FundTransaction__c> AmountCarryForwardNextYear = database.query(query17);

            //決定前事業
            String query18 = 'SELECT Id, Name, Status__c, Amount__c, Amount1__c, Amount2__c, FundFiscalYearId__c, ChkBox__c'
                           +' FROM FundTransaction__c' 
                           +' WHERE TypeDetail__c = \'3.2. 決定前事業\' AND Status__c = \'Reservation\' AND LinkCategory__c = null AND FurikaeInFund__c = False AND FundFiscalYearId__r.FundId__r.Status__c NOT IN (\'終了\', \'ドラフト\')'
                        // add start 25/9/11 Akiyama 稟議IDがnullでないことをWHERE条件に追加
                           +' AND InternalMemoId__c != null AND InternalMemoId__c != \'\''
                        // add end 25/9/11
                           +' AND SlipCreatedDate__c >= ' + SummaryTermsFromString + ' AND SlipCreatedDate__c <= ' + SummaryTermsToString;
                
            List<FundTransaction__c> BeforeDecisionBusiness = database.query(query18);
                        
            //更新用年度の項目初期化
            FiscalYear__c updateFiscalYear = new FiscalYear__c();
            updateFiscalYear.Id = params[0].recordId;
            updateFiscalYear.SummaryDate__c = date.today();
            updateFiscalYear.SummaryTermFrom__c = SummaryTermsFrom;
            updateFiscalYear.SummaryTermTo__c = SummaryTermsTo;
            updateFiscalYear.AmountCarryForwardLastYear__c = 0;
            updateFiscalYear.TotalCarriedOverFrom1__c = 0;
            updateFiscalYear.TotalCarriedOverFrom2__c = 0;
            updateFiscalYear.DonationIncomeQ1_1__c = 0;
            updateFiscalYear.DonationIncomeQ1_2__c = 0;
            updateFiscalYear.DonationIncomeQ2_1__c = 0;
            updateFiscalYear.DonationIncomeQ2_2__c = 0;
            updateFiscalYear.DonationIncomeQ3_1__c = 0;
            updateFiscalYear.DonationIncomeQ3_2__c = 0;
            updateFiscalYear.DonationIncomeQ4_1__c = 0;
            updateFiscalYear.DonationIncomeQ4_2__c = 0;
            updateFiscalYear.Refund_1__c = 0;
            updateFiscalYear.Refund_2__c = 0;
            updateFiscalYear.TransferDeposit1__c = 0;
            updateFiscalYear.TransferDeposit2__c = 0;
            updateFiscalYear.MiscellaneousIncome1__c = 0;
            updateFiscalYear.MiscellaneousIncome2__c = 0;
            updateFiscalYear.DecisionBusinessQ1_1__c = 0;
            updateFiscalYear.DecisionBusinessQ1_2__c = 0;
            updateFiscalYear.DecisionBusinessQ2_1__c = 0;
            updateFiscalYear.DecisionBusinessQ2_2__c = 0;
            updateFiscalYear.DecisionBusinessQ3_1__c = 0;
            updateFiscalYear.DecisionBusinessQ3_2__c = 0;
            updateFiscalYear.DecisionBusinessQ4_1__c = 0;
            updateFiscalYear.DecisionBusinessQ4_2__c = 0;
            updateFiscalYear.BeforeDecisionBusiness1__c = 0;
            updateFiscalYear.BeforeDecisionBusiness2__c = 0;
            updateFiscalYear.AlreadyDecidedBusiness1__c = 0;
            updateFiscalYear.AlreadyDecidedBusiness2__c = 0;
            updateFiscalYear.TransferWithdrawal1__c = 0;
            updateFiscalYear.TransferWithdrawal2__c = 0;
            updateFiscalYear.PaymentOfVariousNonBusinessFees1__c = 0;
            updateFiscalYear.PaymentOfVariousNonBusinessFees2__c = 0;
            updateFiscalYear.MiscellaneousExpenses1__c = 0;
            updateFiscalYear.MiscellaneousExpenses2__c = 0;
            updateFiscalYear.AmountCarryForwardNextYear__c = 0;
            
            //基金一覧の項目初期化
            List<FundFiscalYear__c> tempList = new List<FundFiscalYear__c>();
            Map<Id, FundFiscalYear__c> fundFiscalYearMap = new Map<Id, FundFiscalYear__c>();

            for(FundFiscalYear__c ffylRec : fundFiscalYearList){
                ffylRec.SummaryDate__c = date.today();
                ffylRec.SummaryTermFrom__c = SummaryTermsFrom;                
                ffylRec.SummaryTermTo__c = SummaryTermsTo;
                ffylRec.AmountCarryForwardLastYear__c = 0;
                ffylRec.DonationIncomeQ1_1__c = 0;
                ffylRec.DonationIncomeQ1_2__c = 0;
                ffylRec.DonationIncomeQ2_1__c = 0;
                ffylRec.DonationIncomeQ2_2__c = 0;
                ffylRec.DonationIncomeQ3_1__c = 0;
                ffylRec.DonationIncomeQ3_2__c = 0;
                ffylRec.DonationIncomeQ4_1__c = 0;
                ffylRec.DonationIncomeQ4_2__c = 0;
                ffylRec.Refund_1__c = 0;
                ffylRec.Refund_2__c = 0;
                ffylRec.TransferDeposit1__c = 0;
                ffylRec.TransferDeposit2__c = 0;
                ffylRec.MiscellaneousIncome1__c = 0;
                ffylRec.MiscellaneousIncome2__c = 0;
                ffylRec.DecisionBusinessQ1_1__c = 0;
                ffylRec.DecisionBusinessQ1_2__c = 0;
                ffylRec.DecisionBusinessQ2_1__c = 0;
                ffylRec.DecisionBusinessQ2_2__c = 0;
                ffylRec.DecisionBusinessQ3_1__c = 0;
                ffylRec.DecisionBusinessQ3_2__c = 0;
                ffylRec.DecisionBusinessQ4_1__c = 0;
                ffylRec.DecisionBusinessQ4_2__c = 0;
                ffylRec.BeforeDecisionBusiness1__c = 0;
                ffylRec.BeforeDecisionBusiness2__c = 0;
                ffylRec.AlreadyDecidedBusiness1__c = 0;
                ffylRec.AlreadyDecidedBusiness2__c = 0;
                ffylRec.TransferWithdrawal1__c = 0;
                ffylRec.TransferWithdrawal2__c = 0;
                ffylRec.PaymentOfVariousNonBusinessFees1__c = 0;
                ffylRec.PaymentOfVariousNonBusinessFees2__c = 0;
                ffylRec.MiscellaneousExpenses1__c = 0;
                ffylRec.MiscellaneousExpenses2__c = 0;
                ffylRec.AmountCarryForwardNextYear__c = 0;
                fundFiscalYearMap.put(ffylRec.Id, ffylRec);
            }
            
            //更新用基金入出金リスト
            List<FundTransaction__c> updateFundTransaction = new List<FundTransaction__c>();
            
            Integer count = 0;
            
            FundFiscalYear__c temp = new FundFiscalYear__c(); 
            
            //前年度繰越額
            if(!AmountCarryForwardLastYear.isEmpty()){
                for(FundTransaction__c ft : AmountCarryForwardLastYear){
                    updateFiscalYear.AmountCarryForwardLastYear__c += ft.Amount1__c;
                    updateFiscalYear.AmountCarryForwardLastYear__c += ft.Amount2__c;
                    updateFiscalYear.TotalCarriedOverFrom1__c += ft.Amount1__c;
                    updateFiscalYear.TotalCarriedOverFrom2__c += ft.Amount2__c;                    
                    
                    if(fundFiscalYearMap.containsKey(ft.FundFiscalYearId__c)){
                        temp = fundFiscalYearMap.get(ft.FundFiscalYearId__c);
                        temp.AmountCarryForwardLastYear__c += ft.Amount1__c;
                        temp.AmountCarryForwardLastYear__c += ft.Amount2__c;
                        fundFiscalYearMap.put(ft.FundFiscalYearId__c, temp);
                    }
                    
                    if(ft.ChkBox__c = true){
                        ft.ChkBox__c = false;
                        updateFundTransaction.add(ft);
                    }
                }
            }
            //寄付金収入額　Q1
            if(!DonationIncomeQ1.isEmpty()){
                for(FundTransaction__c ft : DonationIncomeQ1){
                    updateFiscalYear.DonationIncomeQ1_1__c += ft.Amount1__c;
                    updateFiscalYear.DonationIncomeQ1_2__c += ft.Amount2__c;

                    if(fundFiscalYearMap.containsKey(ft.FundFiscalYearId__c)){
                        temp = fundFiscalYearMap.get(ft.FundFiscalYearId__c);
                        temp.DonationIncomeQ1_1__c += ft.Amount1__c;
                        temp.DonationIncomeQ1_2__c += ft.Amount2__c;
                        fundFiscalYearMap.put(ft.FundFiscalYearId__c, temp);
                    }

                    if(ft.ChkBox__c = true){
                        ft.ChkBox__c = false;
                        updateFundTransaction.add(ft);
                    }                    
                }                
            }
            //寄付金収入額　Q2
            if(!DonationIncomeQ2.isEmpty() && params[0].terms >= 6){
                for(FundTransaction__c ft : DonationIncomeQ2){
                    updateFiscalYear.DonationIncomeQ2_1__c += ft.Amount1__c;
                    updateFiscalYear.DonationIncomeQ2_2__c += ft.Amount2__c;

                    if(fundFiscalYearMap.containsKey(ft.FundFiscalYearId__c)){
                        temp = fundFiscalYearMap.get(ft.FundFiscalYearId__c);
                        temp.DonationIncomeQ2_1__c += ft.Amount1__c;
                        temp.DonationIncomeQ2_2__c += ft.Amount2__c;
                        fundFiscalYearMap.put(ft.FundFiscalYearId__c, temp);
                    }

                    if(ft.ChkBox__c = true){
                        ft.ChkBox__c = false;
                        updateFundTransaction.add(ft);
                    }
                }                 
            }
            //寄付金収入額　Q3
            if(!DonationIncomeQ3.isEmpty() && params[0].terms >= 9){
                for(FundTransaction__c ft : DonationIncomeQ3){
                    updateFiscalYear.DonationIncomeQ3_1__c += ft.Amount1__c;
                    updateFiscalYear.DonationIncomeQ3_2__c += ft.Amount2__c;

                    if(fundFiscalYearMap.containsKey(ft.FundFiscalYearId__c)){
                        temp = fundFiscalYearMap.get(ft.FundFiscalYearId__c);
                        temp.DonationIncomeQ3_1__c += ft.Amount1__c;
                        temp.DonationIncomeQ3_2__c += ft.Amount2__c;
                        fundFiscalYearMap.put(ft.FundFiscalYearId__c, temp);
                    }

                    if(ft.ChkBox__c = true){
                        ft.ChkBox__c = false;
                        updateFundTransaction.add(ft);
                    }
                }                  
            }
            //寄付金収入額　Q4
            if(!DonationIncomeQ4.isEmpty() && params[0].terms == 12){
                for(FundTransaction__c ft : DonationIncomeQ4){
                    updateFiscalYear.DonationIncomeQ4_1__c += ft.Amount1__c;
                    updateFiscalYear.DonationIncomeQ4_2__c += ft.Amount2__c;

                    if(fundFiscalYearMap.containsKey(ft.FundFiscalYearId__c)){
                        temp = fundFiscalYearMap.get(ft.FundFiscalYearId__c);
                        temp.DonationIncomeQ4_1__c += ft.Amount1__c;
                        temp.DonationIncomeQ4_2__c += ft.Amount2__c;
                        fundFiscalYearMap.put(ft.FundFiscalYearId__c, temp);
                    }

                    if(ft.ChkBox__c = true){
                        ft.ChkBox__c = false;
                        updateFundTransaction.add(ft);
                    }
                }                  
            }
            //返還金
            count = 0;
            if(!Refund.isEmpty()){
                for(FundTransaction__c ft : Refund){
                    updateFiscalYear.Refund_1__c += ft.Amount1__c;
                    updateFiscalYear.Refund_2__c += ft.Amount2__c;

                    if(fundFiscalYearMap.containsKey(ft.FundFiscalYearId__c)){
                        temp = fundFiscalYearMap.get(ft.FundFiscalYearId__c);
                        temp.Refund_1__c += ft.Amount1__c;
                        temp.Refund_2__c += ft.Amount2__c;
                        fundFiscalYearMap.put(ft.FundFiscalYearId__c, temp);
                    }

                    count++;                    
                    if(count == Refund.size() && ft.ChkBox__c == false){
                        ft.ChkBox__c = true;
                        updateFundTransaction.add(ft);
                    }
                    else if (ft.ChkBox__c == true){
                        ft.ChkBox__c = false;                                               
                        updateFundTransaction.add(ft);
                    } 
                }                               
            }
            //振替入金
            count = 0;
            if(!TransferDeposit.isEmpty()){
                for(FundTransaction__c ft : TransferDeposit){
                    updateFiscalYear.TransferDeposit1__c += ft.Amount1__c;
                    updateFiscalYear.TransferDeposit2__c += ft.Amount2__c;

                    if(fundFiscalYearMap.containsKey(ft.FundFiscalYearId__c)){
                        temp = fundFiscalYearMap.get(ft.FundFiscalYearId__c);
                        temp.TransferDeposit1__c += ft.Amount1__c;
                        temp.TransferDeposit2__c += ft.Amount2__c;
                        fundFiscalYearMap.put(ft.FundFiscalYearId__c, temp);
                    }
                    
                    count++;                    
                    system.debug('###振替入金：' + count);
                    system.debug('###TransferDeposit.size()：' + TransferDeposit.size() + ',' + ft.ChkBox__c);                    
                    if(count == TransferDeposit.size() && ft.ChkBox__c == false){
                        ft.ChkBox__c = true;
                        updateFundTransaction.add(ft);
                        system.debug('###振替入金：ft.ChkBox__c = true');
                    }
                    else if (ft.ChkBox__c == true){
                        ft.ChkBox__c = false;                                               
                        updateFundTransaction.add(ft);
                        system.debug('###振替入金：ft.ChkBox__c = false');
                    } 
                }                  
            }
            //雑収入
            count = 0;
            if(!MiscellaneousIncome.isEmpty()){
                for(FundTransaction__c ft : MiscellaneousIncome){
                    updateFiscalYear.MiscellaneousIncome1__c += ft.Amount1__c;
                    updateFiscalYear.MiscellaneousIncome2__c += ft.Amount2__c;

                    if(fundFiscalYearMap.containsKey(ft.FundFiscalYearId__c)){
                        temp = fundFiscalYearMap.get(ft.FundFiscalYearId__c);
                        temp.MiscellaneousIncome1__c += ft.Amount1__c;
                        temp.MiscellaneousIncome2__c += ft.Amount2__c;
                        fundFiscalYearMap.put(ft.FundFiscalYearId__c, temp);
                    }

                    count++;                    
                    if(count == MiscellaneousIncome.size() && ft.ChkBox__c == false){
                        ft.ChkBox__c = true;
                        updateFundTransaction.add(ft);
                    }
                    else if (ft.ChkBox__c == true){
                        ft.ChkBox__c = false;                                               
                        updateFundTransaction.add(ft);
                    } 
                }                 
            }
            //決定事業　Q1
            count = 0;
            if(!DecisionBusinessQ1.isEmpty()){
                for(FundTransaction__c ft : DecisionBusinessQ1){
                    updateFiscalYear.DecisionBusinessQ1_1__c += ft.Amount1__c;
                    updateFiscalYear.DecisionBusinessQ1_2__c += ft.Amount2__c;
                    
                    if(fundFiscalYearMap.containsKey(ft.FundFiscalYearId__c)){
                        temp = fundFiscalYearMap.get(ft.FundFiscalYearId__c);
                        temp.DecisionBusinessQ1_1__c += ft.Amount1__c;
                        temp.DecisionBusinessQ1_2__c += ft.Amount2__c;
                        fundFiscalYearMap.put(ft.FundFiscalYearId__c, temp);
                    }
    
                    count++;                    
                    if(count == DecisionBusinessQ1.size() && ft.ChkBox__c == false){
                        ft.ChkBox__c = false;
                        updateFundTransaction.add(ft);
                    }
                    else if (ft.ChkBox__c == true){
                        ft.ChkBox__c = false;                                               
                        updateFundTransaction.add(ft);
                    } 
                }                  
            }
            //決定事業　Q2
            count = 0;
            if(!DecisionBusinessQ2.isEmpty() && params[0].terms >= 6){
                for(FundTransaction__c ft : DecisionBusinessQ2){
                    updateFiscalYear.DecisionBusinessQ2_1__c += ft.Amount1__c;
                    updateFiscalYear.DecisionBusinessQ2_2__c += ft.Amount2__c;
                    
                    if(fundFiscalYearMap.containsKey(ft.FundFiscalYearId__c)){
                        temp = fundFiscalYearMap.get(ft.FundFiscalYearId__c);
                        temp.DecisionBusinessQ2_1__c += ft.Amount1__c;
                        temp.DecisionBusinessQ2_2__c += ft.Amount2__c;
                        fundFiscalYearMap.put(ft.FundFiscalYearId__c, temp);
                    }

                    count++;                    
                    if(count == DecisionBusinessQ2.size() && ft.ChkBox__c == false){
                        ft.ChkBox__c = false;
                        updateFundTransaction.add(ft);
                    }
                    else if (ft.ChkBox__c == true){
                        ft.ChkBox__c = false;                                               
                        updateFundTransaction.add(ft);
                    } 
                }                  
            }
            //決定事業　Q3
            count = 0;
            if(!DecisionBusinessQ3.isEmpty() && params[0].terms >= 9){
                for(FundTransaction__c ft : DecisionBusinessQ3){
                    updateFiscalYear.DecisionBusinessQ3_1__c += ft.Amount1__c;
                    updateFiscalYear.DecisionBusinessQ3_2__c += ft.Amount2__c;
                    
                    if(fundFiscalYearMap.containsKey(ft.FundFiscalYearId__c)){
                        temp = fundFiscalYearMap.get(ft.FundFiscalYearId__c);
                        temp.DecisionBusinessQ3_1__c += ft.Amount1__c;
                        temp.DecisionBusinessQ3_2__c += ft.Amount2__c;
                        fundFiscalYearMap.put(ft.FundFiscalYearId__c, temp);
                    }

                    count++;                    
                    if(count == DecisionBusinessQ3.size() && ft.ChkBox__c == false){
                        ft.ChkBox__c = false;
                        updateFundTransaction.add(ft);
                    }
                    else if (ft.ChkBox__c == true){
                        ft.ChkBox__c = false;                                               
                        updateFundTransaction.add(ft);
                    } 
                }                  
            }
            //決定事業　Q4
            count = 0;
            if(!DecisionBusinessQ4.isEmpty() && params[0].terms == 12){
                for(FundTransaction__c ft : DecisionBusinessQ4){
                    updateFiscalYear.DecisionBusinessQ4_1__c += ft.Amount1__c;
                    updateFiscalYear.DecisionBusinessQ4_2__c += ft.Amount2__c;
                    
                    if(fundFiscalYearMap.containsKey(ft.FundFiscalYearId__c)){
                        temp = fundFiscalYearMap.get(ft.FundFiscalYearId__c);
                        temp.DecisionBusinessQ4_1__c += ft.Amount1__c;
                        temp.DecisionBusinessQ4_2__c += ft.Amount2__c;
                        fundFiscalYearMap.put(ft.FundFiscalYearId__c, temp);
                    }

                    count++;                    
                    if(count == DecisionBusinessQ4.size() && ft.ChkBox__c == false){
                        ft.ChkBox__c = false;
                        updateFundTransaction.add(ft);
                    }
                    else if (ft.ChkBox__c == true){
                        ft.ChkBox__c = false;                                               
                        updateFundTransaction.add(ft);
                    } 
                }                  
            }
            //決定前事業
            if(!BeforeDecisionBusiness.isEmpty()){
                for(FundTransaction__c ft : BeforeDecisionBusiness){
                    updateFiscalYear.BeforeDecisionBusiness1__c += ft.Amount1__c;
                    updateFiscalYear.BeforeDecisionBusiness2__c += ft.Amount2__c;
                    
                    if(fundFiscalYearMap.containsKey(ft.FundFiscalYearId__c)){
                        temp = fundFiscalYearMap.get(ft.FundFiscalYearId__c);
                        temp.BeforeDecisionBusiness1__c += ft.Amount1__c;
                        temp.BeforeDecisionBusiness2__c += ft.Amount2__c;
                        fundFiscalYearMap.put(ft.FundFiscalYearId__c, temp);
                    }

                    if(ft.ChkBox__c = true){
                        ft.ChkBox__c = false;
                        updateFundTransaction.add(ft);
                    }
                }                 
            }
            //既決定事業
            count = 0;
            if(!AlreadyDecidedBusiness.isEmpty()){
                for(FundTransaction__c ft : AlreadyDecidedBusiness){
                    updateFiscalYear.AlreadyDecidedBusiness1__c += ft.Amount1__c;
                    updateFiscalYear.AlreadyDecidedBusiness2__c += ft.Amount2__c;

                    if(fundFiscalYearMap.containsKey(ft.FundFiscalYearId__c)){
                        temp = fundFiscalYearMap.get(ft.FundFiscalYearId__c);
                        temp.AlreadyDecidedBusiness1__c += ft.Amount1__c;
                        temp.AlreadyDecidedBusiness2__c += ft.Amount2__c;
                        fundFiscalYearMap.put(ft.FundFiscalYearId__c, temp);
                    }

                    count++;                    
                    if(count == AlreadyDecidedBusiness.size() && ft.ChkBox__c == false){
                        ft.ChkBox__c = false;
                        updateFundTransaction.add(ft);
                    }
                    else if (ft.ChkBox__c == true){
                        ft.ChkBox__c = false;                                               
                        updateFundTransaction.add(ft);
                    } 
                }                   
            }
            //振替出金
            count = 0;
            if(!TransferWithdrawal.isEmpty()){
                for(FundTransaction__c ft : TransferWithdrawal){
                    updateFiscalYear.TransferWithdrawal1__c += ft.Amount1__c;
                    updateFiscalYear.TransferWithdrawal2__c += ft.Amount2__c;

                    if(fundFiscalYearMap.containsKey(ft.FundFiscalYearId__c)){
                        temp = fundFiscalYearMap.get(ft.FundFiscalYearId__c);
                        temp.TransferWithdrawal1__c += ft.Amount1__c;
                        temp.TransferWithdrawal2__c += ft.Amount2__c;
                        fundFiscalYearMap.put(ft.FundFiscalYearId__c, temp);
                    }

                    count++;                    
                    if(count == TransferWithdrawal.size() && ft.ChkBox__c == false){
                        ft.ChkBox__c = false;
                        updateFundTransaction.add(ft);
                    }
                    else if (ft.ChkBox__c == true){
                        ft.ChkBox__c = false;                                               
                        updateFundTransaction.add(ft);
                    } 
                }                 
            }
            //事業外各種手数料支払い
            if(!PaymentOfVariousNonBusinessFees.isEmpty()){
                for(FundTransaction__c ft : PaymentOfVariousNonBusinessFees){
                    updateFiscalYear.PaymentOfVariousNonBusinessFees1__c += ft.Amount1__c;
                    updateFiscalYear.PaymentOfVariousNonBusinessFees2__c += ft.Amount2__c;

                    if(fundFiscalYearMap.containsKey(ft.FundFiscalYearId__c)){
                        temp = fundFiscalYearMap.get(ft.FundFiscalYearId__c);
                        temp.PaymentOfVariousNonBusinessFees1__c += ft.Amount1__c;
                        temp.PaymentOfVariousNonBusinessFees2__c += ft.Amount2__c;
                        fundFiscalYearMap.put(ft.FundFiscalYearId__c, temp);
                    }

                    if(ft.ChkBox__c = true){
                        ft.ChkBox__c = false;
                        updateFundTransaction.add(ft);
                    }
                }                 
            }
            //雑支出
            count = 0;
            if(!MiscellaneousExpenses.isEmpty()){
                for(FundTransaction__c ft : MiscellaneousExpenses){
                    updateFiscalYear.MiscellaneousExpenses1__c += ft.Amount1__c;
                    updateFiscalYear.MiscellaneousExpenses2__c += ft.Amount2__c;

                    if(fundFiscalYearMap.containsKey(ft.FundFiscalYearId__c)){
                        temp = fundFiscalYearMap.get(ft.FundFiscalYearId__c);
                        temp.MiscellaneousExpenses1__c += ft.Amount1__c;
                        temp.MiscellaneousExpenses2__c += ft.Amount2__c;
                        fundFiscalYearMap.put(ft.FundFiscalYearId__c, temp);
                    }

                    count++;                    
                    if(count == MiscellaneousExpenses.size() && ft.ChkBox__c == false){
                        ft.ChkBox__c = false;
                        updateFundTransaction.add(ft);
                    }
                    else if (ft.ChkBox__c == true){
                        ft.ChkBox__c = false;                                               
                        updateFundTransaction.add(ft);
                    } 
                }                 
            }
            //次年度繰越額
            if(!AmountCarryForwardNextYear.isEmpty()){
                for(FundTransaction__c ft : AmountCarryForwardNextYear){
                    updateFiscalYear.AmountCarryForwardNextYear__c += ft.Amount1__c;
                    updateFiscalYear.AmountCarryForwardNextYear__c += ft.Amount2__c;

                    if(fundFiscalYearMap.containsKey(ft.FundFiscalYearId__c)){
                        temp = fundFiscalYearMap.get(ft.FundFiscalYearId__c);
                        temp.AmountCarryForwardNextYear__c += ft.Amount1__c;
                        temp.AmountCarryForwardNextYear__c += ft.Amount2__c;
                        fundFiscalYearMap.put(ft.FundFiscalYearId__c, temp);
                    }

                    if(ft.ChkBox__c = true){
                        ft.ChkBox__c = false;
                        updateFundTransaction.add(ft);
                    }
                }                 
            }
            update updateFiscalYear;
            update fundFiscalYearMap.values();
            
            // del start 25/10/2 Akiyama 基金入出金のUpdateをコメントアウト
            // if(updateFundTransaction.size() > 0){
            //     update updateFundTransaction;                
            // }
            // del end 25/10/2
            
            return new List<String>{'集計処理が正常に終了しました。'};
        } catch (Exception e) {
            return new List<String>{'集計処理が失敗しました: ' + e.getMessage()};
        }
    }
}