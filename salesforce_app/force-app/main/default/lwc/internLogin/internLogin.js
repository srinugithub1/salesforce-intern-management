import { LightningElement, track } from 'lwc';
import login from '@salesforce/apex/InternAuthController.login';
import registerIntern from '@salesforce/apex/InternAuthController.registerIntern';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import LightningAlert from 'lightning/alert';

export default class InternLogin extends LightningElement {
    @track currentView = 'login'; // 'login', 'register', 'forgot'
    @track isLoading = false;
    @track error = '';

    // Login Data
    email = '';
    password = '';

    // Register Data
    regData = {
        firstName: '', lastName: '', email: '', phone: '',
        rollNo: '', college: '', address: '', password: ''
    };

    // Forgot Password Data
    forgotEmail = '';
    forgotCollege = '';
    @track isForgotSuccess = false;

    // --- Getters ---
    get isLoginView() { return this.currentView === 'login'; }
    get isRegisterView() { return this.currentView === 'register'; }
    get isForgotView() { return this.currentView === 'forgot'; }

    get loginBtnLabel() { return this.isLoading ? 'Signing In...' : 'Login'; }
    get registerBtnLabel() { return this.isLoading ? 'Registering...' : 'Sign Up'; }
    get forgotBtnLabel() { return this.isLoading ? 'Sending...' : 'Submit Request'; }

    get cardClass() {
        return this.isRegisterView ? 'glass-card wide-card' : 'glass-card';
    }

    // --- Navigation ---
    showLogin() { this.currentView = 'login'; this.error = ''; }
    showRegister() { this.currentView = 'register'; this.error = ''; }
    showForgot() { this.currentView = 'forgot'; this.error = ''; this.isForgotSuccess = false; }

    // --- Input Handlers ---
    handleLoginInput(event) {
        const field = event.target.dataset.id;
        if (field === 'email') this.email = event.target.value;
        if (field === 'password') this.password = event.target.value;
    }

    handleRegisterInput(event) {
        const field = event.target.dataset.id;
        // Map simplified IDs to object keys
        const map = {
            'fname': 'firstName', 'lname': 'lastName', 'email': 'email',
            'phone': 'phone', 'rollNo': 'rollNo', 'college': 'college',
            'address': 'address', 'password': 'password'
        };
        if (map[field]) this.regData[map[field]] = event.target.value;
    }

    handleForgotInput(event) {
        const field = event.target.dataset.id;
        if (field === 'email') this.forgotEmail = event.target.value;
        if (field === 'college') this.forgotCollege = event.target.value;
    }

    // --- Helper Validation ---
    validateInputs() {
        const inputs = [...this.template.querySelectorAll('lightning-input')];
        const allValid = inputs.reduce((validSoFar, inputCmp) => {
            inputCmp.reportValidity(); // Shows red border if invalid
            return validSoFar && inputCmp.checkValidity();
        }, true);
        return allValid;
    }

    // --- Actions ---

    async handleLogin() {
        if (!this.validateInputs()) {
            this.showToast('Error', 'Please enter your Details', 'error');
            return;
        }

        this.isLoading = true;
        this.error = '';
        try {
            const result = await login({ email: this.email, password: this.password });
            this.dispatchEvent(new CustomEvent('login', {
                detail: { token: result.Session_Token__c, name: result.Name }
            }));
        } catch (e) {
            console.error(e);
            this.error = 'Invalid Email or Password';
            this.showToast('Error', 'Invalid Email or Password', 'error'); // Also show toast
        } finally {
            this.isLoading = false;
        }
    }

    handleRegister() {
        // Run UI validation first
        if (!this.validateInputs()) {
            this.showToast('Error', 'Please fill all required fields correctly.', 'error');
            return;
        }

        this.isLoading = true;
        registerIntern(this.regData)
            .then(() => {
                console.log('Registration Apex Success');
                this.successMsg = 'Account Created Successfully! You are now ready to log in.';

                // Professional Success Alert
                LightningAlert.open({
                    message: 'Welcome aboard! Your intern account has been successfully created. You can now sign in using your email and password.',
                    label: 'Registration Successful',
                    theme: 'success',
                });

                this.showToast('Success', this.successMsg, 'success');
                this.returnToLoginDelay();
            })
            .catch(async (e) => {
                console.error('Detailed Registration Error:', JSON.parse(JSON.stringify(e)));

                // Set the default to exactly what the user wants
                let msg = 'Give me your Registered Email address.';

                try {
                    if (e.body) {
                        if (Array.isArray(e.body)) {
                            msg = e.body.map(err => err.message).join(', ');
                        } else if (typeof e.body.message === 'string' && e.body.message !== 'Script-thrown exception') {
                            msg = e.body.message;
                        } else if (e.body.pageErrors && e.body.pageErrors.length > 0) {
                            msg = e.body.pageErrors[0].message;
                        } else if (e.body.fieldErrors && Object.keys(e.body.fieldErrors).length > 0) {
                            const firstField = Object.keys(e.body.fieldErrors)[0];
                            msg = e.body.fieldErrors[firstField][0].message;
                        }
                    } else if (e.message) {
                        msg = e.message;
                    }
                } catch (parseErr) {
                    console.error('Error parsing registration failure:', parseErr);
                }

                // Final sanitize: if it's still generic or empty, use the user's preferred message
                if (msg === 'Script-thrown exception' || !msg || msg.includes('Generic')) {
                    msg = 'Give me your Registered Email address.';
                }

                this.error = msg;
                this.isLoading = false;

                try {
                    await LightningAlert.open({
                        message: msg,
                        label: 'Registration Issue',
                        theme: 'error',
                    });
                } catch (alertErr) {
                    window.alert('Registration Issue: ' + msg);
                }

                this.showToast('Registration Error', msg, 'error');
            });

    }

    handleForgotSubmit() {
        if (!this.validateInputs()) {
            return; // Standard validation handles the UI indication
        }

        this.isLoading = true;
        // Simulate API
        setTimeout(() => {
            this.isLoading = false;
            this.isForgotSuccess = true;
        }, 1500);
    }

    returnToLoginDelay() {
        setTimeout(() => {
            this.showLogin();
            this.isLoading = false;
        }, 2000);
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}