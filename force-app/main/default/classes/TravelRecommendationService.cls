/**
 * @description AI Recommendation Engine for WanderRoster.
 *              Generates intelligent, rule-based cost-saving alternatives and predicts travel spend.
 *              Keeps potential savings strictly separated from realized savings.
 */
public with sharing class TravelRecommendationService {

    public class RecommendationItem {
        @AuraEnabled public String category { get; set; }
        @AuraEnabled public String title { get; set; }
        @AuraEnabled public String suggestion { get; set; }
        @AuraEnabled public Decimal currentEstimate { get; set; }
        @AuraEnabled public Decimal optimizedEstimate { get; set; }
        @AuraEnabled public Decimal potentialSavings { get; set; }
        @AuraEnabled public String confidenceLevel { get; set; } // High, Moderate

        public RecommendationItem(String category, String title, String suggestion, 
                                  Decimal currentEstimate, Decimal optimizedEstimate, String confidence) {
            this.category = category;
            this.title = title;
            this.suggestion = suggestion;
            this.currentEstimate = currentEstimate != null ? currentEstimate : 0;
            this.optimizedEstimate = optimizedEstimate != null ? optimizedEstimate : 0;
            this.potentialSavings = this.currentEstimate - this.optimizedEstimate;
            this.confidenceLevel = confidence;
        }
    }

    public class RecommendationAnalysis {
        @AuraEnabled public Decimal originalTotal { get; set; }
        @AuraEnabled public Decimal recommendedTotal { get; set; }
        @AuraEnabled public Decimal totalPotentialSavings { get; set; }
        @AuraEnabled public List<RecommendationItem> items { get; set; }
        @AuraEnabled public String executiveSummary { get; set; }

        public RecommendationAnalysis() {
            this.originalTotal = 0;
            this.recommendedTotal = 0;
            this.totalPotentialSavings = 0;
            this.items = new List<RecommendationItem>();
            this.executiveSummary = '';
        }
    }

    /**
     * @description Generates AI travel optimizations based on requested route, dates, and budget caps
     */
    public static RecommendationAnalysis generateRecommendations(Travel_Request__c request) {
        RecommendationAnalysis analysis = new RecommendationAnalysis();
        Decimal origTotal = 0;

        Decimal transport = request.Estimated_Transport_Cost__c != null ? request.Estimated_Transport_Cost__c : 0;
        Decimal accommodation = request.Estimated_Accommodation_Cost__c != null ? request.Estimated_Accommodation_Cost__c : 0;
        Decimal food = request.Estimated_Food_Cost__c != null ? request.Estimated_Food_Cost__c : 0;
        Decimal localTransport = request.Estimated_Local_Transport_Cost__c != null ? request.Estimated_Local_Transport_Cost__c : 0;
        Decimal other = request.Estimated_Other_Cost__c != null ? request.Estimated_Other_Cost__c : 0;

        origTotal = transport + accommodation + food + localTransport + other;
        analysis.originalTotal = origTotal;

        // 1. Flight / Transport Optimization
        if (transport > 10000) {
            Decimal optTransport = transport * 0.80; // 20% savings via 14-day advance booking or corporate carrier rate
            analysis.items.add(new RecommendationItem(
                'Flights',
                'Corporate Airline Partner & Advance Booking',
                'Book corporate preferred carrier or depart 45 mins earlier to capture negotiated tier discount. Potential 20% savings.',
                transport,
                optTransport.setScale(2),
                'High'
            ));
        }

        // 2. Hotel / Accommodation Optimization
        if (accommodation > 5000) {
            Decimal optHotel = accommodation * 0.75; // 25% savings via preferred 3-star business hotel near office/meeting venue
            analysis.items.add(new RecommendationItem(
                'Hotel',
                'Preferred Business Hotel Rate',
                'Select partner business hotel near ' + (String.isNotBlank(request.Destination__c) ? request.Destination__c : 'destination') + 
                ' business hub with complimentary breakfast and shuttle, reducing lodging and morning cab expenses.',
                accommodation,
                optHotel.setScale(2),
                'High'
            ));
        }

        // 3. Local Transport / Cab Optimization
        if (localTransport > 2000) {
            Decimal optLocal = localTransport * 0.70; // 30% savings via corporate ride-hailing pass / metro
            analysis.items.add(new RecommendationItem(
                'Local Transport',
                'Corporate Transit Pass / Rideshare Pool',
                'Utilize corporate ride pass instead of on-demand peak airport taxis.',
                localTransport,
                optLocal.setScale(2),
                'Moderate'
            ));
        }

        // 4. Meal / Food Optimization
        if (food > 3000) {
            Decimal optFood = food * 0.85;
            analysis.items.add(new RecommendationItem(
                'Food',
                'Standard Per-Diem Meal Allowance',
                'Align dining with standard corporate per-diem allowance tier.',
                food,
                optFood.setScale(2),
                'Moderate'
            ));
        }

        // Calculate Totals
        Decimal totalSavings = 0;
        for (RecommendationItem item : analysis.items) {
            totalSavings += item.potentialSavings;
        }

        analysis.totalPotentialSavings = totalSavings.setScale(2);
        analysis.recommendedTotal = (analysis.originalTotal - analysis.totalPotentialSavings).setScale(2);

        if (analysis.totalPotentialSavings > 0) {
            analysis.executiveSummary = 'AI Spend Optimizer identified ₹' + analysis.totalPotentialSavings + 
                ' in potential savings (' + 
                (analysis.originalTotal > 0 ? String.valueOf(((analysis.totalPotentialSavings / analysis.originalTotal) * 100).setScale(1)) : '0') + 
                '%) across ' + analysis.items.size() + ' categories without compromising business objectives.';
        } else {
            analysis.executiveSummary = 'Proposed travel spend is already fully optimized and aligned with corporate benchmarks.';
        }

        return analysis;
    }

    /**
     * @description Populates AI recommendation fields on the Travel Request record
     */
    public static void populateAIRecommendations(Travel_Request__c request) {
        RecommendationAnalysis analysis = generateRecommendations(request);
        request.Potential_Savings__c = analysis.totalPotentialSavings;

        List<String> summaryLines = new List<String>();
        summaryLines.add(analysis.executiveSummary);
        for (RecommendationItem item : analysis.items) {
            summaryLines.add('• ' + item.category + ': ' + item.title + ' (Saves ₹' + item.potentialSavings + ')');
        }
        request.AI_Recommendation__c = String.join(summaryLines, '\n');
    }
}
