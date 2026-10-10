/**
 * @description Unit tests for ReceiptVerificationService, discrepancy detection,
 *              duplicate claim flagging, and 24-hour compliance monitoring.
 */
@isTest
private class ReceiptVerificationServiceTest {

    @isTest
    static void testReceiptAmountDiscrepancy() {
        // Scenario C: Claimed hotel expense ₹8,000, Receipt amount ₹8,800 -> flags ₹800 discrepancy
        Travel_Budget__c budget = TravelTestDataFactory.createBudget('Engineering', 200000);
        Travel_Request__c req = TravelTestDataFactory.createTravelRequest(UserInfo.getUserId(), budget.Id, 15000, 8000);
        Expense_Report__c rep = TravelTestDataFactory.createExpenseReport(req.Id, UserInfo.getUserId());

        Expense_Item__c item = new Expense_Item__c(
            Expense_Report__c = rep.Id,
            Travel_Request__c = req.Id,
            Expense_Category__c = 'Hotel',
            Merchant_Name__c = 'Novotel Bengaluru',
            Expense_Date__c = Date.today(),
            Claimed_Amount__c = 8000,
            Receipt_Amount__c = 8800,
            Receipt_Number__c = 'REC-8800-TEST',
            Receipt_Submission_Time__c = DateTime.now(),
            Review_Status__c = 'Pending Review'
        );

        Test.startTest();
        ReceiptVerificationService.verifyExpenseItems(new List<Expense_Item__c>{ item });
        Test.stopTest();

        System.assertEquals('Discrepancy Flagged', item.Receipt_Verification_Status__c, 'Should flag discrepancy');
        System.assert(item.Anomaly_Risk_Score__c >= 35, 'Risk score should reflect discrepancy');
        System.assert(item.AI_Explanation__c.contains('Discrepancy'), 'Explanation should highlight mismatch');
    }

    @isTest
    static void testSuspectedDuplicateReceipt() {
        // Scenario E: Two expense items share matching receipt identifier
        Travel_Budget__c budget = TravelTestDataFactory.createBudget('Operations', 200000);
        Travel_Request__c req = TravelTestDataFactory.createTravelRequest(UserInfo.getUserId(), budget.Id, 15000, 6000);
        Expense_Report__c rep = TravelTestDataFactory.createExpenseReport(req.Id, UserInfo.getUserId());

        // First item already exists
        Expense_Item__c item1 = TravelTestDataFactory.createExpenseItem(rep.Id, req.Id, 'Flights', 14000, 14000);
        item1.Receipt_Number__c = 'DUP-AIR-12345';
        update item1;

        // Second item has the exact same receipt number
        Expense_Item__c item2 = new Expense_Item__c(
            Expense_Report__c = rep.Id,
            Travel_Request__c = req.Id,
            Expense_Category__c = 'Flights',
            Merchant_Name__c = 'IndiGo Airlines',
            Expense_Date__c = Date.today(),
            Claimed_Amount__c = 14000,
            Receipt_Amount__c = 14000,
            Receipt_Number__c = 'DUP-AIR-12345',
            Receipt_Submission_Time__c = DateTime.now(),
            Review_Status__c = 'Pending Review'
        );

        Test.startTest();
        ReceiptVerificationService.verifyExpenseItems(new List<Expense_Item__c>{ item2 });
        Test.stopTest();

        System.assertEquals(true, item2.Duplicate_Suspected__c, 'Duplicate flag must be true');
        System.assertEquals('Duplicate Suspected', item2.Receipt_Verification_Status__c, 'Status should be Duplicate Suspected');
        System.assert(item2.Anomaly_Risk_Score__c >= 50, 'Duplicate risk score should be elevated');
    }

    @isTest
    static void testReceiptComplianceDeadlines() {
        // Scenario D: Missing / Late receipt compliance
        Travel_Budget__c budget = TravelTestDataFactory.createBudget('Finance', 200000);
        Travel_Request__c req = TravelTestDataFactory.createTravelRequest(UserInfo.getUserId(), budget.Id, 15000, 6000);
        Expense_Report__c rep = TravelTestDataFactory.createExpenseReport(req.Id, UserInfo.getUserId());

        Expense_Item__c itemMissing = new Expense_Item__c(
            Expense_Report__c = rep.Id,
            Travel_Request__c = req.Id,
            Expense_Category__c = 'Hotel',
            Merchant_Name__c = 'Lemon Tree Bengaluru',
            Expense_Date__c = Date.today().addDays(-3), // Incurred 3 days ago, no receipt attached
            Claimed_Amount__c = 5000,
            Review_Status__c = 'Pending Review'
        );

        Test.startTest();
        ReceiptComplianceService.computeDeadlinesAndCompliance(new List<Expense_Item__c>{ itemMissing });
        Test.stopTest();

        System.assertNotEquals(null, itemMissing.Receipt_Deadline__c, 'Deadline should be computed');
        System.assertEquals('Overdue', itemMissing.Receipt_Compliance_Status__c, 'Item past 24h deadline without receipt should be Overdue');
    }
}
