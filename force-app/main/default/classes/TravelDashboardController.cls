/**
 * @description Controller providing real-time data metrics for the Financial Intelligence Dashboard.
 *              Strictly distinguishes potential savings from realized savings and prevents double counting.
 */
public with sharing class TravelDashboardController {

    public class DepartmentSpendDTO {
        @AuraEnabled public String department { get; set; }
        @AuraEnabled public Decimal allocated { get; set; }
        @AuraEnabled public Decimal committed { get; set; }
        @AuraEnabled public Decimal recorded { get; set; }
        @AuraEnabled public Decimal remaining { get; set; }
    }

    public class DashboardMetricsDTO {
        @AuraEnabled public Decimal totalRequestedSpend { get; set; }
        @AuraEnabled public Decimal approvedCommitments { get; set; }
        @AuraEnabled public Decimal actualRecordedExpenses { get; set; }
        @AuraEnabled public Decimal totalRemainingBudget { get; set; }
        @AuraEnabled public Decimal totalAllocatedBudget { get; set; }
        @AuraEnabled public Decimal forecastSpending { get; set; }
        @AuraEnabled public Decimal forecastVariance { get; set; }

        @AuraEnabled public Decimal potentialSavings { get; set; }
        @AuraEnabled public Decimal realizedSavings { get; set; }

        @AuraEnabled public Integer policyExceptionCount { get; set; }
        @AuraEnabled public Integer overdueReceiptCount { get; set; }
        @AuraEnabled public Integer flaggedReviewCount { get; set; }
        @AuraEnabled public Integer totalReceiptsAnalyzed { get; set; }
        @AuraEnabled public Decimal receiptComplianceRate { get; set; }

        @AuraEnabled public List<DepartmentSpendDTO> departmentBreakdown { get; set; }

        public DashboardMetricsDTO() {
            this.totalRequestedSpend = 0;
            this.approvedCommitments = 0;
            this.actualRecordedExpenses = 0;
            this.totalRemainingBudget = 0;
            this.totalAllocatedBudget = 0;
            this.forecastSpending = 0;
            this.forecastVariance = 0;
            this.potentialSavings = 0;
            this.realizedSavings = 0;
            this.policyExceptionCount = 0;
            this.overdueReceiptCount = 0;
            this.flaggedReviewCount = 0;
            this.totalReceiptsAnalyzed = 0;
            this.receiptComplianceRate = 100;
            this.departmentBreakdown = new List<DepartmentSpendDTO>();
        }
    }

    /**
     * @description Calculates real-time financial intelligence metrics from live records
     */
    @AuraEnabled(cacheable=true)
    public static DashboardMetricsDTO getDashboardMetrics() {
        DashboardMetricsDTO dto = new DashboardMetricsDTO();

        // 1. Budget Aggregates
        for (Travel_Budget__c b : [
            SELECT Id, Department__c, Allocated_Budget__c, Approved_Commitments__c,
                   Recorded_Expenses__c, Pending_Commitments__c, Remaining_Budget__c,
                   Forecast_Spending__c, Forecast_Variance__c
            FROM Travel_Budget__c
        ]) {
            Decimal alloc = b.Allocated_Budget__c != null ? b.Allocated_Budget__c : 0;
            Decimal comm = b.Approved_Commitments__c != null ? b.Approved_Commitments__c : 0;
            Decimal rec = b.Recorded_Expenses__c != null ? b.Recorded_Expenses__c : 0;
            Decimal rem = b.Remaining_Budget__c != null ? b.Remaining_Budget__c : 0;

            dto.totalAllocatedBudget += alloc;
            dto.approvedCommitments += comm;
            dto.actualRecordedExpenses += rec;
            dto.totalRemainingBudget += rem;
            dto.forecastSpending += (b.Forecast_Spending__c != null ? b.Forecast_Spending__c : 0);
            dto.forecastVariance += (b.Forecast_Variance__c != null ? b.Forecast_Variance__c : 0);

            DepartmentSpendDTO d = new DepartmentSpendDTO();
            d.department = b.Department__c;
            d.allocated = alloc;
            d.committed = comm;
            d.recorded = rec;
            d.remaining = rem;
            dto.departmentBreakdown.add(d);
        }

        // 2. Travel Requests Totals & Potential Savings
        for (AggregateResult ar : [
            SELECT SUM(Total_Estimated_Cost__c) totalReq, SUM(Potential_Savings__c) totalPotSavings,
                   COUNT(Id) totalCount
            FROM Travel_Request__c
        ]) {
            Decimal req = (Decimal)ar.get('totalReq');
            Decimal pot = (Decimal)ar.get('totalPotSavings');
            dto.totalRequestedSpend = req != null ? req : 0;
            dto.potentialSavings = pot != null ? pot : 0;
        }

        // Policy Exception Count on Requests
        Integer reqViolations = [
            SELECT COUNT()
            FROM Travel_Request__c
            WHERE Policy_Validation_Status__c IN ('Warning', 'Policy Violation')
        ];
        dto.policyExceptionCount = reqViolations;

        // 3. Expense Items Compliance & Risk Metrics
        Integer onTimeCount = 0;
        Integer overdueCount = 0;
        Integer missingCount = 0;
        Integer flaggedCount = 0;
        Decimal totalClaimed = 0;
        Decimal totalApproved = 0;

        for (Expense_Item__c item : [
            SELECT Id, Claimed_Amount__c, Approved_Amount__c, Receipt_Compliance_Status__c,
                   Receipt_Verification_Status__c, Review_Status__c
            FROM Expense_Item__c
        ]) {
            dto.totalReceiptsAnalyzed++;
            if (item.Receipt_Compliance_Status__c == 'On-Time') {
                onTimeCount++;
            } else if (item.Receipt_Compliance_Status__c == 'Overdue') {
                overdueCount++;
            } else if (item.Receipt_Compliance_Status__c == 'Missing Receipt') {
                missingCount++;
            }

            if (item.Receipt_Verification_Status__c == 'Discrepancy Flagged' ||
                item.Receipt_Verification_Status__c == 'Duplicate Suspected' ||
                item.Receipt_Verification_Status__c == 'Policy Limit Exceeded' ||
                item.Receipt_Verification_Status__c == 'Human Review Required') {
                flaggedCount++;
            }

            if (item.Review_Status__c == 'Approved' || item.Review_Status__c == 'Partial Approved') {
                totalClaimed += (item.Claimed_Amount__c != null ? item.Claimed_Amount__c : 0);
                totalApproved += (item.Approved_Amount__c != null ? item.Approved_Amount__c : 0);
            }
        }

        dto.overdueReceiptCount = overdueCount + missingCount;
        dto.flaggedReviewCount = flaggedCount;

        // Realized Savings = Total Claimed - Total Approved on reviewed items (money saved from audit rejections)
        dto.realizedSavings = Math.max(0, totalClaimed - totalApproved);

        // Compliance rate %
        if (dto.totalReceiptsAnalyzed > 0) {
            dto.receiptComplianceRate = ((Decimal)onTimeCount / dto.totalReceiptsAnalyzed * 100).setScale(1);
        } else {
            dto.receiptComplianceRate = 100.0;
        }

        return dto;
    }
}
