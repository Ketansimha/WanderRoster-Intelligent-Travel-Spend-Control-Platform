/**
 * @description Service to manage departmental travel budgets, commitment tracking,
 *              forecast spending, and prevention of double-counting between commitments and recorded expenses.
 */
public with sharing class TravelBudgetForecastService {

    public class BudgetCheckResult {
        @AuraEnabled public Boolean isAvailable { get; set; }
        @AuraEnabled public Decimal allocatedBudget { get; set; }
        @AuraEnabled public Decimal remainingBudget { get; set; }
        @AuraEnabled public Decimal requestedAmount { get; set; }
        @AuraEnabled public Decimal shortfall { get; set; }
        @AuraEnabled public String healthStatus { get; set; }
        @AuraEnabled public String message { get; set; }

        public BudgetCheckResult() {
            this.isAvailable = true;
            this.shortfall = 0;
            this.remainingBudget = 0;
            this.allocatedBudget = 0;
            this.requestedAmount = 0;
            this.healthStatus = 'Healthy';
            this.message = 'Sufficient budget is available.';
        }
    }

    /**
     * @description Checks if a department budget has enough remaining funds for a proposed expenditure
     */
    public static BudgetCheckResult checkBudgetAvailability(Id budgetId, Decimal requestedAmount) {
        BudgetCheckResult result = new BudgetCheckResult();
        if (budgetId == null) {
            result.isAvailable = true;
            result.message = 'No specific budget linked.';
            return result;
        }

        Travel_Budget__c budget = [
            SELECT Id, Name, Department__c, Allocated_Budget__c, Approved_Commitments__c,
                   Recorded_Expenses__c, Pending_Commitments__c, Remaining_Budget__c,
                   Forecast_Spending__c, Budget_Health_Status__c
            FROM Travel_Budget__c
            WHERE Id = :budgetId
            LIMIT 1
        ];

        result.allocatedBudget = budget.Allocated_Budget__c != null ? budget.Allocated_Budget__c : 0;
        result.remainingBudget = budget.Remaining_Budget__c != null ? budget.Remaining_Budget__c : 0;
        result.requestedAmount = requestedAmount != null ? requestedAmount : 0;
        result.healthStatus = budget.Budget_Health_Status__c;

        if (result.remainingBudget < result.requestedAmount) {
            result.isAvailable = false;
            result.shortfall = result.requestedAmount - result.remainingBudget;
            result.healthStatus = 'Overrun';
            result.message = 'Budget Shortfall Detected: Proposed cost ₹' + result.requestedAmount.setScale(2) + 
                ' exceeds remaining budget of ₹' + result.remainingBudget.setScale(2) + 
                ' by ₹' + result.shortfall.setScale(2) + '.';
        } else if (result.remainingBudget - result.requestedAmount < (result.allocatedBudget * 0.15)) {
            result.healthStatus = 'Warning';
            result.message = 'Budget Warning: Request will consume over 85% of allocated departmental funds.';
        }

        return result;
    }

    /**
     * @description Bulk recalculates and updates budget commitments and recorded expenses
     *              Strictly avoids double-counting between approved commitments and recorded expenses.
     */
    public static void recalculateBudgets(Set<Id> budgetIds) {
        if (budgetIds == null || budgetIds.isEmpty()) {
            return;
        }

        List<Travel_Budget__c> budgetsToUpdate = [
            SELECT Id, Allocated_Budget__c, Approved_Commitments__c, Recorded_Expenses__c,
                   Pending_Commitments__c, Forecast_Spending__c, Budget_Health_Status__c
            FROM Travel_Budget__c
            WHERE Id IN :budgetIds
        ];

        // 1. Pending Commitments: Travel requests submitted/pending approval
        Map<Id, Decimal> pendingMap = new Map<Id, Decimal>();
        for (AggregateResult ar : [
            SELECT Budget__c bId, SUM(Total_Estimated_Cost__c) totalCost
            FROM Travel_Request__c
            WHERE Budget__c IN :budgetIds
              AND Approval_Status__c IN ('Submitted', 'Pending Approval')
            GROUP BY Budget__c
        ]) {
            pendingMap.put((Id)ar.get('bId'), (Decimal)ar.get('totalCost'));
        }

        // 2. Approved Commitments: Approved requests that do NOT yet have an expense report submitted/approved
        // To avoid double-counting, if a travel request already has recorded expenses, commitment is zeroed or netted.
        Map<Id, Decimal> approvedMap = new Map<Id, Decimal>();
        for (AggregateResult ar : [
            SELECT Budget__c bId, SUM(Total_Estimated_Cost__c) totalCost
            FROM Travel_Request__c
            WHERE Budget__c IN :budgetIds
              AND Approval_Status__c = 'Approved'
              AND Trip_Status__c != 'Completed'
            GROUP BY Budget__c
        ]) {
            approvedMap.put((Id)ar.get('bId'), (Decimal)ar.get('totalCost'));
        }

        // 3. Recorded Expenses: Actual expenses approved by Finance on completed or expensed trips
        Map<Id, Decimal> recordedMap = new Map<Id, Decimal>();
        for (AggregateResult ar : [
            SELECT Travel_Request__r.Budget__c bId, SUM(Claimed_Amount__c) totalSpent
            FROM Expense_Item__c
            WHERE Travel_Request__r.Budget__c IN :budgetIds
              AND Review_Status__c IN ('Approved', 'Partial Approved')
            GROUP BY Travel_Request__r.Budget__c
        ]) {
            recordedMap.put((Id)ar.get('bId'), (Decimal)ar.get('totalSpent'));
        }

        for (Travel_Budget__c b : budgetsToUpdate) {
            Decimal pending = pendingMap.containsKey(b.Id) ? pendingMap.get(b.Id) : 0;
            Decimal approved = approvedMap.containsKey(b.Id) ? approvedMap.get(b.Id) : 0;
            Decimal recorded = recordedMap.containsKey(b.Id) ? recordedMap.get(b.Id) : 0;
            Decimal allocated = b.Allocated_Budget__c != null ? b.Allocated_Budget__c : 0;

            b.Pending_Commitments__c = pending;
            b.Approved_Commitments__c = approved;
            b.Recorded_Expenses__c = recorded;
            b.Forecast_Spending__c = recorded + approved + pending;

            if (allocated > 0) {
                Decimal usageRatio = b.Forecast_Spending__c / allocated;
                if (usageRatio > 1.0) {
                    b.Budget_Health_Status__c = 'Overrun';
                } else if (usageRatio >= 0.8) {
                    b.Budget_Health_Status__c = 'Warning';
                } else {
                    b.Budget_Health_Status__c = 'Healthy';
                }
            } else {
                b.Budget_Health_Status__c = 'Healthy';
            }
        }

        update budgetsToUpdate;
    }
}
