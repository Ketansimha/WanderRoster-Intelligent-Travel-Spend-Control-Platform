/**
 * @description Unit tests for all WanderRoster Lightning Web Component Controllers.
 */
@isTest
private class TravelControllersTest {

    @isTest
    static void testTravelRequestControllerWorkflow() {
        // Scenario A: Normal approval flow
        Travel_Budget__c budget = TravelTestDataFactory.createBudget('Engineering', 200000);

        // 1. Preview
        Travel_Request__c reqDraft = new Travel_Request__c(
            Department__c = 'Engineering',
            Travel_Purpose__c = 'Client Meeting',
            Origin__c = 'Hyderabad',
            Destination__c = 'Bengaluru',
            Departure_Date__c = Date.today().addDays(4),
            Return_Date__c = Date.today().addDays(7),
            Estimated_Transport_Cost__c = 14000,
            Estimated_Accommodation_Cost__c = 6000,
            Estimated_Food_Cost__c = 2000,
            Estimated_Local_Transport_Cost__c = 1500,
            Estimated_Other_Cost__c = 500,
            Budget__c = budget.Id
        );

        Test.startTest();
        TravelRequestController.PreviewResult preview = TravelRequestController.previewPolicyAndAI(reqDraft);
        System.assertNotEquals(null, preview.policyResult, 'Policy preview should not be null');

        // 2. Save
        Travel_Request__c savedReq = TravelRequestController.saveTravelRequest(reqDraft);
        System.assertNotEquals(null, savedReq.Id, 'Travel request should be saved');

        // 3. Submit
        Travel_Request__c submittedReq = TravelRequestController.submitForApproval(savedReq.Id);
        System.assertEquals('Pending Approval', submittedReq.Approval_Status__c, 'Status should be Pending Approval');

        // 4. Queries
        List<Travel_Request__c> myReqs = TravelRequestController.getMyTravelRequests();
        System.assert(myReqs.size() > 0, 'Should return user requests');

        List<Travel_Request__c> pending = TravelRequestController.getPendingApprovals();
        System.assert(pending.size() > 0, 'Should return pending requests');

        List<Travel_Budget__c> budgets = TravelRequestController.getAvailableBudgets();
        System.assert(budgets.size() > 0, 'Should return available budgets');

        // 5. Update existing request
        savedReq.Estimated_Other_Cost__c = 800;
        Travel_Request__c updatedReq = TravelRequestController.saveTravelRequest(savedReq);
        System.assertEquals(800, updatedReq.Estimated_Other_Cost__c, 'Cost should be updated');

        // 6. Manager Decisions by distinct user
        User mgr;
        System.runAs(new User(Id = UserInfo.getUserId())) {
            mgr = TravelTestDataFactory.createTestUser('mgr1', 'System Administrator');
        }

        System.runAs(mgr) {
            Travel_Request__c approvedReq = TravelRequestController.processManagerApproval(savedReq.Id, 'Approve', 'Approved by manager');
            System.assertEquals('Approved', approvedReq.Approval_Status__c, 'Request should be approved');
            System.assertEquals('Scheduled', approvedReq.Trip_Status__c, 'Trip status should be Scheduled');

            Travel_Request__c changesReq = TravelRequestController.processManagerApproval(savedReq.Id, 'Changes Requested', 'Please revise transport');
            System.assertEquals('Changes Requested', changesReq.Approval_Status__c, 'Request should have changes requested');

            Travel_Request__c rejectedReq = TravelRequestController.processManagerApproval(savedReq.Id, 'Reject', 'Budget exceeded');
            System.assertEquals('Rejected', rejectedReq.Approval_Status__c, 'Request should be rejected');
        }

        // Test self-approval block
        Boolean exceptionCaught = false;
        try {
            TravelRequestController.processManagerApproval(savedReq.Id, 'Approve', 'Self approval attempt');
        } catch (Exception e) {
            exceptionCaught = true;
        }
        System.assertEquals(true, exceptionCaught, 'Self-approval must throw an exception');

        // Test date validation block
        Boolean dateException = false;
        try {
            Travel_Request__c badDateReq = new Travel_Request__c(
                Departure_Date__c = Date.today().addDays(5),
                Return_Date__c = Date.today().addDays(2)
            );
            TravelRequestController.saveTravelRequest(badDateReq);
        } catch (Exception e) {
            dateException = true;
        }
        System.assertEquals(true, dateException, 'Invalid date range must throw an exception');

        Test.stopTest();
    }

    @isTest
    static void testExpenseReviewControllerWorkflow() {
        Travel_Budget__c budget = TravelTestDataFactory.createBudget('Sales', 200000);
        Travel_Request__c req = TravelTestDataFactory.createTravelRequest(UserInfo.getUserId(), budget.Id, 15000, 6000);

        Expense_Report__c rep = new Expense_Report__c(
            Travel_Request__c = req.Id
        );

        Expense_Item__c item1 = new Expense_Item__c(
            Expense_Category__c = 'Flights',
            Merchant_Name__c = 'Air India',
            Expense_Date__c = Date.today(),
            Claimed_Amount__c = 15000,
            Receipt_Amount__c = 15000,
            Receipt_Number__c = 'AI-INV-9988'
        );

        Test.startTest();
        Expense_Report__c submittedReport = ExpenseReviewController.submitExpenseReport(rep, new List<Expense_Item__c>{ item1 });
        System.assertNotEquals(null, submittedReport.Id, 'Expense report should be inserted');

        List<Expense_Report__c> reportsForReview = ExpenseReviewController.getReportsForReview();
        System.assert(reportsForReview.size() > 0, 'Should return reports for review');

        List<Expense_Item__c> items = ExpenseReviewController.getItemsForReport(submittedReport.Id);
        System.assertEquals(1, items.size(), 'Should return 1 item');

        // Test Receipt file upload and attachment
        ContentVersion cv = new ContentVersion(
            Title = 'Test Receipt',
            PathOnClient = 'receipt.jpg',
            VersionData = Blob.valueOf('Fake receipt content')
        );
        insert cv;
        Id docId = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id].ContentDocumentId;
        Expense_Item__c attachedItem = ExpenseReviewController.attachReceiptAndVerify(items[0].Id, docId, 15000);
        System.assertEquals(String.valueOf(docId), attachedItem.Receipt_Attachment_Reference__c, 'Attachment reference should match');

        // Review item
        Expense_Item__c reviewedItem = ExpenseReviewController.reviewExpenseItem(items[0].Id, 'Approved', 15000, 'Eligible flight expense');
        System.assertEquals('Approved', reviewedItem.Review_Status__c, 'Item should be approved');

        // Transition reimbursement status to Paid
        Expense_Report__c paidRep = ExpenseReviewController.updateReimbursementStatus(submittedReport.Id, 'Paid');
        System.assertEquals('Paid', paidRep.Reimbursement_Status__c, 'Reimbursement status should be Paid');
        Test.stopTest();
    }

    @isTest
    static void testTravelOutcomeAndLocationControllers() {
        // Scenario G: Business outcome
        Travel_Budget__c budget = TravelTestDataFactory.createBudget('Marketing', 200000);
        Travel_Request__c req = TravelTestDataFactory.createTravelRequest(UserInfo.getUserId(), budget.Id, 15000, 6000);
        req.Actual_Cost__c = 21000;
        update req;

        Travel_Outcome__c outcome = new Travel_Outcome__c(
            Travel_Request__c = req.Id,
            Business_Objective__c = 'Lead generation at Cloud Expo 2026',
            Outcome_Description__c = 'Signed 3 high-value enterprise POC contracts with annual value of ₹50,00,000.',
            Outcome_Status__c = 'Exceeded Expectations',
            Business_Value_Estimate__c = 5000000,
            Follow_up_Required__c = true,
            Follow_up_Actions__c = 'Schedule technical kickoff calls next Tuesday'
        );

        Test.startTest();
        Travel_Outcome__c savedOutcome = TravelOutcomeController.saveOutcome(outcome);
        System.assertNotEquals(null, savedOutcome.Id, 'Outcome should be saved');

        List<TravelOutcomeController.OutcomeRoiSummary> summaries = TravelOutcomeController.getOutcomeSummaries();
        System.assert(summaries.size() > 0, 'Should return outcome ROI summaries');
        System.assert(summaries[0].netRoi > 0, 'Net ROI should be positive');

        // Test Location Check-in
        Travel_Location_Update__c loc = new Travel_Location_Update__c(
            Travel_Request__c = req.Id,
            Location_Sharing_Consent__c = true,
            Location_City__c = 'Bengaluru',
            Trip_Progress_Status__c = 'Arrived',
            Update_Source__c = 'Manual Check-In',
            Latitude__c = 12.9716,
            Longitude__c = 77.5946
        );

        Travel_Location_Update__c savedLoc = TravelLocationController.recordLocationUpdate(loc);
        System.assertNotEquals(null, savedLoc.Id, 'Location update should be recorded');

        List<Travel_Location_Update__c> history = TravelLocationController.getLocationHistory(req.Id);
        System.assertEquals(1, history.size(), 'Should return check-in history');
        Test.stopTest();
    }

    @isTest
    static void testTravelDashboardController() {
        Travel_Budget__c budget = TravelTestDataFactory.createBudget('Finance', 300000);
        Travel_Request__c req = TravelTestDataFactory.createTravelRequest(UserInfo.getUserId(), budget.Id, 12000, 5000);

        Test.startTest();
        TravelDashboardController.DashboardMetricsDTO metrics = TravelDashboardController.getDashboardMetrics();
        Test.stopTest();

        System.assertNotEquals(null, metrics, 'Dashboard metrics DTO should not be null');
        System.assert(metrics.totalAllocatedBudget > 0, 'Total allocated budget should be calculated');
    }
}
