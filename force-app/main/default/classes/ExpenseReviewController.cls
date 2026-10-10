/**
 * @description Controller for Finance Review Workspace, Receipt Verification, and Reimbursement Lifecycle.
 *              Allows line-level expense approvals, discrepancy audits, and file attachments.
 */
public with sharing class ExpenseReviewController {

    public class ExpenseSubmissionPayload {
        @AuraEnabled public Expense_Report__c report { get; set; }
        @AuraEnabled public List<Expense_Item__c> items { get; set; }
    }

    /**
     * @description Submits a new expense report and its line items with automated compliance and anomaly detection
     */
    @AuraEnabled
    public static Expense_Report__c submitExpenseReport(Expense_Report__c report, List<Expense_Item__c> items) {
        if (report == null || items == null || items.isEmpty()) {
            throw new AuraHandledException('Expense report and at least one expense item are required.');
        }

        if (report.Employee__c == null) {
            report.Employee__c = UserInfo.getUserId();
        }

        report.Submission_Date__c = DateTime.now();
        report.Finance_Review_Status__c = 'Submitted';
        report.Reimbursement_Status__c = 'Under Review';

        Decimal totalClaimed = 0;
        for (Expense_Item__c itm : items) {
            totalClaimed += (itm.Claimed_Amount__c != null ? itm.Claimed_Amount__c : 0);
        }
        report.Total_Claimed_Amount__c = totalClaimed;

        insert report;

        for (Expense_Item__c itm : items) {
            itm.Expense_Report__c = report.Id;
            if (itm.Travel_Request__c == null) {
                itm.Travel_Request__c = report.Travel_Request__c;
            }
            itm.Review_Status__c = 'Pending Review';
        }

        // Run automated compliance and verification engines
        ReceiptComplianceService.computeDeadlinesAndCompliance(items);
        ReceiptVerificationService.verifyExpenseItems(items);

        insert items;

        return report;
    }

    /**
     * @description Attach uploaded receipt file to an expense item and trigger re-verification
     */
    @AuraEnabled
    public static Expense_Item__c attachReceiptAndVerify(Id expenseItemId, Id contentDocumentId, Decimal extractedReceiptAmount) {
        if (expenseItemId == null) {
            throw new AuraHandledException('Expense Item ID is required.');
        }

        Expense_Item__c itm = [
            SELECT Id, Name, Expense_Category__c, Merchant_Name__c, Expense_Date__c,
                   Claimed_Amount__c, Receipt_Amount__c, Receipt_Number__c, Receipt_Deadline__c,
                   Receipt_Submission_Time__c, Receipt_Compliance_Status__c,
                   Receipt_Verification_Status__c, Anomaly_Risk_Score__c, Duplicate_Suspected__c,
                   Policy_Violation__c, AI_Explanation__c, Receipt_Attachment_Reference__c,
                   Travel_Request__c, Travel_Request__r.Budget__c
            FROM Expense_Item__c
            WHERE Id = :expenseItemId
            LIMIT 1
        ];

        if (contentDocumentId != null) {
            itm.Receipt_Attachment_Reference__c = String.valueOf(contentDocumentId);
            // Create ContentDocumentLink
            ContentDocumentLink cdl = new ContentDocumentLink();
            cdl.ContentDocumentId = contentDocumentId;
            cdl.LinkedEntityId = expenseItemId;
            cdl.ShareType = 'V';
            cdl.Visibility = 'AllUsers';
            insert cdl;
        }

        itm.Receipt_Submission_Time__c = DateTime.now();
        if (extractedReceiptAmount != null) {
            itm.Receipt_Amount__c = extractedReceiptAmount;
        }

        List<Expense_Item__c> itemsToVerify = new List<Expense_Item__c>{ itm };
        ReceiptComplianceService.computeDeadlinesAndCompliance(itemsToVerify);
        ReceiptVerificationService.verifyExpenseItems(itemsToVerify);

        update itm;
        return itm;
    }

    /**
     * @description Fetch expense reports awaiting finance review
     */
    @AuraEnabled(cacheable=true)
    public static List<Expense_Report__c> getReportsForReview() {
        return [
            SELECT Id, Name, Travel_Request__c, Travel_Request__r.Name, Travel_Request__r.Destination__c,
                   Employee__c, Employee__r.Name, Submission_Date__c, Total_Claimed_Amount__c,
                   Total_Approved_Amount__c, Total_Rejected_Amount__c, Finance_Review_Status__c,
                   Reimbursement_Status__c, Reimbursement_Date__c, Review_Comments__c
            FROM Expense_Report__c
            ORDER BY Submission_Date__c DESC
            LIMIT 100
        ];
    }

    /**
     * @description Fetch line items for a specific expense report
     */
    @AuraEnabled
    public static List<Expense_Item__c> getItemsForReport(Id reportId) {
        return [
            SELECT Id, Name, Expense_Report__c, Travel_Request__c, Expense_Category__c,
                   Merchant_Name__c, Expense_Date__c, Claimed_Amount__c, Receipt_Amount__c,
                   Tax_Amount__c, Receipt_Number__c, Receipt_Attachment_Reference__c,
                   Receipt_Submission_Time__c, Receipt_Deadline__c, Receipt_Compliance_Status__c,
                   Receipt_Verification_Status__c, Anomaly_Risk_Score__c, Duplicate_Suspected__c,
                   Policy_Violation__c, AI_Explanation__c, Review_Status__c, Approved_Amount__c,
                   Reviewer_Comments__c, Late_Submission_Reason__c
            FROM Expense_Item__c
            WHERE Expense_Report__c = :reportId
            ORDER BY CreatedDate ASC
        ];
    }

    /**
     * @description Finance determination on a single expense item
     */
    @AuraEnabled
    public static Expense_Item__c reviewExpenseItem(Id expenseItemId, String reviewStatus, Decimal approvedAmount, String comments) {
        if (expenseItemId == null || String.isBlank(reviewStatus)) {
            throw new AuraHandledException('Item ID and review status are required.');
        }

        Expense_Item__c itm = [
            SELECT Id, Expense_Report__c, Claimed_Amount__c, Review_Status__c, Approved_Amount__c,
                   Reviewer_Comments__c, Travel_Request__c, Travel_Request__r.Budget__c
            FROM Expense_Item__c
            WHERE Id = :expenseItemId
            LIMIT 1
        ];

        itm.Review_Status__c = reviewStatus;
        itm.Reviewer_Comments__c = comments;

        if (reviewStatus == 'Approved') {
            itm.Approved_Amount__c = itm.Claimed_Amount__c;
        } else if (reviewStatus == 'Partial Approved') {
            itm.Approved_Amount__c = (approvedAmount != null ? approvedAmount : 0);
        } else if (reviewStatus == 'Rejected') {
            itm.Approved_Amount__c = 0;
        }

        update itm;

        // Roll up approved and rejected totals to parent Expense_Report__c
        syncExpenseReportTotals(itm.Expense_Report__c);

        return itm;
    }

    /**
     * @description Recalculate parent Expense Report totals based on reviewed items
     */
    public static void syncExpenseReportTotals(Id reportId) {
        if (reportId == null) return;

        List<Expense_Item__c> allItems = [
            SELECT Id, Claimed_Amount__c, Approved_Amount__c, Review_Status__c
            FROM Expense_Item__c
            WHERE Expense_Report__c = :reportId
        ];

        Decimal approvedTotal = 0;
        Decimal rejectedTotal = 0;
        Boolean allReviewed = true;

        for (Expense_Item__c item : allItems) {
            if (item.Review_Status__c == 'Pending Review') {
                allReviewed = false;
            } else if (item.Review_Status__c == 'Approved') {
                approvedTotal += (item.Approved_Amount__c != null ? item.Approved_Amount__c : 0);
            } else if (item.Review_Status__c == 'Partial Approved') {
                approvedTotal += (item.Approved_Amount__c != null ? item.Approved_Amount__c : 0);
                rejectedTotal += ((item.Claimed_Amount__c != null ? item.Claimed_Amount__c : 0) - (item.Approved_Amount__c != null ? item.Approved_Amount__c : 0));
            } else if (item.Review_Status__c == 'Rejected') {
                rejectedTotal += (item.Claimed_Amount__c != null ? item.Claimed_Amount__c : 0);
            }
        }

        Expense_Report__c rep = [
            SELECT Id, Total_Approved_Amount__c, Total_Rejected_Amount__c, Finance_Review_Status__c,
                   Reimbursement_Status__c, Travel_Request__c, Travel_Request__r.Budget__c
            FROM Expense_Report__c
            WHERE Id = :reportId
            LIMIT 1
        ];

        rep.Total_Approved_Amount__c = approvedTotal;
        rep.Total_Rejected_Amount__c = rejectedTotal;

        if (allReviewed) {
            rep.Finance_Review_Status__c = 'Approved';
            rep.Reimbursement_Status__c = 'Ready for Payment';
        }

        update rep;

        // Sync budget
        if (rep.Travel_Request__r.Budget__c != null) {
            TravelBudgetForecastService.recalculateBudgets(new Set<Id>{ rep.Travel_Request__r.Budget__c });
        }
    }

    /**
     * @description Transition reimbursement lifecycle (e.g. Ready for Payment -> Paid)
     */
    @AuraEnabled
    public static Expense_Report__c updateReimbursementStatus(Id reportId, String reimbursementStatus) {
        if (reportId == null || String.isBlank(reimbursementStatus)) {
            throw new AuraHandledException('Report ID and reimbursement status are required.');
        }

        Expense_Report__c rep = [
            SELECT Id, Reimbursement_Status__c, Reimbursement_Date__c, Total_Approved_Amount__c,
                   Travel_Request__c, Travel_Request__r.Budget__c
            FROM Expense_Report__c
            WHERE Id = :reportId
            LIMIT 1
        ];

        rep.Reimbursement_Status__c = reimbursementStatus;

        if (reimbursementStatus == 'Paid') {
            rep.Reimbursement_Date__c = Date.today();

            // Update Travel_Request__c actual cost and complete trip status
            if (rep.Travel_Request__c != null) {
                Travel_Request__c req = [
                    SELECT Id, Actual_Cost__c, Trip_Status__c
                    FROM Travel_Request__c
                    WHERE Id = :rep.Travel_Request__c
                    LIMIT 1
                ];
                req.Actual_Cost__c = rep.Total_Approved_Amount__c;
                req.Trip_Status__c = 'Completed';
                update req;
            }
        }

        update rep;

        if (rep.Travel_Request__r.Budget__c != null) {
            TravelBudgetForecastService.recalculateBudgets(new Set<Id>{ rep.Travel_Request__r.Budget__c });
        }

        return rep;
    }
}
