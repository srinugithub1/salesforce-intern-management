import { LightningElement, track } from 'lwc';

export default class MainApp extends LightningElement {
    @track selectedRole = null; // 'intern' | 'admin' | null
    @track session = null; // { type: 'intern'|'admin', token: '...', name: '...'}

    connectedCallback() {
        const storedFn = localStorage.getItem('main_session');
        if (storedFn) {
            this.session = JSON.parse(storedFn);
        }
    }

    // Getters
    get isAuthenticated() { return !!this.session; }
    get isInternRole() { return this.selectedRole === 'intern'; }
    get isAdminRole() { return this.selectedRole === 'admin'; }

    get isInternSession() { return this.session && this.session.type === 'intern'; }
    get isAdminSession() { return this.session && this.session.type === 'admin'; }
    get sessionToken() { return this.session ? this.session.token : ''; }
    get adminRole() { return this.session && this.session.type === 'admin' ? this.session.role : ''; }

    // Role Selection
    selectInternRole() { this.selectedRole = 'intern'; }
    selectAdminRole() { this.selectedRole = 'admin'; }
    clearRole() { this.selectedRole = null; }

    // Login Handlers
    handleInternLogin(event) {
        const { token, name } = event.detail;
        this.setSession('intern', token, name);
    }

    handleAdminLogin(event) {
        const { token, name, role } = event.detail;
        this.setSession('admin', token, name, role);
    }

    setSession(type, token, name, role) {
        this.session = { type, token, name, role };
        localStorage.setItem('main_session', JSON.stringify(this.session));
        this.selectedRole = null; // Reset selection for next logout
    }

    handleLogout() {
        this.session = null;
        localStorage.removeItem('main_session');
        this.selectedRole = null; // Go back to role selection
    }
}
