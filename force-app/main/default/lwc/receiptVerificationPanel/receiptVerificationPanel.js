import { LightningElement, api } from 'lwc';
import attachReceiptAndVerify from '@salesforce/apex/ExpenseReviewController.attachReceiptAndVerify';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class ReceiptVerificationPanel extends LightningElement {
    @api item;

    get isFlagged() {
        return this.item && (
            this.item.Receipt_Verification_Status__c === 'Discrepancy Flagged' ||
            this.item.Receipt_Verification_Status__c === 'Duplicate Suspected' ||
            this.item.Receipt_Verification_Status__c === 'Policy Limit Exceeded' ||
            this.item.Receipt_Verification_Status__c === 'Human Review Required'
        );
    }

    get complianceBadgeClass() {
        if (!this.item) return 'slds-badge';
        const st = this.item.Receipt_Compliance_Status__c;
        if (st === 'On-Time') return 'slds-badge slds-theme_success';
        if (st === 'Overdue') return 'slds-badge slds-theme_error';
        if (st === 'Missing Receipt') return 'slds-badge slds-theme_warning';
        return 'slds-badge';
    }

    get verificationBadgeClass() {
        if (!this.item) return 'slds-badge slds-m-left_x-small';
        const st = this.item.Receipt_Verification_Status__c;
        if (st === 'Verified') return 'slds-badge slds-theme_success slds-m-left_x-small';
        if (st === 'Discrepancy Flagged') return 'slds-badge slds-theme_warning slds-m-left_x-small';
        if (st === 'Duplicate Suspected') return 'slds-badge slds-theme_error slds-m-left_x-small';
        if (st === 'Policy Limit Exceeded') return 'slds-badge slds-theme_error slds-m-left_x-small';
        return 'slds-badge slds-m-left_x-small';
    }

    handleUploadFinished(event) {
        const uploadedFiles = event.detail.files;
        if (uploadedFiles && uploadedFiles.length > 0) {
            const docId = uploadedFiles[0].documentId;
            attachReceiptAndVerify({
                expenseItemId: this.item.Id,
                contentDocumentId: docId,
                extractedReceiptAmount: this.item.Claimed_Amount__c
            })
                .then(updatedItem => {
                    this.item = updatedItem;
                    this.dispatchEvent(new ShowToastEvent({
                        title: 'Receipt Uploaded',
                        message: 'Receipt attached and automated risk verification re-run successfully.',
                        variant: 'success'
                    }));
                    this.dispatchEvent(new CustomEvent('refresh'));
                })
                .catch(error => {
                    this.dispatchEvent(new ShowToastEvent({
                        title: 'Error Attaching Receipt',
                        message: error.body ? error.body.message : error.message,
                        variant: 'error'
                    }));
                });
        }
    }
}
