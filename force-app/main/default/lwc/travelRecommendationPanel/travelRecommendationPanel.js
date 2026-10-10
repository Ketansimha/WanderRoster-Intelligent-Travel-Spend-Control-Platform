import { LightningElement, api } from 'lwc';

export default class TravelRecommendationPanel extends LightningElement {
    @api recommendations = null;

    get hasData() {
        return this.recommendations && this.recommendations.items && this.recommendations.items.length > 0;
    }
}
