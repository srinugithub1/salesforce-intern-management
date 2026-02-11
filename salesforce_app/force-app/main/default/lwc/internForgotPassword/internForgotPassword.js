import { LightningElement, track } from 'lwc';

export default class InternForgotPassword extends LightningElement {
    @track email = '';
    @track college = '';
    @track isLoading = false;
    @track isSuccess = false;

    get buttonLabel() {
        return this.isLoading ? 'Sending...' : 'Submit Request';
    }

    handleInput(event) {
        const field = event.target.dataset.id;
        if (field === 'email') this.email = event.target.value;
        if (field === 'college') this.college = event.target.value;
    }

    handleSubmit() {
        if (!this.email || !this.college) {
            // Simple validation feedback (could use toast)
            // For this UI, maybe shake input? But simple alert/console for now or just ignore
            return;
        }

        this.isLoading = true;
        // Simulate Server Call
        setTimeout(() => {
            this.isLoading = false;
            this.isSuccess = true;
        }, 1500);
    }

    handleBackToLogin() {
        // Dispatch event to parent to switch back to login view
        this.dispatchEvent(new CustomEvent('navigatetologin'));
    }
}
