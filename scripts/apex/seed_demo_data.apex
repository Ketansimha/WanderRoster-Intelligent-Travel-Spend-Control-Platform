/**
 * @description Demonstration seed script for WanderRoster.
 *              Sets up repeatable test records covering Scenarios A through G.
 */

// 1. Department Budgets
List<Travel_Budget__c> existingBudgets = [SELECT Id FROM Travel_Budget__c LIMIT 100];
if (!existingBudgets.isEmpty()) {
    delete existingBudgets;
}

Travel_Budget__c engBudget = new Travel_Budget__c(
    Name = 'FY26-Q3 Engineering Travel Budget',
    Department__c = 'Engineering',
    Financial_Period__c = 'FY26-Q3',
    Allocated_Budget__c = 250000,
    Approved_Commitments__c = 0,
    Recorded_Expenses__c = 0,
    Pending_Commitments__c = 0
);
insert engBudget;

Travel_Budget__c salesBudget = new Travel_Budget__c(
    Name = 'FY26-Q3 Sales Travel Budget',
    Department__c = 'Sales',
    Financial_Period__c = 'FY26-Q3',
    Allocated_Budget__c = 40000, // Budget constraint for Scenario B overrun test
    Approved_Commitments__c = 0,
    Recorded_Expenses__c = 0,
    Pending_Commitments__c = 0
);
insert salesBudget;

Travel_Budget__c opsBudget = new Travel_Budget__c(
    Name = 'FY26-Q3 Operations Travel Budget',
    Department__c = 'Operations',
    Financial_Period__c = 'FY26-Q3',
    Allocated_Budget__c = 150000,
    Approved_Commitments__c = 0,
    Recorded_Expenses__c = 0,
    Pending_Commitments__c = 0
);
insert opsBudget;

Id currentUserId = UserInfo.getUserId();

// 2. Scenario A: Normal Travel Request (Compliant & Approved)
Travel_Request__c reqA = new Travel_Request__c(
    Employee__c = currentUserId,
    Department__c = 'Engineering',
    Travel_Purpose__c = 'Client Meeting',
    Origin__c = 'Hyderabad',
    Destination__c = 'Bengaluru',
    Departure_Date__c = Date.today().addDays(3),
    Return_Date__c = Date.today().addDays(6),
    Estimated_Transport_Cost__c = 14000,
    Estimated_Accommodation_Cost__c = 10000,
    Estimated_Food_Cost__c = 3500,
    Estimated_Local_Transport_Cost__c = 2000,
    Estimated_Other_Cost__c = 500,
    Business_Justification__c = 'Scenario A: In-person customer integration workshop with tech architecture leadership.',
    Budget__c = engBudget.Id,
    Approval_Status__c = 'Approved',
    Trip_Status__c = 'Scheduled',
    Submission_Date__c = DateTime.now()
);
insert reqA;

// 3. Scenario B: Budget Overrun Request (₹50,000 spend vs ₹40,000 Sales budget)
Travel_Request__c reqB = new Travel_Request__c(
    Employee__c = currentUserId,
    Department__c = 'Sales',
    Travel_Purpose__c = 'Sales Pitch',
    Origin__c = 'Mumbai',
    Destination__c = 'Delhi',
    Departure_Date__c = Date.today().addDays(10),
    Return_Date__c = Date.today().addDays(14),
    Estimated_Transport_Cost__c = 25000,
    Estimated_Accommodation_Cost__c = 15000,
    Estimated_Food_Cost__c = 6000,
    Estimated_Local_Transport_Cost__c = 3000,
    Estimated_Other_Cost__c = 1000,
    Business_Justification__c = 'Scenario B: Q3 Enterprise pitch. Flags ₹10,000 shortfall against ₹40,000 Sales budget.',
    Budget__c = salesBudget.Id,
    Approval_Status__c = 'Pending Approval',
    Trip_Status__c = 'Not Started',
    Submission_Date__c = DateTime.now()
);
insert reqB;

// 4. Scenario G: Completed Trip with Documented Business Outcome
Travel_Request__c reqG = new Travel_Request__c(
    Employee__c = currentUserId,
    Department__c = 'Engineering',
    Travel_Purpose__c = 'Project Kickoff',
    Origin__c = 'Hyderabad',
    Destination__c = 'Chennai',
    Departure_Date__c = Date.today().addDays(-10),
    Return_Date__c = Date.today().addDays(-7),
    Estimated_Transport_Cost__c = 12000,
    Estimated_Accommodation_Cost__c = 10000,
    Estimated_Food_Cost__c = 4000,
    Estimated_Local_Transport_Cost__c = 2500,
    Estimated_Other_Cost__c = 1000,
    Actual_Cost__c = 29500,
    Business_Justification__c = 'Strategic Enterprise Client Technical Kickoff & Contract Negotiation.',
    Budget__c = engBudget.Id,
    Approval_Status__c = 'Approved',
    Trip_Status__c = 'Completed',
    Submission_Date__c = DateTime.now().addDays(-12)
);
insert reqG;

Travel_Outcome__c outcomeG = new Travel_Outcome__c(
    Travel_Request__c = reqG.Id,
    Business_Objective__c = 'On-site Enterprise Pilot Sign-Off & Architecture Alignment',
    Outcome_Description__c = 'Client executive steering committee approved multi-year cloud contract with ₹25,00,000 ARR value.',
    Outcome_Status__c = 'Exceeded Expectations',
    Business_Value_Estimate__c = 2500000,
    Follow_up_Required__c = true,
    Follow_up_Actions__c = 'Deliver Phase-1 integration sprint backlog by end of month.',
    Manager_Feedback__c = 'Exceptional ROI. Spend of ₹29,500 yielded a 84.7x business value multiplier.'
);
insert outcomeG;

// 5. Scenarios C, D, E: Expense Report with Discrepancy, Overdue Receipt, and Duplicates
Expense_Report__c report = new Expense_Report__c(
    Travel_Request__c = reqA.Id,
    Employee__c = currentUserId,
    Submission_Date__c = DateTime.now(),
    Finance_Review_Status__c = 'Submitted',
    Reimbursement_Status__c = 'Under Review'
);
insert report;

// Scenario C: Claimed ₹8,000, Receipt ₹8,800 discrepancy
Expense_Item__c itemC = new Expense_Item__c(
    Expense_Report__c = report.Id,
    Travel_Request__c = reqA.Id,
    Expense_Category__c = 'Hotel',
    Merchant_Name__c = 'The Chancery Pavilion Bengaluru',
    Expense_Date__c = Date.today().addDays(-1),
    Claimed_Amount__c = 8000,
    Receipt_Amount__c = 8800,
    Receipt_Number__c = 'CHANCERY-INV-8800',
    Receipt_Submission_Time__c = DateTime.now()
);
insert itemC;

// Scenario D: Incurred 4 days ago without receipt (overdue 24h compliance)
Expense_Item__c itemD = new Expense_Item__c(
    Expense_Report__c = report.Id,
    Travel_Request__c = reqA.Id,
    Expense_Category__c = 'Food',
    Merchant_Name__c = 'Vidyarthi Bhavan',
    Expense_Date__c = Date.today().addDays(-4),
    Claimed_Amount__c = 1500
);
insert itemD;

// Scenario E: Suspected Duplicate Receipts
Expense_Item__c itemE1 = new Expense_Item__c(
    Expense_Report__c = report.Id,
    Travel_Request__c = reqA.Id,
    Expense_Category__c = 'Flights',
    Merchant_Name__c = 'IndiGo Airlines',
    Expense_Date__c = Date.today().addDays(-2),
    Claimed_Amount__c = 7200,
    Receipt_Amount__c = 7200,
    Receipt_Number__c = 'DUP-AIR-7788',
    Receipt_Submission_Time__c = DateTime.now()
);
insert itemE1;

Expense_Item__c itemE2 = new Expense_Item__c(
    Expense_Report__c = report.Id,
    Travel_Request__c = reqA.Id,
    Expense_Category__c = 'Flights',
    Merchant_Name__c = 'IndiGo Airlines',
    Expense_Date__c = Date.today().addDays(-2),
    Claimed_Amount__c = 7200,
    Receipt_Amount__c = 7200,
    Receipt_Number__c = 'DUP-AIR-7788', // Identical receipt number -> triggers duplicate alert
    Receipt_Submission_Time__c = DateTime.now()
);
insert itemE2;

ExpenseReviewController.syncExpenseReportTotals(report.Id);
TravelBudgetForecastService.recalculateBudgets(new Set<Id>{ engBudget.Id, salesBudget.Id, opsBudget.Id });

System.debug('WanderRoster demonstration dataset initialized successfully.');
