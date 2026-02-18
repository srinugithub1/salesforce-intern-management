import { LightningElement } from 'lwc';
import validateSession from '@salesforce/apex/InternAuthController.validateSession';
import logout from '@salesforce/apex/InternAuthController.logout';

export default class LandingInternApp extends LightningElement {
    isAuthenticated = false;
    isCheckingSession = true;
    sessionToken;
    internName;

    // View State: 'login' or 'register'
    currentView = 'login';

    connectedCallback() {
        this.checkSession();
    }

    get isLoginView() {
        return this.currentView === 'login';
    }

    get isRegisterView() {
        return this.currentView === 'register';
    }

    get isForgotPasswordView() {
        return this.currentView === 'forgotpassword';
    }

    async checkSession() {
        const token = localStorage.getItem('intern_session_token');
        const savedName = localStorage.getItem('intern_name');

        if (token) {
            try {
                const intern = await validateSession({ token });
                if (intern) {
                    this.sessionToken = token;
                    this.internName = intern.Name;
                    localStorage.setItem('intern_name', intern.Name);
                    this.isAuthenticated = true;
                    this.dispatchEvent(new CustomEvent('authenticated'));
                } else {
                    // Token explicitly invalid (not an error, just not found)
                    localStorage.removeItem('intern_session_token');
                    localStorage.removeItem('intern_name');
                }
            } catch (e) {
                console.error('Session check failed', e);
                const msg = e.message || (e.body ? e.body.message : '');

                // If busy/quota, trust the existing token and saved name
                if (msg.includes('429') || msg.includes('Quota') || msg.includes('Limit') || msg.includes('busy')) {
                    this.sessionToken = token;
                    this.internName = savedName || 'Intern';
                    this.isAuthenticated = true;
                    this.dispatchEvent(new CustomEvent('authenticated'));
                } else {
                    // For other hard errors, maybe keep them at login but don't delete token?
                    // Actually, if we don't set authenticated=true, they see login.
                }
            }
        }
        this.isCheckingSession = false;
    }

    handleLogin(event) {
        const { token, name } = event.detail;
        this.sessionToken = token;
        this.internName = name;
        localStorage.setItem('intern_session_token', token);
        localStorage.setItem('intern_name', name);
        this.isAuthenticated = true;

        // Notify parent that authentication succeeded
        this.dispatchEvent(new CustomEvent('authenticated'));
    }

    async handleLogout() {
        if (this.sessionToken) {
            try {
                await logout({ token: this.sessionToken });
            } catch (e) {
                console.error(e);
            }
        }
        localStorage.removeItem('intern_session_token');
        localStorage.removeItem('intern_name');
        this.sessionToken = null;
        this.internName = null;
        this.isAuthenticated = false;

        // Redirect to main landing page
        this.dispatchEvent(new CustomEvent('backtolanding'));
    }

    handleBackToLanding() {
        // Pass the backtolanding event up to parent (landingPage)
        this.dispatchEvent(new CustomEvent('backtolanding'));
    }
}