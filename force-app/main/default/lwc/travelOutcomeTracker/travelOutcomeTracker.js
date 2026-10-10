import { LightningElement, track } from 'lwc';
import getOutcomeSummaries from '@salesforce/apex/TravelOutcomeController.getOutcomeSummaries';
import saveOutcome from '@salesforce/apex/TravelOutcomeController.saveOutcome';
import getMyTravelRequests from '@salesforce/apex/TravelRequestController.getMyTravelRequests';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class TravelOutcomeTracker extends LightningElement {
    @track outcomes = [];
    @track tripOptions = [];
    @track isLoading = false;
    @track isModalOpen = false;

    @track form = {
        Travel_Request__c: '',
        Business_Objective__c: '',
        Outcome_Description__c: '',
        Outcome_Status__c: 'Achieved',
        Business_Value_Estimate__c: 0,
        Follow_up_Required__c: false,
        Follow_up_Actions__c: ''
    };

    statusOptions = [
        { label: 'Achieved', value: 'Achieved' },
        { label: 'Exceeded Expectations', value: 'Exceeded Expectations' },
        { label: 'Partially Achieved', value: 'Partially Achieved' },
        { label: 'Not Achieved', value: 'Not Achieved' }
    ];

    connectedCallback() {
        this.loadOutcomes();
        this.loadTrips();
    }

    get hasOutcomes() {
        return this.outcomes && this.outcomes.length > 0;
    }

    loadOutcomes() {
        this.isLoading = true;
        getOutcomeSummaries()
            .then(data => {
                this.outcomes = data;
                this.isLoading = false;
            })
            .catch(error => {
                this.isLoading = false;
                this.showToast('Error', error.body ? error.body.message : error.message, 'error');
            });
    }

    loadTrips() {
        getMyTravelRequests()
            .then(data => {
                this.tripOptions = data.map(r => ({
                    label: `${r.Name} (${r.Origin__c} ➔ ${r.Destination__c})`,
                    value: r.Id
                }));
            })
            .catch(error => {
                console.error(error);
            });
    }

    handleOpenModal() {
        this.isModalOpen = true;
    }

    handleCloseModal() {
        this.isModalOpen = false;
    }

    handleInputChange(event) {
        const field = event.target.dataset.field;
        const val = event.target.type === 'checkbox' ? event.target.checked : event.target.value;
        this.form[field] = val;
    }

    handleSaveOutcome() {
        this.isLoading = true;
        saveOutcome({ outcome: this.form })
            .then(() => {
                this.isLoading = false;
                this.isModalOpen = false;
                this.showToast('Success', 'Business outcome logged successfully.', 'success');
                this.loadOutcomes();
            })
            .catch(error => {
                this.isLoading = false;
                this.showToast('Error', error.body ? error.body.message : error.message, 'error');
            });
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}
