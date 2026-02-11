import { LightningElement, track } from 'lwc';
import LOGO from '@salesforce/resourceUrl/LearnersByteExpertpedia';

export default class LandingPage extends LightningElement {
    @track currentView = 'landing'; // 'landing', 'admin', 'intern', 'fullpage-admin', 'fullpage-intern'
    @track isModalOpen = false;
    @track isModalVisible = false;

    // Logo
    logoUrl = LOGO;

    _escHandler;

    connectedCallback() {
        // Restore dashboard view on page refresh if session exists
        const adminToken = localStorage.getItem('admin_token');
        const internToken = localStorage.getItem('intern_session_token');

        if (adminToken) {
            this.currentView = 'fullpage-admin';
        } else if (internToken) {
            this.currentView = 'fullpage-intern';
        }
    }

    // Computed properties for conditional rendering
    get isLandingView() {
        return this.currentView === 'landing' || this.currentView === 'admin' || this.currentView === 'intern';
    }

    get isAdminView() {
        return this.currentView === 'admin';
    }

    get isInternView() {
        return this.currentView === 'intern';
    }

    get isFullPageAdmin() {
        return this.currentView === 'fullpage-admin';
    }

    get isFullPageIntern() {
        return this.currentView === 'fullpage-intern';
    }

    get modalOverlayClass() {
        return `modal-overlay ${this.isModalVisible ? 'modal-overlay-visible' : ''}`;
    }

    handleAdminLogin() {
        this.currentView = 'admin';
        this.openModal();
    }

    handleInternLogin() {
        this.currentView = 'intern';
        this.openModal();
    }

    openModal() {
        this.isModalOpen = true;
        // Trigger animation on next frame
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        requestAnimationFrame(() => {
            // eslint-disable-next-line @lwc/lwc/no-async-operation
            requestAnimationFrame(() => {
                this.isModalVisible = true;
            });
        });
        this.addEscListener();
        document.body.style.overflow = 'hidden';
    }

    handleCloseModal() {
        this.isModalVisible = false;
        // Wait for animation to finish before removing from DOM
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        setTimeout(() => {
            this.isModalOpen = false;
            this.currentView = 'landing';
            document.body.style.overflow = '';
        }, 300);
        this.removeEscListener();
    }

    handleAuthenticated() {
        // Close modal and switch to full-page dashboard
        const targetView = this.currentView === 'admin' ? 'fullpage-admin' : 'fullpage-intern';

        this.isModalVisible = false;
        this.removeEscListener();

        // eslint-disable-next-line @lwc/lwc/no-async-operation
        setTimeout(() => {
            this.isModalOpen = false;
            this.currentView = targetView;
            document.body.style.overflow = '';
        }, 300);
    }

    handleBackToLanding() {
        this.currentView = 'landing';
        this.scrollToTop();
    }

    handleOverlayClick() {
        this.handleCloseModal();
    }

    handleModalContentClick(event) {
        event.stopPropagation();
    }

    addEscListener() {
        this._escHandler = (e) => {
            if (e.key === 'Escape') {
                this.handleCloseModal();
            }
        };
        window.addEventListener('keydown', this._escHandler);
    }

    removeEscListener() {
        if (this._escHandler) {
            window.removeEventListener('keydown', this._escHandler);
            this._escHandler = null;
        }
    }

    scrollToTop() {
        window.scrollTo({ top: 0, behavior: 'smooth' });
    }

    disconnectedCallback() {
        this.removeEscListener();
        document.body.style.overflow = '';
    }
}
