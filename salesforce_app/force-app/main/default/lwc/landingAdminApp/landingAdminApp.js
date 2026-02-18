import { LightningElement, track } from 'lwc';
import checkAuth from '@salesforce/apex/AdminAuthController.checkAuth';
import logout from '@salesforce/apex/AdminAuthController.logout';

export default class LandingAdminApp extends LightningElement {
    @track isAuthenticated = false;
    @track isCheckingSession = true;
    @track adminName = '';

    @track token = '';
    @track role = '';

    connectedCallback() {
        const storedToken = localStorage.getItem('admin_token');
        const storedName = localStorage.getItem('admin_name');
        const storedRole = localStorage.getItem('admin_role');

        if (storedToken) {
            this.verifyToken(storedToken, storedName, storedRole);
        } else {
            this.isCheckingSession = false;
        }
    }

    async verifyToken(token, name, role) {
        try {
            const admin = await checkAuth({ token: token });
            if (admin) {
                this.token = token;
                this.adminName = name;
                this.role = admin.Role__c || role;
                this.isAuthenticated = true;

                // Refresh role in storage if it changed
                if (admin.Role__c) {
                    localStorage.setItem('admin_role', admin.Role__c);
                }

                // Notify parent that session is already authenticated
                this.dispatchEvent(new CustomEvent('authenticated'));
            } else {
                this.handleLogout();
            }
        } catch (e) {
            console.error('Admin session check failed', e);
            const msg = e.message || (e.body ? e.body.message : '');

            // If busy/quota/error, trust the existing token and stored data
            if (msg.includes('429') || msg.includes('Quota') || msg.includes('Limit') || msg.includes('Check Failed')) {
                this.token = token;
                this.adminName = name || 'Admin';
                this.role = role || 'Team Lead';
                this.isAuthenticated = true;
                this.dispatchEvent(new CustomEvent('authenticated'));
            } else {
                this.handleLogout();
            }
        }
        this.isCheckingSession = false;
    }

    handleLogin(event) {
        const { token, name, role } = event.detail;
        this.token = token;
        this.adminName = name || 'Admin';
        this.role = role || 'Team Lead';
        this.isAuthenticated = true;

        localStorage.setItem('admin_token', token);
        localStorage.setItem('admin_name', this.adminName);
        localStorage.setItem('admin_role', this.role);

        // Notify parent that authentication succeeded
        this.dispatchEvent(new CustomEvent('authenticated'));
    }

    handleLogout() {
        if (this.token) {
            logout({ token: this.token }).catch(console.error);
        }

        this.isAuthenticated = false;
        this.token = '';
        this.adminName = '';
        this.role = '';
        localStorage.removeItem('admin_token');
        localStorage.removeItem('admin_name');
        localStorage.removeItem('admin_role');

        // Redirect to main landing page
        this.dispatchEvent(new CustomEvent('backtolanding'));
    }

    handleBackToLanding() {
        // Pass the backtolanding event up to parent (landingPage)
        this.dispatchEvent(new CustomEvent('backtolanding'));
    }
}
