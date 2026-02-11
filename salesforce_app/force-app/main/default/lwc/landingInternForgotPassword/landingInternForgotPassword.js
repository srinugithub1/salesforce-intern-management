import { LightningElement, track } from 'lwc';

export default class LandingInternForgotPassword extends LightningElement {
    @track email = '';
    @track college = '';
    @track isLoading = false;
    @track isSuccess = false;
    @track errorMsg = '';

    handleInput(event) {
        const field = event.target.dataset.id;
        if (field === 'email') this.email = event.target.value;
        if (field === 'college') this.college = event.target.value;

        // Clear error message on input
        this.errorMsg = '';
    }

    handleFormSubmit(event) {
        event.preventDefault();
        this.handleSubmit();
    }

    handleSubmit() {
        // Clear previous error
        this.errorMsg = '';

        // Validation
        if (!this.email || !this.college) {
            this.errorMsg = 'Please fill in all required fields.';
            return;
        }

        // Basic email validation
        const emailPattern = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
        if (!emailPattern.test(this.email)) {
            this.errorMsg = 'Please enter a valid email address.';
            return;
        }

        this.isLoading = true;

        // Simulate Server Call
        // In production, this would call an Apex method
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
