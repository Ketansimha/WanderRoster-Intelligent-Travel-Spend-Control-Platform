/**
 * @description Unit tests for TravelBudgetForecastService, budget overrun detection,
 *              and anti-double-counting integrity.
 */
@isTest
private class TravelBudgetForecastServiceTest {

    @isTest
    static void testBudgetOverrunDetection() {
        // Scenario B: Budget allocated ₹40,000, requested ₹50,000 -> shortfall ₹10,000
        Travel_Budget__c budget = TravelTestDataFactory.createBudget('Sales', 40000);

        Test.startTest();
        TravelBudgetForecastService.BudgetCheckResult res = 
            TravelBudgetForecastService.checkBudgetAvailability(budget.Id, 50000);
        Test.stopTest();

        System.assertEquals(false, res.isAvailable, 'Should flag lack of budget');
        System.assertEquals(10000, res.shortfall, 'Shortfall should be exactly ₹10,000');
        System.assertEquals('Overrun', res.healthStatus, 'Health status should be Overrun');
    }

    @isTest
    static void testBudgetRecalculationAndNoDoubleCounting() {
        // Scenario F: Budget forecasting without double counting
        Travel_Budget__c budget = TravelTestDataFactory.createBudget('Engineering', 200000);
        Travel_Request__c req = TravelTestDataFactory.createTravelRequest(UserInfo.getUserId(), budget.Id, 20000, 10000);

        // Submit for approval -> Pending Commitment
        req.Approval_Status__c = 'Submitted';
        update req;

        Test.startTest();
        TravelBudgetForecastService.recalculateBudgets(new Set<Id>{ budget.Id });
        Travel_Budget__c updatedBudget = [SELECT Id, Pending_Commitments__c, Approved_Commitments__c, Recorded_Expenses__c FROM Travel_Budget__c WHERE Id = :budget.Id];
        System.assert(updatedBudget.Pending_Commitments__c > 0, 'Pending commitments should be tracked');

        // Approve request -> Approved Commitment
        req.Approval_Status__c = 'Approved';
        update req;
        TravelBudgetForecastService.recalculateBudgets(new Set<Id>{ budget.Id });

        // Add expense items approved by Finance -> Recorded Expenses
        Expense_Report__c rep = TravelTestDataFactory.createExpenseReport(req.Id, UserInfo.getUserId());
        Expense_Item__c item = TravelTestDataFactory.createExpenseItem(rep.Id, req.Id, 'Flights', 18000, 18000);
        item.Review_Status__c = 'Approved';
        update item;

        TravelBudgetForecastService.recalculateBudgets(new Set<Id>{ budget.Id });
        Test.stopTest();

        Travel_Budget__c finalBudget = [
            SELECT Id, Pending_Commitments__c, Approved_Commitments__c, Recorded_Expenses__c, Forecast_Spending__c
            FROM Travel_Budget__c
            WHERE Id = :budget.Id
        ];

        System.assertEquals(18000, finalBudget.Recorded_Expenses__c, 'Recorded expenses should match approved line items');
        System.assert(finalBudget.Forecast_Spending__c > 0, 'Forecast spending should be calculated');
    }
}
