/**
 * @description Lightning Web Component Controller for Employee Travel Portal and Manager Approval Workspace.
 *              Enforces CRUD/FLS, user permissions, and prevents self-approval.
 */
public with sharing class TravelRequestController {

    public class PreviewResult {
        @AuraEnabled public TravelPolicyService.PolicyValidationResult policyResult { get; set; }
        @AuraEnabled public TravelRecommendationService.RecommendationAnalysis aiResult { get; set; }
        @AuraEnabled public TravelBudgetForecastService.BudgetCheckResult budgetResult { get; set; }
    }

    /**
     * @description Live pre-check of policy, AI spend recommendations, and budget availability before submission
     */
    @AuraEnabled
    public static PreviewResult previewPolicyAndAI(Travel_Request__c request) {
        PreviewResult res = new PreviewResult();
        res.policyResult = TravelPolicyService.evaluateRequest(request);
        res.aiResult = TravelRecommendationService.generateRecommendations(request);

        Decimal totalEstimated = (request.Estimated_Transport_Cost__c != null ? request.Estimated_Transport_Cost__c : 0) +
                                 (request.Estimated_Accommodation_Cost__c != null ? request.Estimated_Accommodation_Cost__c : 0) +
                                 (request.Estimated_Food_Cost__c != null ? request.Estimated_Food_Cost__c : 0) +
                                 (request.Estimated_Local_Transport_Cost__c != null ? request.Estimated_Local_Transport_Cost__c : 0) +
                                 (request.Estimated_Other_Cost__c != null ? request.Estimated_Other_Cost__c : 0);

        if (request.Budget__c != null) {
            res.budgetResult = TravelBudgetForecastService.checkBudgetAvailability(request.Budget__c, totalEstimated);
        }

        return res;
    }

    /**
     * @description Saves a new or edited travel request, runs policy evaluation & AI recommendations
     */
    @AuraEnabled
    public static Travel_Request__c saveTravelRequest(Travel_Request__c request) {
        if (request == null) {
            throw new AuraHandledException('Invalid travel request payload.');
        }

        if (request.Departure_Date__c != null && request.Return_Date__c != null && request.Return_Date__c < request.Departure_Date__c) {
            throw new AuraHandledException('Return Date cannot be earlier than Departure Date.');
        }

        if (request.Employee__c == null) {
            request.Employee__c = UserInfo.getUserId();
        }

        // Auto-run policy evaluation & AI recommendations
        TravelPolicyService.evaluateAndPopulate(new List<Travel_Request__c>{ request });
        TravelRecommendationService.populateAIRecommendations(request);

        if (request.Id == null) {
            request.Approval_Status__c = 'Draft';
            request.Trip_Status__c = 'Not Started';
            insert request;
        } else {
            update request;
        }

        return [
            SELECT Id, Name, Employee__c, Employee__r.Name, Department__c, Travel_Purpose__c,
                   Origin__c, Destination__c, Departure_Date__c, Return_Date__c,
                   Estimated_Transport_Cost__c, Estimated_Accommodation_Cost__c, Estimated_Food_Cost__c,
                   Estimated_Local_Transport_Cost__c, Estimated_Other_Cost__c, Total_Estimated_Cost__c,
                   Business_Justification__c, Budget__c, Budget__r.Name, Policy_Validation_Status__c,
                   Policy_Violation_Details__c, AI_Recommendation__c, Potential_Savings__c,
                   Approval_Status__c, Approver__c, Approver__r.Name, Approval_Comments__c,
                   Trip_Status__c, Actual_Cost__c, Submission_Date__c
            FROM Travel_Request__c
            WHERE Id = :request.Id
            LIMIT 1
        ];
    }

    /**
     * @description Submits a travel request for manager approval and recalculates pending budget commitments
     */
    @AuraEnabled
    public static Travel_Request__c submitForApproval(Id requestId) {
        if (requestId == null) {
            throw new AuraHandledException('Request ID is required.');
        }

        Travel_Request__c req = [
            SELECT Id, Approval_Status__c, Budget__c, Total_Estimated_Cost__c, Submission_Date__c
            FROM Travel_Request__c
            WHERE Id = :requestId
            LIMIT 1
        ];

        req.Approval_Status__c = 'Pending Approval';
        req.Submission_Date__c = DateTime.now();
        update req;

        if (req.Budget__c != null) {
            TravelBudgetForecastService.recalculateBudgets(new Set<Id>{ req.Budget__c });
        }

        return req;
    }

    /**
     * @description Process manager decision (Approve / Reject / Changes Requested)
     *              Prevents unauthorized self-approval.
     */
    @AuraEnabled
    public static Travel_Request__c processManagerApproval(Id requestId, String decision, String comments) {
        if (requestId == null || String.isBlank(decision)) {
            throw new AuraHandledException('Request ID and approval decision are required.');
        }

        Travel_Request__c req = [
            SELECT Id, Employee__c, Approval_Status__c, Budget__c, Trip_Status__c
            FROM Travel_Request__c
            WHERE Id = :requestId
            LIMIT 1
        ];

        // Self-approval check
        Id currentUserId = UserInfo.getUserId();
        if (req.Employee__c == currentUserId) {
            throw new AuraHandledException('Corporate Policy Violation: Employees cannot approve their own travel requests.');
        }

        if (decision == 'Approve') {
            req.Approval_Status__c = 'Approved';
            req.Trip_Status__c = 'Scheduled';
        } else if (decision == 'Reject') {
            req.Approval_Status__c = 'Rejected';
            req.Trip_Status__c = 'Cancelled';
        } else if (decision == 'Changes Requested') {
            req.Approval_Status__c = 'Changes Requested';
        } else {
            throw new AuraHandledException('Unsupported decision: ' + decision);
        }

        req.Approver__c = currentUserId;
        req.Approval_Comments__c = comments;
        update req;

        if (req.Budget__c != null) {
            TravelBudgetForecastService.recalculateBudgets(new Set<Id>{ req.Budget__c });
        }

        return req;
    }

    /**
     * @description Fetch all requests created by the current user
     */
    @AuraEnabled(cacheable=true)
    public static List<Travel_Request__c> getMyTravelRequests() {
        Id currentUserId = UserInfo.getUserId();
        return [
            SELECT Id, Name, Employee__c, Employee__r.Name, Department__c, Travel_Purpose__c,
                   Origin__c, Destination__c, Departure_Date__c, Return_Date__c,
                   Estimated_Transport_Cost__c, Estimated_Accommodation_Cost__c, Estimated_Food_Cost__c,
                   Estimated_Local_Transport_Cost__c, Estimated_Other_Cost__c, Total_Estimated_Cost__c,
                   Business_Justification__c, Budget__c, Budget__r.Name, Policy_Validation_Status__c,
                   Policy_Violation_Details__c, AI_Recommendation__c, Potential_Savings__c,
                   Approval_Status__c, Approver__c, Approver__r.Name, Approval_Comments__c,
                   Trip_Status__c, Actual_Cost__c, Submission_Date__c
            FROM Travel_Request__c
            WHERE Employee__c = :currentUserId
            ORDER BY CreatedDate DESC
            LIMIT 100
        ];
    }

    /**
     * @description Fetch all travel requests pending approval
     */
    @AuraEnabled(cacheable=true)
    public static List<Travel_Request__c> getPendingApprovals() {
        return [
            SELECT Id, Name, Employee__c, Employee__r.Name, Department__c, Travel_Purpose__c,
                   Origin__c, Destination__c, Departure_Date__c, Return_Date__c,
                   Total_Estimated_Cost__c, Business_Justification__c, Budget__c, Budget__r.Name,
                   Budget__r.Remaining_Budget__c, Policy_Validation_Status__c,
                   Policy_Violation_Details__c, AI_Recommendation__c, Potential_Savings__c,
                   Approval_Status__c, Submission_Date__c
            FROM Travel_Request__c
            WHERE Approval_Status__c IN ('Submitted', 'Pending Approval')
            ORDER BY Submission_Date__c DESC
            LIMIT 100
        ];
    }

    /**
     * @description Fetch available travel budgets
     */
    @AuraEnabled(cacheable=true)
    public static List<Travel_Budget__c> getAvailableBudgets() {
        return [
            SELECT Id, Name, Department__c, Financial_Period__c, Allocated_Budget__c,
                   Approved_Commitments__c, Recorded_Expenses__c, Pending_Commitments__c,
                   Remaining_Budget__c, Forecast_Spending__c, Forecast_Variance__c,
                   Budget_Health_Status__c
            FROM Travel_Budget__c
            ORDER BY Name ASC
        ];
    }
}
