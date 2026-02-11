import { LightningElement, track } from 'lwc';
import login from '@salesforce/apex/AdminAuthController.login';
import registerAdmin from '@salesforce/apex/AdminAuthController.registerAdmin';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class AdminLogin extends LightningElement {
    @track currentView = 'login'; // 'login', 'register'
    @track isLoading = false;
    @track error = '';

    email = '';
    password = '';

    @track regData = {
        name: '',
        email: '',
        password: '',
        role: 'Team Lead'
    };

    get roleOptions() {
        return [
            { label: 'Super Admin', value: 'Super Admin' },
            { label: 'Team Lead', value: 'Team Lead' }
        ];
    }

    get isLoginView() { return this.currentView === 'login'; }
    get isRegisterView() { return this.currentView === 'register'; }

    get loginBtnLabel() { return this.isLoading ? 'Processing...' : 'Secure Login'; }
    get registerBtnLabel() { return this.isLoading ? 'Creating Account...' : 'Sign Up as Admin'; }

    get subtitle() {
        return this.isLoginView ? 'Secure Access Control' : 'Create Admin Account';
    }

    get cardClass() {
        return 'glass-card animate-fade';
    }

    showRegister() { this.currentView = 'register'; this.error = ''; }
    showLogin() { this.currentView = 'login'; this.error = ''; }

    handleLoginInput(event) {
        const field = event.target.dataset.id;
        if (field === 'email') this.email = event.target.value;
        if (field === 'password') this.password = event.target.value;
    }

    handleRegisterInput(event) {
        const field = event.target.dataset.id;
        this.regData = { ...this.regData, [field]: event.target.value };
    }

    validateInputs() {
        const inputs = [...this.template.querySelectorAll('lightning-input')];
        return inputs.reduce((validSoFar, inputCmp) => {
            inputCmp.reportValidity();
            return validSoFar && inputCmp.checkValidity();
        }, true);
    }

    async handleLogin() {
        if (!this.validateInputs()) return;

        this.isLoading = true;
        this.error = '';
        try {
            const result = await login({ email: this.email, password: this.password });
            this.dispatchEvent(new CustomEvent('login', {
                detail: { token: result.Session_Token__c, name: result.Name, role: result.Role__c }
            }));
        } catch (e) {
            this.error = 'Invalid Credentials';
            console.error(e);
        } finally {
            this.isLoading = false;
        }
    }

    async handleRegister() {
        if (!this.validateInputs()) return;

        this.isLoading = true;
        this.error = '';
        try {
            await registerAdmin(this.regData);
            this.showToast('Success', 'Admin Registered Successfully! Please login.', 'success');
            setTimeout(() => {
                this.showLogin();
            }, 2000);
        } catch (e) {
            this.error = 'Registration Failed: ' + (e.body ? e.body.message : e.message);
            console.error(e);
        } finally {
            this.isLoading = false;
        }
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}
