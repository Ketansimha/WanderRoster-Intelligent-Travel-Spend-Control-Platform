import { LightningElement, track } from 'lwc';
import getDashboardMetrics from '@salesforce/apex/TravelDashboardController.getDashboardMetrics';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class FinancialIntelligenceDashboard extends LightningElement {
    @track metrics = {};
    @track departmentBreakdown = [];
    @track isLoading = false;

    connectedCallback() {
        this.loadMetrics();
    }

    loadMetrics() {
        this.isLoading = true;
        getDashboardMetrics()
            .then(data => {
                this.metrics = data;
                if (data.departmentBreakdown) {
                    this.departmentBreakdown = data.departmentBreakdown.map(d => {
                        const spentAndCommitted = (d.committed || 0) + (d.recorded || 0);
                        const pct = d.allocated > 0 ? ((spentAndCommitted / d.allocated) * 100).toFixed(1) : '0';
                        return {
                            ...d,
                            utilizationPct: pct
                        };
                    });
                }
                this.isLoading = false;
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
