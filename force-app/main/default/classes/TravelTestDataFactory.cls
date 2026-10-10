/**
 * @description Test Data Factory for WanderRoster unit tests.
 */
@isTest
public class TravelTestDataFactory {

    public static User createTestUser(String alias, String profileName) {
        Profile p = [SELECT Id FROM Profile WHERE Name = :profileName LIMIT 1];
        User u = new User(
            Alias = alias,
            Email = alias + '@wandertest.com',
            EmailEncodingKey = 'UTF-8',
            LastName = 'Tester',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = p.Id,
            TimeZoneSidKey = 'Asia/Kolkata',
            UserName = alias + DateTime.now().getTime() + '@wandertest.com'
        );
        insert u;
        return u;
    }

    public static Travel_Budget__c createBudget(String dept, Decimal allocated) {
        Travel_Budget__c b = new Travel_Budget__c(
            Name = dept + ' Travel Budget ' + Crypto.getRandomInteger(),
            Department__c = dept,
            Financial_Period__c = 'FY26-Q3',
            Allocated_Budget__c = allocated,
            Approved_Commitments__c = 0,
            Recorded_Expenses__c = 0,
            Pending_Commitments__c = 0
        );
        insert b;
        return b;
    }

    public static Travel_Request__c createTravelRequest(Id employeeId, Id budgetId, Decimal transport, Decimal hotel) {
        Travel_Request__c req = new Travel_Request__c(
            Employee__c = employeeId,
            Department__c = 'Engineering',
            Travel_Purpose__c = 'Client Meeting',
            Origin__c = 'Hyderabad',
            Destination__c = 'Bengaluru',
            Departure_Date__c = Date.today().addDays(5),
            Return_Date__c = Date.today().addDays(8),
            Estimated_Transport_Cost__c = transport,
            Estimated_Accommodation_Cost__c = hotel,
            Estimated_Food_Cost__c = 2000,
            Estimated_Local_Transport_Cost__c = 1500,
            Estimated_Other_Cost__c = 500,
            Business_Justification__c = 'On-site technical architecture kickoff with client engineering leadership.',
            Budget__c = budgetId,
            Approval_Status__c = 'Draft',
            Trip_Status__c = 'Not Started'
        );
        insert req;
        return req;
    }

    public static Expense_Report__c createExpenseReport(Id requestId, Id employeeId) {
        Expense_Report__c rep = new Expense_Report__c(
            Travel_Request__c = requestId,
            Employee__c = employeeId,
            Submission_Date__c = DateTime.now(),
            Finance_Review_Status__c = 'Draft',
            Reimbursement_Status__c = 'Not Submitted',
            Total_Claimed_Amount__c = 0
        );
        insert rep;
        return rep;
    }

    public static Expense_Item__c createExpenseItem(Id reportId, Id requestId, String category, Decimal claimed, Decimal receiptAmt) {
        Expense_Item__c itm = new Expense_Item__c(
            Expense_Report__c = reportId,
            Travel_Request__c = requestId,
            Expense_Category__c = category,
            Merchant_Name__c = 'Taj Hotels Bengaluru',
            Expense_Date__c = Date.today(),
            Claimed_Amount__c = claimed,
            Receipt_Amount__c = receiptAmt,
            Receipt_Number__c = 'INV-' + Crypto.getRandomInteger(),
            Receipt_Submission_Time__c = DateTime.now(),
            Review_Status__c = 'Pending Review'
        );
        insert itm;
        return itm;
    }
}
