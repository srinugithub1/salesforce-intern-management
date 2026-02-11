import { LightningElement, track } from 'lwc';
import registerIntern from '@salesforce/apex/InternAuthController.registerIntern';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { NavigationMixin } from 'lightning/navigation';
import LightningAlert from 'lightning/alert';

// window.alert('Signup Component Version: 1.0.3 Loaded');

export default class InternSignup extends NavigationMixin(LightningElement) {
    @track isLoading = false;
    @track errorMsg = ''; // Inline error message support
    @track successMsg = ''; // Inline success message support

    // Form Data
    formData = {
        firstName: '',
        lastName: '',
        email: '',
        phone: '',
        rollNo: '',
        college: '',
        address: '',
        password: ''
    };

    get buttonLabel() {
        return this.isLoading ? 'Registering...' : 'Sign Up';
    }

    handleInput(event) {
        const field = event.target.dataset.id;
        // Map data-id to formData keys
        const map = {
            'fname': 'firstName',
            'lname': 'lastName',
            'email': 'email',
            'phone': 'phone',
            'rollNo': 'rollNo',
            'college': 'college',
            'address': 'address',
            'password': 'password'
        };

        if (map[field]) {
            this.formData[map[field]] = event.target.value;
        }
    }

    handleSignup() {
        console.log('--- Handle Signup Start ---');
        // alert('Registration starting for: ' + this.formData.email);

        this.errorMsg = ''; // Reset messages
        this.successMsg = '';

        console.log('Form Data State:', JSON.stringify(this.formData));
        if (!this.formData.lastName || !this.formData.email || !this.formData.phone || !this.formData.password) {
            this.showToast('Error', 'Please fill all required fields (Last Name, Email, Phone, Password).', 'error');
            return;
        }

        this.isLoading = true;

        registerIntern({
            firstName: this.formData.firstName,
            lastName: this.formData.lastName,
            email: this.formData.email,
            phone: this.formData.phone,
            password: this.formData.password,
            college: this.formData.college,
            rollNo: this.formData.rollNo,
            address: this.formData.address
        })
            .then(() => {
                console.log('Registration Apex Success');
                this.successMsg = 'Registration Successful! Redirecting to Login...';
                alert('Success! Registration completed. Redirecting...');
                this.showToast('Success', this.successMsg, 'success');

                // Wait a moment for the toast then redirect
                setTimeout(() => {
                    this.navigateToLogin();
                }, 2000);
            })
            .catch(async (error) => {
                console.error('Registration Exception caught:', error);

                let message = 'An unexpected error occurred';

                if (error.body) {
                    if (Array.isArray(error.body)) {
                        message = error.body.map(e => e.message).join(', ');
                    } else if (typeof error.body.message === 'string') {
                        message = error.body.message;
                    } else if (error.body.pageErrors && error.body.pageErrors.length > 0) {
                        message = error.body.pageErrors[0].message;
                    } else {
                        message = JSON.stringify(error.body);
                    }
                } else if (error.message) {
                    message = error.message;
                } else if (typeof error === 'string') {
                    message = error;
                }

                console.error('Final Extracted Message:', message);
                this.errorMsg = message;
                this.isLoading = false;

                // High-visibility Alert
                await LightningAlert.open({
                    message: message,
                    label: 'Registration Error',
                    theme: 'error',
                });
            });
    }

    navigateToLogin() {
        // Navigate to the 'internLogin' page. 
        // In Experience Cloud, standard comm_namedPage is often used.
        // Or if it is the home page, home.

        // Try standard navigation first
        this[NavigationMixin.Navigate]({
            type: 'comm__namedPage',
            attributes: {
                name: 'Login'
            }
        });

        // Fallback or if using custom component on same page:
        // Dispatch event if parent is handling visibility (SPA style)
        // Check if we are in an SPA container. If standalone, NavMixin handles it.
        const event = new CustomEvent('navigatetologin');
        this.dispatchEvent(event);
    }

    showToast(title, message, variant) {
        const event = new ShowToastEvent({
            title: title,
            message: message,
            variant: variant,
            mode: 'dismissable'
        });
        this.dispatchEvent(event);
    }
}
