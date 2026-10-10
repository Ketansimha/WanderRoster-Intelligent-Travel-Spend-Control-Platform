/**
 * @description Controller for consent-based travel location updates and progress tracking.
 *              Strictly enforces privacy consent and ensures tracking is limited to authorized trips.
 */
public with sharing class TravelLocationController {

    /**
     * @description Record a consent-based location check-in during an authorized trip
     */
    @AuraEnabled
    public static Travel_Location_Update__c recordLocationUpdate(Travel_Location_Update__c locUpdate) {
        if (locUpdate == null) {
            throw new AuraHandledException('Invalid location payload.');
        }

        if (locUpdate.Location_Sharing_Consent__c != true) {
            throw new AuraHandledException('Privacy Requirement: Location check-in requires explicit employee consent.');
        }

        if (locUpdate.Employee__c == null) {
            locUpdate.Employee__c = UserInfo.getUserId();
        }

        locUpdate.Location_Timestamp__c = DateTime.now();

        // Ensure associated travel request is valid
        if (locUpdate.Travel_Request__c != null) {
            Travel_Request__c req = [
                SELECT Id, Trip_Status__c, Departure_Date__c, Return_Date__c
                FROM Travel_Request__c
                WHERE Id = :locUpdate.Travel_Request__c
                LIMIT 1
            ];

            // If trip not started, advance to In Progress
            if (req.Trip_Status__c == 'Scheduled' || req.Trip_Status__c == 'Not Started') {
                req.Trip_Status__c = 'In Progress';
                update req;
            }
        }

        insert locUpdate;
        return locUpdate;
    }

    /**
     * @description Fetch check-in history for a travel request
     */
    @AuraEnabled(cacheable=true)
    public static List<Travel_Location_Update__c> getLocationHistory(Id travelRequestId) {
        return [
            SELECT Id, Name, Travel_Request__c, Employee__c, Employee__r.Name,
                   Latitude__c, Longitude__c, Location_City__c, Location_Timestamp__c,
                   Trip_Progress_Status__c, Update_Source__c
            FROM Travel_Location_Update__c
            WHERE Travel_Request__c = :travelRequestId
            ORDER BY Location_Timestamp__c DESC
            LIMIT 50
        ];
    }
}
