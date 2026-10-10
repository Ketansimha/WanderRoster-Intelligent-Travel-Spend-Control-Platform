import { LightningElement, track } from 'lwc';
import getReportsForReview from '@salesforce/apex/ExpenseReviewController.getReportsForReview';
import getItemsForReport from '@salesforce/apex/ExpenseReviewController.getItemsForReport';
import reviewExpenseItem from '@salesforce/apex/ExpenseReviewController.reviewExpenseItem';
import updateReimbursementStatus from '@salesforce/apex/ExpenseReviewController.updateReimbursementStatus';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class FinanceReviewWorkspace extends LightningElement {
    @track reports = [];
    @track selectedReport = null;
    @track selectedReportItems = [];
    @track isLoading = false;

    @track isItemModalOpen = false;
    @track selectedItemId = null;
    @track selectedAction = '';
    @track modalApprovedAmount = 0;
    @track modalComments = '';

    connectedCallback() {
        this.loadReports();
    }

    get hasReports() {
        return this.reports && this.reports.length > 0;
    }

    get isReadyForPayment() {
        return this.selectedReport && this.selectedReport.Reimbursement_Status__c === 'Ready for Payment';
    }

    get isPartialApprove() {
        return this.selectedAction === 'Partial Approved';
    }

    get itemModalTitle() {
        if (this.selectedAction === 'Approved') return 'Approve Expense Item (Full Amount)';
        if (this.selectedAction === 'Partial Approved') return 'Partially Approve Expense Item';
        if (this.selectedAction === 'Rejected') return 'Reject Expense Item';
        return 'Review Item';
    }

    loadReports() {
        this.isLoading = true;
        getReportsForReview()
            .then(data => {
                this.reports = data.map(r => ({
                    ...r,
                    reimbursementBadgeClass: this.getReimbursementBadge(r.Reimbursement_Status__c)
                }));
                this.isLoading = false;
            })
            .catch(error => {
                this.isLoading = false;
                this.showToast('Error Loading Reports', error.body ? error.body.message : error.message, 'error');
            });
    }

    getReimbursementBadge(status) {
        if (status === 'Paid') return 'slds-badge slds-theme_success';
        if (status === 'Ready for Payment') return 'slds-badge slds-theme_warning';
        if (status === 'Approved') return 'slds-badge slds-theme_success';
        if (status === 'Rejected') return 'slds-badge slds-theme_error';
        return 'slds-badge';
    }

    handleSelectReport(event) {
        const reportId = event.target.dataset.id;
        this.selectedReport = this.reports.find(r => r.Id === reportId);
        this.loadReportItems(reportId);
    }

    handleBackToList() {
        this.selectedReport = null;
        this.selectedReportItems = [];
        this.loadReports();
    }

    loadReportItems(reportId) {
        this.isLoading = true;
        getItemsForReport({ reportId: reportId })
            .then(data => {
                this.selectedReportItems = data.map(itm => ({
                    ...itm,
                    reviewBadgeClass: this.getReviewBadge(itm.Review_Status__c),
                    verificationBadgeClass: this.getVerificationBadge(itm.Receipt_Verification_Status__c)
                }));
                this.isLoading = false;
            })
            .catch(error => {
                this.isLoading = false;
                this.showToast('Error Loading Items', error.body ? error.body.message : error.message, 'error');
            });
    }

    getReviewBadge(status) {
        if (status === 'Approved') return 'slds-badge slds-theme_success';
        if (status === 'Partial Approved') return 'slds-badge slds-theme_warning';
        if (status === 'Rejected') return 'slds-badge slds-theme_error';
        return 'slds-badge';
    }

    getVerificationBadge(status) {
        if (status === 'Verified') return 'slds-badge slds-theme_success slds-m-left_x-small';
        if (status === 'Discrepancy Flagged') return 'slds-badge slds-theme_warning slds-m-left_x-small';
        if (status === 'Duplicate Suspected') return 'slds-badge slds-theme_error slds-m-left_x-small';
        if (status === 'Policy Limit Exceeded') return 'slds-badge slds-theme_error slds-m-left_x-small';
        return 'slds-badge slds-m-left_x-small';
    }

    handleOpenLineItemModal(event) {
        this.selectedItemId = event.target.dataset.id;
        this.selectedAction = event.target.dataset.action;
        const currentItem = this.selectedReportItems.find(i => i.Id === this.selectedItemId);
        this.modalApprovedAmount = currentItem ? currentItem.Claimed_Amount__c : 0;
        this.modalComments = '';
        this.isItemModalOpen = true;
    }

    handleCloseItemModal() {
        this.isItemModalOpen = false;
    }

    handleApprovedAmountChange(event) {
        this.modalApprovedAmount = parseFloat(event.target.value) || 0;
    }

    handleCommentsChange(event) {
        this.modalComments = event.target.value;
    }

    handleConfirmItemReview() {
        this.isLoading = true;
        this.isItemModalOpen = false;

        reviewExpenseItem({
            expenseItemId: this.selectedItemId,
            reviewStatus: this.selectedAction,
            approvedAmount: this.modalApprovedAmount,
            comments: this.modalComments
        })
            .then(() => {
                this.showToast('Item Reviewed', `Determination saved: ${this.selectedAction}`, 'success');
                return getReportsForReview();
            })
            .then(data => {
                this.reports = data;
                if (this.selectedReport) {
                    this.selectedReport = this.reports.find(r => r.Id === this.selectedReport.Id);
                }
                this.loadReportItems(this.selectedReport.Id);
            })
            .catch(error => {
                this.isLoading = false;
                this.showToast('Error', error.body ? error.body.message : error.message, 'error');
            });
    }

    handleMarkPaid() {
        this.isLoading = true;
        updateReimbursementStatus({
            reportId: this.selectedReport.Id,
            reimbursementStatus: 'Paid'
        })
            .then(updated => {
                this.isLoading = false;
                this.showToast('Reimbursement Finalized', 'Reimbursement confirmed as Paid. Actual trip costs and budgets updated.', 'success');
                this.handleBackToList();
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
