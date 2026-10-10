/**
 * @description Trigger on Expense_Item__c to enforce 24h compliance, receipt verification,
 *              discrepancy checking, and automatic sync of parent report totals and budget recorded expenses.
 */
trigger ExpenseItemTrigger on Expense_Item__c (before insert, before update, after insert, after update, after delete) {

    if (Trigger.isBefore && (Trigger.isInsert || Trigger.isUpdate)) {
        ReceiptComplianceService.computeDeadlinesAndCompliance(Trigger.new);
        ReceiptVerificationService.verifyExpenseItems(Trigger.new);
    }

    if (Trigger.isAfter) {
        Set<Id> reportIds = new Set<Id>();
        Set<Id> budgetIds = new Set<Id>();

        if (Trigger.isInsert || Trigger.isUpdate) {
            for (Expense_Item__c itm : Trigger.new) {
                if (itm.Expense_Report__c != null) {
                    reportIds.add(itm.Expense_Report__c);
                }
            }
        }
        if (Trigger.isDelete) {
            for (Expense_Item__c itm : Trigger.old) {
                if (itm.Expense_Report__c != null) {
                    reportIds.add(itm.Expense_Report__c);
                }
            }
        }

        if (!reportIds.isEmpty()) {
            for (Expense_Report__c rep : [
                SELECT Id, Travel_Request__r.Budget__c
                FROM Expense_Report__c
                WHERE Id IN :reportIds
            ]) {
                if (rep.Travel_Request__r.Budget__c != null) {
                    budgetIds.add(rep.Travel_Request__r.Budget__c);
                }
            }
            if (!budgetIds.isEmpty()) {
                TravelBudgetForecastService.recalculateBudgets(budgetIds);
            }
        }
    }
}
