/**
 * @description Controller for Travel Outcome logging, ROI analysis, and spend vs outcome comparison.
 */
public with sharing class TravelOutcomeController {

    public class OutcomeRoiSummary {
        @AuraEnabled public Travel_Outcome__c outcome { get; set; }
        @AuraEnabled public Decimal actualSpend { get; set; }
        @AuraEnabled public Decimal businessValue { get; set; }
        @AuraEnabled public Decimal netRoi { get; set; }
        @AuraEnabled public Decimal roiRatio { get; set; }
    }

    /**
     * @description Log or update a travel outcome post-trip
     */
    @AuraEnabled
    public static Travel_Outcome__c saveOutcome(Travel_Outcome__c outcome) {
        if (outcome == null) {
            throw new AuraHandledException('Invalid outcome record.');
        }

        if (outcome.Id == null) {
            insert outcome;
        } else {
            update outcome;
        }

        // Also update summary on parent Travel_Request__c
        if (outcome.Travel_Request__c != null) {
            Travel_Request__c req = [
                SELECT Id, Business_Outcome_Summary__c
                FROM Travel_Request__c
                WHERE Id = :outcome.Travel_Request__c
                LIMIT 1
            ];
            req.Business_Outcome_Summary__c = outcome.Outcome_Description__c;
            update req;
        }

        return outcome;
    }

    /**
     * @description Fetch all travel outcomes with spend-to-value analysis
     */
    @AuraEnabled(cacheable=true)
    public static List<OutcomeRoiSummary> getOutcomeSummaries() {
        List<OutcomeRoiSummary> summaries = new List<OutcomeRoiSummary>();

        List<Travel_Outcome__c> outcomes = [
            SELECT Id, Name, Travel_Request__c, Travel_Request__r.Name, Travel_Request__r.Destination__c,
                   Travel_Request__r.Travel_Purpose__c, Travel_Request__r.Actual_Cost__c,
                   Travel_Request__r.Total_Estimated_Cost__c, Business_Objective__c,
                   Outcome_Description__c, Outcome_Status__c, Business_Value_Estimate__c,
                   Follow_up_Required__c, Follow_up_Actions__c, Manager_Feedback__c, CreatedDate
            FROM Travel_Outcome__c
            ORDER BY CreatedDate DESC
            LIMIT 50
        ];

        for (Travel_Outcome__c out : outcomes) {
            OutcomeRoiSummary s = new OutcomeRoiSummary();
            s.outcome = out;
            s.actualSpend = out.Travel_Request__r.Actual_Cost__c != null && out.Travel_Request__r.Actual_Cost__c > 0 
                ? out.Travel_Request__r.Actual_Cost__c 
                : (out.Travel_Request__r.Total_Estimated_Cost__c != null ? out.Travel_Request__r.Total_Estimated_Cost__c : 0);
            s.businessValue = out.Business_Value_Estimate__c != null ? out.Business_Value_Estimate__c : 0;
            s.netRoi = s.businessValue - s.actualSpend;
            s.roiRatio = s.actualSpend > 0 ? (s.businessValue / s.actualSpend).setScale(2) : 0;
            summaries.add(s);
        }

        return summaries;
    }
}
