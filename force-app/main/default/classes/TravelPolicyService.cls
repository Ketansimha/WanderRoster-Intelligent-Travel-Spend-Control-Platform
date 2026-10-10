/**
 * @description Service to evaluate Travel Requests and Expense Items against configurable Expense_Policy__mdt rules.
 *              Enforces policy limits, threshold warnings, and class restrictions.
 */
public with sharing class TravelPolicyService {

    public class PolicyValidationResult {
        @AuraEnabled public String status { get; set; } // Compliant, Warning, Policy Violation
        @AuraEnabled public List<String> violationDetails { get; set; }
        @AuraEnabled public Boolean requiresExecutiveApproval { get; set; }
        @AuraEnabled public Decimal totalPotentialSavings { get; set; }

        public PolicyValidationResult() {
            this.status = 'Compliant';
            this.violationDetails = new List<String>();
            this.requiresExecutiveApproval = false;
            this.totalPotentialSavings = 0;
        }

        public String getJoinedDetails() {
            if (violationDetails == null || violationDetails.isEmpty()) {
                return 'All line items comply with corporate expense policies.';
            }
            return String.join(violationDetails, '\n• ');
        }
    }

    /**
     * @description Fetch all configured expense policies from Custom Metadata
     */
    public static Map<String, Expense_Policy__mdt> getPoliciesByCategory() {
        Map<String, Expense_Policy__mdt> policyMap = new Map<String, Expense_Policy__mdt>();
        for (Expense_Policy__mdt policy : [
            SELECT DeveloperName, MasterLabel, Expense_Category__c, Max_Allowed_Amount__c,
                   Approval_Threshold__c, Receipt_Deadline_Hours__c, Travel_Class_Restriction__c,
                   Requires_Receipt__c
            FROM Expense_Policy__mdt
        ]) {
            if (String.isNotBlank(policy.Expense_Category__c)) {
                policyMap.put(policy.Expense_Category__c.toLowerCase(), policy);
            }
        }
        return policyMap;
    }

    /**
     * @description Evaluates a single Travel Request against expense policy rules
     */
    public static PolicyValidationResult evaluateRequest(Travel_Request__c request) {
        PolicyValidationResult result = new PolicyValidationResult();
        Map<String, Expense_Policy__mdt> policies = getPoliciesByCategory();

        // 1. Validate Transport / Flight
        if (request.Estimated_Transport_Cost__c != null && request.Estimated_Transport_Cost__c > 0) {
            Expense_Policy__mdt flightPolicy = policies.get('flights');
            if (flightPolicy != null) {
                if (flightPolicy.Approval_Threshold__c != null && request.Estimated_Transport_Cost__c > flightPolicy.Approval_Threshold__c) {
                    result.status = 'Policy Violation';
                    result.requiresExecutiveApproval = true;
                    result.violationDetails.add('Transport estimate (₹' + request.Estimated_Transport_Cost__c + 
                        ') exceeds executive approval threshold of ₹' + flightPolicy.Approval_Threshold__c + 
                        '. Requires Tier-2 Executive Approval.');
                } else if (flightPolicy.Max_Allowed_Amount__c != null && request.Estimated_Transport_Cost__c > flightPolicy.Max_Allowed_Amount__c) {
                    if (result.status != 'Policy Violation') {
                        result.status = 'Warning';
                    }
                    result.violationDetails.add('Transport estimate (₹' + request.Estimated_Transport_Cost__c + 
                        ') exceeds standard policy cap of ₹' + flightPolicy.Max_Allowed_Amount__c + 
                        ' (' + flightPolicy.Travel_Class_Restriction__c + '). Manager review required.');
                }
            }
        }

        // 2. Validate Accommodation / Hotel
        if (request.Estimated_Accommodation_Cost__c != null && request.Estimated_Accommodation_Cost__c > 0) {
            Expense_Policy__mdt hotelPolicy = policies.get('hotel');
            if (hotelPolicy != null) {
                Integer tripDays = 1;
                if (request.Departure_Date__c != null && request.Return_Date__c != null) {
                    tripDays = Math.max(1, request.Departure_Date__c.daysBetween(request.Return_Date__c));
                }
                Decimal maxAccommodation = (hotelPolicy.Max_Allowed_Amount__c != null ? hotelPolicy.Max_Allowed_Amount__c : 6000) * tripDays;
                Decimal thresholdAccommodation = (hotelPolicy.Approval_Threshold__c != null ? hotelPolicy.Approval_Threshold__c : 8000) * tripDays;

                if (request.Estimated_Accommodation_Cost__c > thresholdAccommodation) {
                    result.status = 'Policy Violation';
                    result.requiresExecutiveApproval = true;
                    result.violationDetails.add('Accommodation estimate (₹' + request.Estimated_Accommodation_Cost__c + 
                        ' for ' + tripDays + ' day(s)) exceeds executive ceiling of ₹' + thresholdAccommodation + '.');
                } else if (request.Estimated_Accommodation_Cost__c > maxAccommodation) {
                    if (result.status != 'Policy Violation') {
                        result.status = 'Warning';
                    }
                    result.violationDetails.add('Accommodation estimate (₹' + request.Estimated_Accommodation_Cost__c + 
                        ') exceeds standard daily rate cap of ₹' + (hotelPolicy.Max_Allowed_Amount__c * tripDays) + '.');
                }
            }
        }

        // 3. Validate Food
        if (request.Estimated_Food_Cost__c != null && request.Estimated_Food_Cost__c > 0) {
            Expense_Policy__mdt foodPolicy = policies.get('food');
            if (foodPolicy != null) {
                Integer tripDays = 1;
                if (request.Departure_Date__c != null && request.Return_Date__c != null) {
                    tripDays = Math.max(1, request.Departure_Date__c.daysBetween(request.Return_Date__c) + 1);
                }
                Decimal maxFood = (foodPolicy.Max_Allowed_Amount__c != null ? foodPolicy.Max_Allowed_Amount__c : 2500) * tripDays;
                if (request.Estimated_Food_Cost__c > maxFood) {
                    if (result.status != 'Policy Violation') {
                        result.status = 'Warning';
                    }
                    result.violationDetails.add('Food allowance estimate (₹' + request.Estimated_Food_Cost__c + 
                        ') exceeds standard allowance cap of ₹' + maxFood + ' for ' + tripDays + ' day(s).');
                }
            }
        }

        // 4. Validate Local Transport
        if (request.Estimated_Local_Transport_Cost__c != null && request.Estimated_Local_Transport_Cost__c > 0) {
            Expense_Policy__mdt cabPolicy = policies.get('local transport');
            if (cabPolicy != null && cabPolicy.Max_Allowed_Amount__c != null && request.Estimated_Local_Transport_Cost__c > (cabPolicy.Max_Allowed_Amount__c * 3)) {
                if (result.status != 'Policy Violation') {
                    result.status = 'Warning';
                }
                result.violationDetails.add('Local transit estimate (₹' + request.Estimated_Local_Transport_Cost__c + 
                    ') is above standard recommendation limit.');
            }
        }

        return result;
    }

    /**
     * @description Bulk evaluation and population of policy fields on Travel Requests
     */
    public static void evaluateAndPopulate(List<Travel_Request__c> requests) {
        for (Travel_Request__c req : requests) {
            PolicyValidationResult res = evaluateRequest(req);
            req.Policy_Validation_Status__c = res.status;
            req.Policy_Violation_Details__c = res.getJoinedDetails();
        }
    }
}
