/**
 * @description Unit tests for TravelPolicyService.
 */
@isTest
private class TravelPolicyServiceTest {

    @isTest
    static void testPolicyComplianceNormal() {
        Travel_Budget__c budget = TravelTestDataFactory.createBudget('Engineering', 100000);
        Travel_Request__c req = TravelTestDataFactory.createTravelRequest(UserInfo.getUserId(), budget.Id, 12000, 5000);

        Test.startTest();
        TravelPolicyService.PolicyValidationResult result = TravelPolicyService.evaluateRequest(req);
        Test.stopTest();

        System.assertEquals('Compliant', result.status, 'Standard travel costs should pass as Compliant');
        System.assertEquals(false, result.requiresExecutiveApproval, 'Compliant request should not need executive sign-off');
    }

    @isTest
    static void testPolicyViolationHighSpend() {
        Travel_Budget__c budget = TravelTestDataFactory.createBudget('Sales', 150000);
        // ₹25,000 flights exceeds flight executive threshold of ₹20,000
        Travel_Request__c req = TravelTestDataFactory.createTravelRequest(UserInfo.getUserId(), budget.Id, 25000, 15000);

        Test.startTest();
        TravelPolicyService.PolicyValidationResult result = TravelPolicyService.evaluateRequest(req);
        Test.stopTest();

        System.assertEquals('Policy Violation', result.status, 'Exorbitant flight spend should flag as Policy Violation');
        System.assertEquals(true, result.requiresExecutiveApproval, 'Should require executive escalation');
        System.assert(result.violationDetails.size() > 0, 'Should include violation details');
    }

    @isTest
    static void testBulkPolicyEvaluation() {
        Travel_Budget__c budget = TravelTestDataFactory.createBudget('Marketing', 200000);
        List<Travel_Request__c> reqList = new List<Travel_Request__c>{
            TravelTestDataFactory.createTravelRequest(UserInfo.getUserId(), budget.Id, 10000, 4000),
            TravelTestDataFactory.createTravelRequest(UserInfo.getUserId(), budget.Id, 22000, 12000)
        };

        Test.startTest();
        TravelPolicyService.evaluateAndPopulate(reqList);
        Test.stopTest();

        System.assertNotEquals(null, reqList[0].Policy_Validation_Status__c, 'Status should be populated');
        System.assertNotEquals(null, reqList[1].Policy_Validation_Status__c, 'Status should be populated');
    }
}
