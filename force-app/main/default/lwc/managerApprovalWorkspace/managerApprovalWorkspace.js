import { LightningElement, track } from 'lwc';
import getPendingApprovals from '@salesforce/apex/TravelRequestController.getPendingApprovals';
import processManagerApproval from '@salesforce/apex/TravelRequestController.processManagerApproval';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class ManagerApprovalWorkspace extends LightningElement {
    @track pendingRequests = [];
    @track isLoading = false;
    @track isActionModalOpen = false;
    @track selectedRequestId = null;
    @track selectedAction = '';
    @track actionComments = '';

    connectedCallback() {
        this.loadPendingApprovals();
    }

    get hasPending() {
        return this.pendingRequests && this.pendingRequests.length > 0;
    }

    get actionTitle() {
        if (this.selectedAction === 'Approve') return 'Approve Travel Request';
        if (this.selectedAction === 'Reject') return 'Reject Travel Request';
        if (this.selectedAction === 'Changes Requested') return 'Request Modifications';
        return 'Review Request';
    }

    loadPendingApprovals() {
        this.isLoading = true;
        getPendingApprovals()
            .then(data => {
                this.pendingRequests = data.map(r => ({
                    ...r,
                    hasBudget: r.Budget__c != null,
                    hasPolicyViolation: r.Policy_Validation_Status__c === 'Warning' || r.Policy_Validation_Status__c === 'Policy Violation',
                    policyClass: this.getBadgeClassForPolicy(r.Policy_Validation_Status__c)
                }));
                this.isLoading = false;
            })
            .catch(error => {
                this.isLoading = false;
                this.showToast('Error', error.body ? error.body.message : error.message, 'error');
            });
    }

    getBadgeClassForPolicy(status) {
        if (status === 'Compliant') return 'slds-badge slds-theme_success';
        if (status === 'Warning') return 'slds-badge slds-theme_warning';
        if (status === 'Policy Violation') return 'slds-badge slds-theme_error';
        return 'slds-badge';
    }

    handleOpenActionModal(event) {
        this.selectedRequestId = event.target.dataset.id;
        this.selectedAction = event.target.dataset.action;
        this.actionComments = '';
        this.isActionModalOpen = true;
    }

    handleCloseActionModal() {
        this.isActionModalOpen = false;
    }

    handleCommentChange(event) {
        this.actionComments = event.target.value;
    }

    handleConfirmDecision() {
        this.isLoading = true;
        this.isActionModalOpen = false;

        processManagerApproval({
            requestId: this.selectedRequestId,
            decision: this.selectedAction,
            comments: this.actionComments
        })
            .then(() => {
                this.isLoading = false;
                this.showToast('Success', `Travel request decision recorded: ${this.selectedAction}`, 'success');
                this.loadPendingApprovals();
            })
            .catch(error => {
                this.isLoading = false;
                this.showToast('Approval Action Error', error.body ? error.body.message : error.message, 'error');
            });
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}
