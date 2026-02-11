import { LightningElement, track } from 'lwc';
import login from '@salesforce/apex/InternAuthController.login';
import registerIntern from '@salesforce/apex/InternAuthController.registerIntern';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import LightningAlert from 'lightning/alert';

export default class LandingInternLogin extends LightningElement {
    @track currentView = 'login'; // 'login', 'register', 'forgot'
    @track isLoading = false;
    @track error = '';
    @track successMessage = '';
    @track rememberMe = false;

    // Login Data
    email = '';
    password = '';

    // Register Data
    @track regData = {
        firstName: '',
        lastName: '',
        email: '',
        phone: '',
        rollNo: '',
        college: '',
        address: '',
        password: ''
    };

    // Forgot Password Data
    forgotEmail = '';
    forgotCollege = '';
    @track isForgotSuccess = false;

    // Computed Properties
    get isLoginView() {
        return this.currentView === 'login';
    }

    get isRegisterView() {
        return this.currentView === 'register';
    }

    get isForgotView() {
        return this.currentView === 'forgot';
    }

    get headerTitle() {
        if (this.isLoginView) return 'Student Portal';
        if (this.isRegisterView) return 'Intern Registration';
        if (this.isForgotView) return 'Reset Password';
        return 'Student Portal';
    }

    get subtitle() {
        if (this.isLoginView) return 'Sign in to access your internship dashboard';
        if (this.isRegisterView) return 'Create your intern account and start your journey';
        if (this.isForgotView) return 'Recover access to your account';
        return 'Welcome Back';
    }

    get cardClass() {
        const baseClass = 'glass-card';
        const viewClass = this.isRegisterView ? 'wide-card' : '';
        return `${baseClass} ${viewClass} fade-in`.trim();
    }

    // View Switching
    showLogin() {
        this.currentView = 'login';
        this.clearMessages();
        this.isForgotSuccess = false;
    }

    showRegister() {
        this.currentView = 'register';
        this.clearMessages();
    }

    showForgot() {
        this.currentView = 'forgot';
        this.clearMessages();
        this.isForgotSuccess = false;
    }

    // Input Handlers
    handleLoginInput(event) {
        const field = event.target.dataset.id;
        if (field === 'email') {
            this.email = event.target.value;
        } else if (field === 'password') {
            this.password = event.target.value;
        }
        this.clearMessages();
    }

    handleRegisterInput(event) {
        const field = event.target.dataset.id;
        this.regData = { ...this.regData, [field]: event.target.value };
        this.clearMessages();
    }

    handleForgotInput(event) {
        const field = event.target.dataset.id;
        if (field === 'email') {
            this.forgotEmail = event.target.value;
        } else if (field === 'college') {
            this.forgotCollege = event.target.value;
        }
        this.clearMessages();
    }

    handleRememberMe(event) {
        this.rememberMe = event.target.checked;
    }

    // Form Submission
    handleFormSubmit(event) {
        event.preventDefault();
        if (this.isLoginView) {
            this.handleLogin();
        } else if (this.isRegisterView) {
            this.handleRegister();
        } else if (this.isForgotView) {
            this.handleForgotSubmit();
        }
    }

    // Validation
    validateInputs() {
        const inputs = [...this.template.querySelectorAll('input[required]')];
        return inputs.reduce((validSoFar, inputCmp) => {
            const isValid = inputCmp.checkValidity();
            if (!isValid) {
                inputCmp.reportValidity();
            }
            return validSoFar && isValid;
        }, true);
    }

    // Login Handler
    async handleLogin() {
        if (!this.validateInputs()) {
            this.error = 'Please fill in all required fields';
            return;
        }

        this.isLoading = true;
        this.clearMessages();

        try {
            const result = await login({
                email: this.email,
                password: this.password
            });

            this.successMessage = 'Login successful! Redirecting...';
            this.showToast('Success', 'Welcome back!', 'success');

            // Dispatch login event to parent
            this.dispatchEvent(new CustomEvent('login', {
                detail: {
                    token: result.Session_Token__c,
                    name: result.Name,
                    email: this.email
                }
            }));

            // Store remember me preference
            if (this.rememberMe) {
                localStorage.setItem('internEmail', this.email);
            }

        } catch (error) {
            this.error = 'Invalid email or password. Please try again.';
            this.showToast('Error', 'Authentication failed', 'error');
            console.error('Login error:', error);
        } finally {
            this.isLoading = false;
        }
    }

    // Register Handler
    async handleRegister() {
        if (!this.validateInputs()) {
            this.error = 'Please fill in all required fields';
            this.showToast('Error', 'Please fill all required fields correctly', 'error');
            return;
        }

        // Password validation
        if (this.regData.password.length < 6) {
            this.error = 'Password must be at least 6 characters long';
            return;
        }

        this.isLoading = true;
        this.clearMessages();

        try {
            await registerIntern(this.regData);

            this.successMessage = 'Registration successful! You can now login.';

            // Show success alert
            await LightningAlert.open({
                message: 'Welcome aboard! Your intern account has been successfully created. You can now sign in using your email and password.',
                label: 'Registration Successful',
                theme: 'success'
            });

            this.showToast('Success', 'Account created successfully!', 'success');

            // Switch to login view after 2 seconds
            setTimeout(() => {
                this.email = this.regData.email;
                this.showLogin();
            }, 2000);

        } catch (error) {
            console.error('Detailed Registration Error:', JSON.parse(JSON.stringify(error)));

            let errorMessage = 'Give me your Registered Email address.';

            try {
                if (error.body) {
                    if (Array.isArray(error.body)) {
                        errorMessage = error.body.map(err => err.message).join(', ');
                    } else if (typeof error.body.message === 'string' && error.body.message !== 'Script-thrown exception') {
                        errorMessage = error.body.message;
                    } else if (error.body.pageErrors && error.body.pageErrors.length > 0) {
                        errorMessage = error.body.pageErrors[0].message;
                    } else if (error.body.fieldErrors && Object.keys(error.body.fieldErrors).length > 0) {
                        const firstField = Object.keys(error.body.fieldErrors)[0];
                        errorMessage = error.body.fieldErrors[firstField][0].message;
                    }
                } else if (error.message) {
                    errorMessage = error.message;
                }
            } catch (parseErr) {
                console.error('Error parsing registration failure:', parseErr);
            }

            // Final sanitize
            if (errorMessage === 'Script-thrown exception' || !errorMessage || errorMessage.includes('Generic')) {
                errorMessage = 'Give me your Registered Email address.';
            }

            this.error = `Registration failed: ${errorMessage}`;
            this.showToast('Error', 'Unable to create account', 'error');

            try {
                await LightningAlert.open({
                    message: errorMessage,
                    label: 'Registration Issue',
                    theme: 'error'
                });
            } catch (alertErr) {
                console.error('Alert error:', alertErr);
            }
        } finally {
            this.isLoading = false;
        }
    }

    // Forgot Password Handler
    handleForgotSubmit() {
        if (!this.validateInputs()) {
            this.error = 'Please fill in all required fields';
            return;
        }

        this.isLoading = true;
        this.clearMessages();

        // Simulate API call (replace with actual implementation)
        setTimeout(() => {
            this.isLoading = false;
            this.isForgotSuccess = true;
            this.showToast('Success', 'Password reset email sent!', 'success');
        }, 1500);
    }

    // Helper Methods
    clearMessages() {
        this.error = '';
        this.successMessage = '';
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({
            title,
            message,
            variant
        }));
    }

    handleBackToLanding() {
        // Fire event to parent component to return to landing page
        this.dispatchEvent(new CustomEvent('backtolanding'));
    }

    // Lifecycle Hooks
    connectedCallback() {
        // Check for remembered email
        const savedEmail = localStorage.getItem('internEmail');
        if (savedEmail) {
            this.email = savedEmail;
            this.rememberMe = true;
        }
    }
}
