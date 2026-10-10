/**
 * @description Service to manage receipt upload compliance, calculate deadlines (24h rule),
 *              and monitor On-Time vs Overdue vs Missing receipt submissions.
 */
public with sharing class ReceiptComplianceService {

    /**
     * @description Calculates and populates receipt submission deadlines and compliance status on expense items
     */
    public static void computeDeadlinesAndCompliance(List<Expense_Item__c> items) {
        Map<String, Expense_Policy__mdt> policies = TravelPolicyService.getPoliciesByCategory();

        for (Expense_Item__c item : items) {
            String cat = String.isNotBlank(item.Expense_Category__c) ? item.Expense_Category__c.toLowerCase() : '';
            Expense_Policy__mdt policy = policies.get(cat);

            Decimal deadlineHours = 24;
            Boolean requiresReceipt = true;
            if (policy != null) {
                if (policy.Receipt_Deadline_Hours__c != null && policy.Receipt_Deadline_Hours__c > 0) {
                    deadlineHours = policy.Receipt_Deadline_Hours__c;
                }
                if (policy.Requires_Receipt__c != null) {
                    requiresReceipt = policy.Requires_Receipt__c;
                }
            }

            if (!requiresReceipt) {
                item.Receipt_Compliance_Status__c = 'Not Required';
                continue;
            }

            // Set deadline based on expense date + deadlineHours
            if (item.Expense_Date__c != null && item.Receipt_Deadline__c == null) {
                DateTime expDateTime = DateTime.newInstance(item.Expense_Date__c, Time.newInstance(23, 59, 59, 0));
                item.Receipt_Deadline__c = expDateTime.addHours(Integer.valueOf(deadlineHours));
            }

            // Evaluate compliance status
            if (item.Receipt_Submission_Time__c != null) {
                if (item.Receipt_Deadline__c != null && item.Receipt_Submission_Time__c <= item.Receipt_Deadline__c) {
                    item.Receipt_Compliance_Status__c = 'On-Time';
                } else {
                    item.Receipt_Compliance_Status__c = 'Overdue';
                }
            } else {
                if (item.Receipt_Deadline__c != null && DateTime.now() > item.Receipt_Deadline__c) {
                    item.Receipt_Compliance_Status__c = 'Overdue';
                } else {
                    item.Receipt_Compliance_Status__c = 'Missing Receipt';
                }
            }
        }
    }
}
