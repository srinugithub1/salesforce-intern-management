import { LightningElement, track } from 'lwc';
import login from '@salesforce/apex/AdminAuthController.login';
import registerAdmin from '@salesforce/apex/AdminAuthController.registerAdmin';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class LandingAdminLogin extends LightningElement {
    @track currentView = 'login'; // 'login' or 'register'
    @track isLoading = false;
    @track error = '';
    @track successMessage = '';
    @track rememberMe = false;

    email = '';
    password = '';

    @track regData = {
        name: '',
        email: '',
        password: '',
        role: 'Team Lead'
    };

    // Computed Properties
    get roleOptions() {
        return [
            { label: 'Super Admin', value: 'Super Admin' },
            { label: 'Team Lead', value: 'Team Lead' },
            { label: 'HR Manager', value: 'HR Manager' },
            { label: 'Department Head', value: 'Department Head' }
        ];
    }

    get isLoginView() {
        return this.currentView === 'login';
    }

    get isRegisterView() {
        return this.currentView === 'register';
    }

    get headerTitle() {
        return this.isLoginView ? 'Admin Portal' : 'Admin Registration';
    }

    get subtitle() {
        return this.isLoginView
            ? 'Secure Access to Administrative Dashboard'
            : 'Create Your Administrative Account';
    }

    get cardClass() {
        return `glass-card ${this.currentView === 'login' ? 'login-mode' : 'register-mode'} fade-in`;
    }

    // View Switching
    showRegister() {
        this.currentView = 'register';
        this.clearMessages();
        this.resetForm();
    }

    showLogin() {
        this.currentView = 'login';
        this.clearMessages();
        this.resetForm();
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

    handleRememberMe(event) {
        this.rememberMe = event.target.checked;
    }

    handleForgotPassword() {
        this.showToast('Info', 'Please contact your system administrator to reset your password.', 'info');
    }

    // Form Submission
    handleFormSubmit(event) {
        event.preventDefault();
        if (this.isLoginView) {
            this.handleLogin();
        } else {
            this.handleRegister();
        }
    }

    // Validation
    validateInputs() {
        const inputs = [...this.template.querySelectorAll('input, lightning-combobox')];
        return inputs.reduce((validSoFar, inputCmp) => {
            if (inputCmp.tagName.toLowerCase() === 'input') {
                // Native input validation
                const isValid = inputCmp.checkValidity();
                if (!isValid) {
                    inputCmp.reportValidity();
                }
                return validSoFar && isValid;
            } else {
                // Lightning combobox validation
                inputCmp.reportValidity();
                return validSoFar && inputCmp.checkValidity();
            }
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

            // Success
            this.successMessage = 'Login successful! Redirecting...';
            this.showToast('Success', 'Welcome back, Admin!', 'success');

            // Dispatch login event to parent
            this.dispatchEvent(new CustomEvent('login', {
                detail: {
                    token: result.Session_Token__c,
                    name: result.Name,
                    role: result.Role__c,
                    email: result.Email__c
                }
            }));

            // Store remember me preference
            if (this.rememberMe) {
                localStorage.setItem('adminEmail', this.email);
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
            await registerAdmin(this.regData);

            this.successMessage = 'Registration successful! You can now login.';
            this.showToast('Success', 'Admin account created successfully!', 'success');

            // Switch to login view after 2 seconds
            setTimeout(() => {
                this.email = this.regData.email;
                this.showLogin();
            }, 2000);

        } catch (error) {
            const errorMessage = error.body?.message || error.message || 'Registration failed';
            this.error = `Registration failed: ${errorMessage}`;
            this.showToast('Error', 'Unable to create account', 'error');
            console.error('Registration error:', error);
        } finally {
            this.isLoading = false;
        }
    }

    // Helper Methods
    clearMessages() {
        this.error = '';
        this.successMessage = '';
    }

    resetForm() {
        this.email = '';
        this.password = '';
        this.regData = {
            name: '',
            email: '',
            password: '',
            role: 'Team Lead'
        };
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
        const savedEmail = localStorage.getItem('adminEmail');
        if (savedEmail) {
            this.email = savedEmail;
            this.rememberMe = true;
        }
    }
}
