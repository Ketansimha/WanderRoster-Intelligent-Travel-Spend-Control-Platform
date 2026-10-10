/**
 * @description Service to verify receipts, detect anomalies, identify duplicate claims,
 *              and calculate anomaly risk scores for finance auditing.
 */
public with sharing class ReceiptVerificationService {

    public class VerificationSummary {
        @AuraEnabled public Integer totalVerified { get; set; }
        @AuraEnabled public Integer totalFlagged { get; set; }
        @AuraEnabled public Integer totalDuplicates { get; set; }
        @AuraEnabled public Integer totalDiscrepancies { get; set; }

        public VerificationSummary() {
            this.totalVerified = 0;
            this.totalFlagged = 0;
            this.totalDuplicates = 0;
            this.totalDiscrepancies = 0;
        }
    }

    /**
     * @description Verifies a list of expense items against receipts, duplicates, and policy limits
     */
    public static void verifyExpenseItems(List<Expense_Item__c> items) {
        if (items == null || items.isEmpty()) {
            return;
        }

        Map<String, Expense_Policy__mdt> policies = TravelPolicyService.getPoliciesByCategory();

        // Collect receipt numbers, merchants, and dates to detect duplicates
        Set<String> receiptNumbers = new Set<String>();
        Set<String> merchants = new Set<String>();
        Set<Date> expenseDates = new Set<Date>();
        Set<Id> currentItemIds = new Set<Id>();

        for (Expense_Item__c itm : items) {
            if (itm.Id != null) {
                currentItemIds.add(itm.Id);
            }
            if (String.isNotBlank(itm.Receipt_Number__c)) {
                receiptNumbers.add(itm.Receipt_Number__c.trim().toLowerCase());
            }
            if (String.isNotBlank(itm.Merchant_Name__c)) {
                merchants.add(itm.Merchant_Name__c.trim().toLowerCase());
            }
            if (itm.Expense_Date__c != null) {
                expenseDates.add(itm.Expense_Date__c);
            }
        }

        // Query potential duplicates in the database
        List<Expense_Item__c> existingItems = new List<Expense_Item__c>();
        if (!receiptNumbers.isEmpty() || (!merchants.isEmpty() && !expenseDates.isEmpty())) {
            existingItems = [
                SELECT Id, Name, Receipt_Number__c, Merchant_Name__c, Expense_Date__c, Claimed_Amount__c
                FROM Expense_Item__c
                WHERE Id NOT IN :currentItemIds
                  AND (Receipt_Number__c IN :receiptNumbers
                       OR (Merchant_Name__c IN :merchants AND Expense_Date__c IN :expenseDates))
            ];
        }

        // Build duplicate lookup maps
        Map<String, Expense_Item__c> existingReceiptMap = new Map<String, Expense_Item__c>();
        Map<String, Expense_Item__c> existingMerchantDateAmountMap = new Map<String, Expense_Item__c>();
        for (Expense_Item__c ex : existingItems) {
            if (String.isNotBlank(ex.Receipt_Number__c)) {
                existingReceiptMap.put(ex.Receipt_Number__c.trim().toLowerCase(), ex);
            }
            if (String.isNotBlank(ex.Merchant_Name__c) && ex.Expense_Date__c != null && ex.Claimed_Amount__c != null) {
                String key = ex.Merchant_Name__c.trim().toLowerCase() + '|' + String.valueOf(ex.Expense_Date__c) + '|' + ex.Claimed_Amount__c;
                existingMerchantDateAmountMap.put(key, ex);
            }
        }

        // Also track duplicates among the current incoming batch
        Map<String, Expense_Item__c> batchReceiptMap = new Map<String, Expense_Item__c>();

        for (Expense_Item__c itm : items) {
            Integer riskScore = 0;
            List<String> explanations = new List<String>();
            Boolean isDuplicate = false;
            Boolean isDiscrepancy = false;
            Boolean isPolicyViolation = false;

            String cat = String.isNotBlank(itm.Expense_Category__c) ? itm.Expense_Category__c.toLowerCase() : '';
            Expense_Policy__mdt policy = policies.get(cat);

            // 1. Duplicate Receipt Number Check
            if (String.isNotBlank(itm.Receipt_Number__c)) {
                String rNumKey = itm.Receipt_Number__c.trim().toLowerCase();
                if (existingReceiptMap.containsKey(rNumKey)) {
                    Expense_Item__c dup = existingReceiptMap.get(rNumKey);
                    isDuplicate = true;
                    riskScore += 50;
                    explanations.add('Duplicate Suspected: Receipt #' + itm.Receipt_Number__c + 
                        ' was previously submitted under ' + dup.Name + ' (₹' + dup.Claimed_Amount__c + ').');
                } else if (batchReceiptMap.containsKey(rNumKey)) {
                    Expense_Item__c dup = batchReceiptMap.get(rNumKey);
                    isDuplicate = true;
                    riskScore += 50;
                    explanations.add('Duplicate Suspected: Duplicate receipt #' + itm.Receipt_Number__c + 
                        ' submitted in the same report.');
                } else {
                    batchReceiptMap.put(rNumKey, itm);
                }
            }

            // 1b. Matching Merchant + Date + Amount Check
            if (!isDuplicate && String.isNotBlank(itm.Merchant_Name__c) && itm.Expense_Date__c != null && itm.Claimed_Amount__c != null) {
                String key = itm.Merchant_Name__c.trim().toLowerCase() + '|' + String.valueOf(itm.Expense_Date__c) + '|' + itm.Claimed_Amount__c;
                if (existingMerchantDateAmountMap.containsKey(key)) {
                    Expense_Item__c dup = existingMerchantDateAmountMap.get(key);
                    isDuplicate = true;
                    riskScore += 40;
                    explanations.add('Duplicate Warning: Identical merchant, date, and amount (₹' + itm.Claimed_Amount__c + 
                        ') already claimed on ' + dup.Name + '.');
                }
            }

            // 2. Receipt Amount Discrepancy Check
            if (itm.Receipt_Amount__c != null && itm.Claimed_Amount__c != null) {
                Decimal diff = itm.Claimed_Amount__c - itm.Receipt_Amount__c;
                if (Math.abs(diff) > 0.01) {
                    isDiscrepancy = true;
                    riskScore += 35;
                    explanations.add('Amount Discrepancy Flag: Claimed amount (₹' + itm.Claimed_Amount__c + 
                        ') does not match extracted receipt amount (₹' + itm.Receipt_Amount__c + 
                        '). Discrepancy: ₹' + diff.abs() + '.');
                }
            }

            // 3. Policy Limit Check
            if (policy != null && policy.Max_Allowed_Amount__c != null && itm.Claimed_Amount__c != null) {
                if (itm.Claimed_Amount__c > policy.Max_Allowed_Amount__c) {
                    isPolicyViolation = true;
                    riskScore += 25;
                    explanations.add('Policy Limit Exceeded: Claimed ₹' + itm.Claimed_Amount__c + 
                        ' exceeds policy cap of ₹' + policy.Max_Allowed_Amount__c + ' for ' + policy.MasterLabel + '.');
                }
            }

            // 4. Missing Receipt Check
            if (policy != null && policy.Requires_Receipt__c == true && 
                String.isBlank(itm.Receipt_Attachment_Reference__c) && itm.Receipt_Amount__c == null) {
                riskScore += 25;
                explanations.add('Missing Receipt Document: Policy requires receipt document attachment.');
            }

            // Cap risk score between 0 and 100
            itm.Anomaly_Risk_Score__c = Math.min(100, riskScore);
            itm.Duplicate_Suspected__c = isDuplicate;
            itm.Policy_Violation__c = isPolicyViolation;

            if (isDuplicate) {
                itm.Receipt_Verification_Status__c = 'Duplicate Suspected';
            } else if (isDiscrepancy) {
                itm.Receipt_Verification_Status__c = 'Discrepancy Flagged';
            } else if (isPolicyViolation) {
                itm.Receipt_Verification_Status__c = 'Policy Limit Exceeded';
            } else if (riskScore > 30) {
                itm.Receipt_Verification_Status__c = 'Human Review Required';
            } else {
                itm.Receipt_Verification_Status__c = 'Verified';
            }

            if (explanations.isEmpty()) {
                itm.AI_Explanation__c = 'Receipt verified successfully. Amounts match, no duplicate claims detected, and expense is within policy limits.';
            } else {
                itm.AI_Explanation__c = String.join(explanations, '\n• ');
            }
        }
    }
}
