/**
 * @description Unit tests for TravelRecommendationService AI spend optimization.
 */
@isTest
private class TravelRecommendationServiceTest {

    @isTest
    static void testRecommendationsGeneration() {
        Travel_Budget__c budget = TravelTestDataFactory.createBudget('Engineering', 200000);
        Travel_Request__c req = TravelTestDataFactory.createTravelRequest(UserInfo.getUserId(), budget.Id, 18000, 8000);
        req.Estimated_Local_Transport_Cost__c = 3000;
        req.Estimated_Food_Cost__c = 4000;

        Test.startTest();
        TravelRecommendationService.RecommendationAnalysis analysis = 
            TravelRecommendationService.generateRecommendations(req);
        Test.stopTest();

        System.assert(analysis.totalPotentialSavings > 0, 'AI engine should discover cost saving opportunities');
        System.assert(analysis.recommendedTotal < analysis.originalTotal, 'Optimized total should be lower than requested total');
        System.assert(analysis.items.size() >= 3, 'Should generate optimizations across flight, hotel, and local transit');
        System.assert(String.isNotBlank(analysis.executiveSummary), 'Should produce executive summary');
    }

    @isTest
    static void testPopulateRecommendations() {
        Travel_Budget__c budget = TravelTestDataFactory.createBudget('Sales', 150000);
        Travel_Request__c req = TravelTestDataFactory.createTravelRequest(UserInfo.getUserId(), budget.Id, 15000, 7000);

        Test.startTest();
        TravelRecommendationService.populateAIRecommendations(req);
        Test.stopTest();

        System.assert(req.Potential_Savings__c > 0, 'Potential savings field should be populated');
        System.assert(String.isNotBlank(req.AI_Recommendation__c), 'AI recommendation explanation should be populated');
    }
}
