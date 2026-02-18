import { LightningElement, track } from 'lwc';
import registerIntern from '@salesforce/apex/InternAuthController.registerIntern';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { NavigationMixin } from 'lightning/navigation';

export default class LandingInternSignup extends NavigationMixin(LightningElement) {
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

        // Clear messages on input
        this.errorMsg = '';
        this.successMsg = '';
    }

    handleFormSubmit(event) {
        event.preventDefault();
        this.handleSignup();
    }

    async handleSignup() {
        console.log('--- Handle Signup Async Start (Reverted to Void/Exception) ---');

        this.errorMsg = '';
        this.successMsg = '';

        // Basic Client-side validation
        if (!this.formData.lastName || !this.formData.email || !this.formData.phone || !this.formData.password) {
            this.errorMsg = 'Please fill all required fields (Last Name, Email, Phone, Password).';
            return;
        }

        this.isLoading = true;

        try {
            // Apex now returns void. Logic errors throw Exceptions.
            await registerIntern({
                firstName: this.formData.firstName,
                lastName: this.formData.lastName,
                email: this.formData.email,
                phone: this.formData.phone,
                password: this.formData.password,
                college: this.formData.college,
                rollNo: this.formData.rollNo,
                address: this.formData.address
            });

            console.log('Registration Success (Void Return)');
            this.successMsg = 'Registration Successful! Redirecting to Login...';
            this.isLoading = false;
            setTimeout(() => { this.navigateToLogin(); }, 2000);

        } catch (error) {
            console.error('Registration Exception:', error);
            this.isLoading = false;

            // Extract User-Friendly Message from Exception
            let message = 'An unexpected system error occurred';
            if (error.body) {
                if (Array.isArray(error.body)) message = error.body.map(e => e.message).join(', ');
                else if (typeof error.body.message === 'string') message = error.body.message;
                else if (error.body.pageErrors && error.body.pageErrors.length > 0) message = error.body.pageErrors[0].message;
                // If the backend throws AuraHandledException('Message'), it often appears in error.body.message
                else message = JSON.stringify(error.body);
            } else if (error.message) {
                message = error.message;
            } else if (typeof error === 'string') {
                message = error;
            }

            // Clean up standard Salesforce error prefixes if present
            if (message && message.includes('Script-thrown exception')) {
                message = message.replace('Script-thrown exception', '').trim();
            }

            this.errorMsg = message;

        } finally {
            if (!this.successMsg) {
                this.isLoading = false;
            }
        }
    }

    navigateToLogin() {
        // Navigate to the 'internLogin' page. 
        this[NavigationMixin.Navigate]({
            type: 'comm__namedPage',
            attributes: {
                name: 'Login'
            }
        });

        // Fallback or if using custom component on same page:
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
