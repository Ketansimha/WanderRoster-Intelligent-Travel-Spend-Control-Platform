import { LightningElement, api, track } from 'lwc';
import recordLocationUpdate from '@salesforce/apex/TravelLocationController.recordLocationUpdate';
import getLocationHistory from '@salesforce/apex/TravelLocationController.getLocationHistory';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class TripLocationTracker extends LightningElement {
    @api recordId; // Travel_Request__c record Id
    @track city = '';
    @track progressStatus = 'In Progress';
    @track consentGiven = true;
    @track checkInHistory = [];

    progressOptions = [
        { label: 'Departure', value: 'Departure' },
        { label: 'En Route', value: 'En Route' },
        { label: 'Arrived at Destination', value: 'Arrived' },
        { label: 'In Progress / At Venue', value: 'In Progress' },
        { label: 'Returning', value: 'Returning' },
        { label: 'Completed', value: 'Completed' }
    ];

    connectedCallback() {
        if (this.recordId) {
            this.loadHistory();
        }
    }

    get isSubmitDisabled() {
        return !this.consentGiven || !this.city;
    }

    get hasHistory() {
        return this.checkInHistory && this.checkInHistory.length > 0;
    }

    handleCityChange(event) {
        this.city = event.target.value;
    }

    handleStatusChange(event) {
        this.progressStatus = event.target.value;
    }

    handleConsentChange(event) {
        this.consentGiven = event.target.checked;
    }

    loadHistory() {
        getLocationHistory({ travelRequestId: this.recordId })
            .then(data => {
                this.checkInHistory = data;
            })
            .catch(error => {
                console.error(error);
            });
    }

    handleSubmitCheckIn() {
        const payload = {
            Travel_Request__c: this.recordId,
            Location_City__c: this.city,
            Trip_Progress_Status__c: this.progressStatus,
            Location_Sharing_Consent__c: this.consentGiven,
            Update_Source__c: 'Manual Check-In'
        };

        recordLocationUpdate({ locUpdate: payload })
            .then(() => {
                this.dispatchEvent(new ShowToastEvent({
                    title: 'Check-In Recorded',
                    message: `Milestone "${this.progressStatus}" saved for ${this.city}.`,
                    variant: 'success'
                }));
                this.city = '';
                this.loadHistory();
            })
            .catch(error => {
                this.dispatchEvent(new ShowToastEvent({
                    title: 'Check-In Error',
                    message: error.body ? error.body.message : error.message,
                    variant: 'error'
                }));
            });
    }
}
