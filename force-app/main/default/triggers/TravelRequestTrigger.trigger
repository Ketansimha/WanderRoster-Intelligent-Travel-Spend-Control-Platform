/**
 * @description Trigger on Travel_Request__c to automatically enforce policy evaluation
 *              and update budget commitments upon approval/modification.
 */
trigger TravelRequestTrigger on Travel_Request__c (before insert, before update, after insert, after update, after delete) {

    if (Trigger.isBefore && (Trigger.isInsert || Trigger.isUpdate)) {
        TravelPolicyService.evaluateAndPopulate(Trigger.new);
    }

    if (Trigger.isAfter) {
        Set<Id> budgetIds = new Set<Id>();
        if (Trigger.isInsert || Trigger.isUpdate) {
            for (Travel_Request__c req : Trigger.new) {
                if (req.Budget__c != null) {
                    budgetIds.add(req.Budget__c);
                }
            }
        }
        if (Trigger.isDelete) {
            for (Travel_Request__c req : Trigger.old) {
                if (req.Budget__c != null) {
                    budgetIds.add(req.Budget__c);
                }
            }
        }
        if (!budgetIds.isEmpty()) {
            TravelBudgetForecastService.recalculateBudgets(budgetIds);
        }
    }
}
