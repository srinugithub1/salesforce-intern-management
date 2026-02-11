import { LightningElement } from 'lwc';
import validateSession from '@salesforce/apex/InternAuthController.validateSession';
import logout from '@salesforce/apex/InternAuthController.logout';

export default class InternApp extends LightningElement {
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
        if (token) {
            try {
                const intern = await validateSession({ token });
                if (intern) {
                    this.sessionToken = token;
                    this.internName = intern.Name;
                    this.isAuthenticated = true;
                } else {
                    localStorage.removeItem('intern_session_token');
                }
            } catch (e) {
                console.error('Session check failed', e);
                localStorage.removeItem('intern_session_token');
            }
        }
        this.isCheckingSession = false;
    }

    handleLogin(event) {
        const { token, name } = event.detail;
        this.sessionToken = token;
        this.internName = name;
        localStorage.setItem('intern_session_token', token);
        this.isAuthenticated = true;
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
        this.sessionToken = null;
        this.internName = null;
        this.isAuthenticated = false;
    }
}