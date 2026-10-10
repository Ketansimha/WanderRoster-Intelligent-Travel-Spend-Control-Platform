import { LightningElement, track, wire } from 'lwc';
import getMyTravelRequests from '@salesforce/apex/TravelRequestController.getMyTravelRequests';
import getAvailableBudgets from '@salesforce/apex/TravelRequestController.getAvailableBudgets';
import saveTravelRequest from '@salesforce/apex/TravelRequestController.saveTravelRequest';
import submitForApproval from '@salesforce/apex/TravelRequestController.submitForApproval';
import previewPolicyAndAI from '@salesforce/apex/TravelRequestController.previewPolicyAndAI';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class TravelRequestPortal extends LightningElement {
    @track myRequests = [];
    @track budgetOptions = [];
    @track isLoading = false;
    @track isModalOpen = false;
    @track isPreChecking = false;
    @track previewResults = null;

    @track form = {
        Origin__c: 'Hyderabad',
        Destination__c: 'Bengaluru',
        Departure_Date__c: '',
        Return_Date__c: '',
        Travel_Purpose__c: 'Client Meeting',
        Budget__c: '',
        Estimated_Transport_Cost__c: 12000,
        Estimated_Accommodation_Cost__c: 6000,
        Estimated_Food_Cost__c: 2000,
        Estimated_Local_Transport_Cost__c: 1500,
        Estimated_Other_Cost__c: 500,
        Business_Justification__c: ''
    };

    purposeOptions = [
        { label: 'Client Meeting', value: 'Client Meeting' },
        { label: 'Conference & Training', value: 'Conference & Training' },
        { label: 'Sales Pitch', value: 'Sales Pitch' },
        { label: 'Project Kickoff', value: 'Project Kickoff' },
        { label: 'Site Visit', value: 'Site Visit' },
        { label: 'Internal Review', value: 'Internal Review' },
        { label: 'Other', value: 'Other' }
    ];

    connectedCallback() {
        this.loadRequests();
        this.loadBudgets();
    }

    get hasRequests() {
        return this.myRequests && this.myRequests.length > 0;
    }

    get computedTotal() {
        const t = (parseFloat(this.form.Estimated_Transport_Cost__c) || 0) +
                  (parseFloat(this.form.Estimated_Accommodation_Cost__c) || 0) +
                  (parseFloat(this.form.Estimated_Food_Cost__c) || 0) +
                  (parseFloat(this.form.Estimated_Local_Transport_Cost__c) || 0) +
                  (parseFloat(this.form.Estimated_Other_Cost__c) || 0);
        return t.toFixed(2);
    }

    get previewPolicyBadgeClass() {
        if (!this.previewResults || !this.previewResults.policyResult) return 'slds-badge';
        const st = this.previewResults.policyResult.status;
        if (st === 'Compliant') return 'slds-badge slds-theme_success';
        if (st === 'Warning') return 'slds-badge slds-theme_warning';
        return 'slds-badge slds-theme_error';
    }

    get previewPolicyDetails() {
        if (!this.previewResults || !this.previewResults.policyResult) return '';
        const details = this.previewResults.policyResult.violationDetails;
        if (!details || details.length === 0) return 'All estimated line items adhere to company expense policies.';
        return details.join(' • ');
    }

    get previewBudgetWarning() {
        return this.previewResults && this.previewResults.budgetResult && !this.previewResults.budgetResult.isAvailable;
    }

    loadRequests() {
        this.isLoading = true;
        getMyTravelRequests()
            .then(data => {
                this.myRequests = data.map(r => ({
                    ...r,
                    isDraft: r.Approval_Status__c === 'Draft',
                    policyClass: this.getBadgeClassForPolicy(r.Policy_Validation_Status__c),
                    approvalClass: this.getBadgeClassForApproval(r.Approval_Status__c)
                }));
                this.isLoading = false;
            })
            .catch(error => {
                this.isLoading = false;
                this.showToast('Error', error.body ? error.body.message : error.message, 'error');
            });
    }

    loadBudgets() {
        getAvailableBudgets()
            .then(data => {
                this.budgetOptions = data.map(b => ({
                    label: `${b.Name} (Avail: ₹${b.Remaining_Budget__c != null ? b.Remaining_Budget__c : b.Allocated_Budget__c})`,
                    value: b.Id
                }));
                if (this.budgetOptions.length > 0 && !this.form.Budget__c) {
                    this.form.Budget__c = this.budgetOptions[0].value;
                }
            })
            .catch(error => {
                console.error('Error loading budgets', error);
            });
    }

    getBadgeClassForPolicy(status) {
        if (status === 'Compliant') return 'slds-badge slds-theme_success';
        if (status === 'Warning') return 'slds-badge slds-theme_warning';
        if (status === 'Policy Violation') return 'slds-badge slds-theme_error';
        return 'slds-badge';
    }

    getBadgeClassForApproval(status) {
        if (status === 'Approved') return 'slds-badge slds-theme_success';
        if (status === 'Pending Approval') return 'slds-badge slds-theme_warning';
        if (status === 'Rejected') return 'slds-badge slds-theme_error';
        return 'slds-badge';
    }

    handleOpenModal() {
        this.isModalOpen = true;
        this.previewResults = null;
    }

    handleCloseModal() {
        this.isModalOpen = false;
    }

    handleInputChange(event) {
        const field = event.target.dataset.field;
        this.form[field] = event.target.value;
    }

    handleRunPreCheck() {
        this.isPreChecking = true;
        previewPolicyAndAI({ request: this.form })
            .then(result => {
                this.previewResults = result;
                this.isPreChecking = false;
                this.showToast('Pre-Check Complete', 'Policy evaluation and AI recommendations updated.', 'info');
            })
            .catch(error => {
                this.isPreChecking = false;
                this.showToast('Pre-Check Error', error.body ? error.body.message : error.message, 'error');
            });
    }

    handleSaveDraft() {
        this.isLoading = true;
        saveTravelRequest({ request: this.form })
            .then(() => {
                this.isLoading = false;
                this.isModalOpen = false;
                this.showToast('Success', 'Travel request saved as draft.', 'success');
                this.loadRequests();
            })
            .catch(error => {
                this.isLoading = false;
                this.showToast('Error', error.body ? error.body.message : error.message, 'error');
            });
    }

    handleSaveAndSubmit() {
        this.isLoading = true;
        saveTravelRequest({ request: this.form })
            .then(saved => {
                return submitForApproval({ requestId: saved.Id });
            })
            .then(() => {
                this.isLoading = false;
                this.isModalOpen = false;
                this.showToast('Success', 'Travel request successfully submitted for manager approval.', 'success');
                this.loadRequests();
            })
            .catch(error => {
                this.isLoading = false;
                this.showToast('Error', error.body ? error.body.message : error.message, 'error');
            });
    }

    handleSubmitExisting(event) {
        const reqId = event.target.dataset.id;
        this.isLoading = true;
        submitForApproval({ requestId: reqId })
            .then(() => {
                this.isLoading = false;
                this.showToast('Success', 'Request submitted for approval.', 'success');
                this.loadRequests();
            })
            .catch(error => {
                this.isLoading = false;
                this.showToast('Error', error.body ? error.body.message : error.message, 'error');
            });
    }

    handleViewDetails(event) {
        const reqId = event.target.dataset.id;
        this.showToast('Travel Request', `Viewing details for ${reqId}`, 'info');
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}
