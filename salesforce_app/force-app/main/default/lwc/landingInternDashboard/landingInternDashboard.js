import { LightningElement, api, track } from 'lwc';
import LightningAlert from 'lightning/alert';
// Forced update
import clockIn from '@salesforce/apex/InternWorkController.clockIn';
import clockOut from '@salesforce/apex/InternWorkController.clockOut';
import getCurrentStatus from '@salesforce/apex/InternWorkController.getCurrentStatus';
import getAttendanceHistory from '@salesforce/apex/InternWorkController.getAttendanceHistory';
import getTasks from '@salesforce/apex/InternWorkController.getTasks';
import updateTaskStatus from '@salesforce/apex/InternWorkController.updateTaskStatus';
import getAttendanceMetrics from '@salesforce/apex/InternWorkController.getAttendanceMetrics';

// Layout & Leaves & Leaderboard & Resources & Announcements & Daily Log & Profile & Mentorship
import submitLeaveRequest from '@salesforce/apex/InternWorkController.submitLeaveRequest';
import getLeaveRequests from '@salesforce/apex/InternWorkController.getLeaveRequests';
import getLeaderboardData from '@salesforce/apex/InternWorkController.getLeaderboardData';
import getResources from '@salesforce/apex/InternWorkController.getResources';
import getAnnouncements from '@salesforce/apex/InternWorkController.getAnnouncements';
import submitDailyLog from '@salesforce/apex/InternWorkController.submitDailyLog';
import getDailyLogs from '@salesforce/apex/InternWorkController.getDailyLogs';
import getInternProfile from '@salesforce/apex/InternWorkController.getInternProfile';
import updateProfile from '@salesforce/apex/InternWorkController.updateProfile';
import uploadProfileImage from '@salesforce/apex/InternWorkController.uploadProfileImage';
import submitMentorshipRequest from '@salesforce/apex/InternWorkController.submitMentorshipRequest';
import getMentorshipRequests from '@salesforce/apex/InternWorkController.getMentorshipRequests';
import getSyllabus from '@salesforce/apex/InternWorkController.getSyllabus';
import getClassSessionLinks from '@salesforce/apex/InternWorkController.getClassSessionLinks';
import LEARNERS_BYTE_LOGO from '@salesforce/resourceUrl/LearnersByteExpertpedia';

export default class LandingInternDashboard extends LightningElement {
    learnersByteLogo = LEARNERS_BYTE_LOGO;
    _token;
    pageSize = 5; // System-wide page size

    @api
    get token() {
        return this._token;
    }
    set token(value) {
        this._token = value;
        if (this._token) {
            this.refreshData();
            this.refreshProfile();
            this.refreshAnnouncements();
        }
    }
    @api internName = 'Intern';
    @track tasks = [];
    @track history = [];
    @track isClockedIn = false;
    @track metrics = { weeklyHours: 0, weeklyGoal: 40, streak: 0 };
    @track checkInTime = null;
    @track profilePicUrl;
    isLoading = false;

    // Checkout Modal State
    @track isCheckoutModalOpen = false;
    @track canCheckoutMsg = '';
    @track isEarlyCheckout = false;
    @track checkoutReason = '';

    // Generic Alert Modal State
    @track isAlertModalOpen = false;
    @track alertTitle = '';
    @track alertMessage = '';
    @track alertVariant = 'error'; // error, warning, success


    // Navigation State
    @track currentTab = 'dashboard';

    get isDashboard() { return this.currentTab === 'dashboard'; }
    get isMyTasks() { return this.currentTab === 'mytasks'; }
    get isLeaves() { return this.currentTab === 'leaves'; }
    get isLeaderboard() { return this.currentTab === 'leaderboard'; }
    get isResources() { return this.currentTab === 'resources'; }
    get isWorkLogs() { return this.currentTab === 'worklogs'; }
    get isProfile() { return this.currentTab === 'profile'; }
    get isMentorship() { return this.currentTab === 'mentorship'; }

    get gridClass() {
        return this.isDashboard ? 'dashboard-grid' : 'tasks-grid';
    }

    // Tab Classes for Header Tabs
    get dashboardTabClass() { return this.isDashboard ? 'active' : ''; }
    get tasksTabClass() { return this.isMyTasks ? 'active' : ''; }
    get resourcesTabClass() { return this.isResources ? 'active' : ''; }
    get workLogsTabClass() { return this.isWorkLogs ? 'active' : ''; }
    get profileTabClass() { return this.isProfile ? 'active' : ''; }
    get mentorshipTabClass() { return this.isMentorship ? 'active' : ''; }

    // Computed properties for dashboard metrics
    get weeklyHours() {
        return this.metrics ? this.metrics.weeklyHours || 0 : 0;
    }

    get weeklyGoal() {
        return this.metrics ? this.metrics.weeklyGoal || 40 : 40;
    }

    get streak() {
        return this.metrics ? this.metrics.streak || 0 : 0;
    }

    // Get first 5 tasks for dashboard preview
    get recentTasks() {
        return this.tasks ? this.tasks.slice(0, 5) : [];
    }

    // Get first letter of intern name for avatar
    get internNameFirstLetter() {
        return this.internName ? this.internName.charAt(0).toUpperCase() : 'I';
    }

    // Get college name from profile
    get collegeName() {
        return this.profile ? this.profile.College_Name__c : '';
    }

    // Dashboard Stats
    get totalTaskCount() {
        return this.tasks ? this.tasks.length : 0;
    }

    get completedTaskCount() {
        return this.tasks ? this.tasks.filter(t => t.Status__c === 'Completed').length : 0;
    }

    get pendingTaskCount() {
        return this.tasks ? this.tasks.filter(t => t.Status__c !== 'Completed').length : 0;
    }

    get totalPresentDays() {
        return this.metrics ? this.metrics.totalPresent || 0 : 0;
    }

    get totalElapsedDays() {
        return this.metrics ? this.metrics.totalElapsed || 0 : 0;
    }

    get totalLeaveDays() {
        return this.metrics ? this.metrics.totalLeave || 0 : 0;
    }

    get attendancePercent() {
        if (!this.totalElapsedDays) return 0;
        return Math.round((this.totalPresentDays / this.totalElapsedDays) * 100);
    }

    get attendancePercentStyle() {
        return `width: ${this.attendancePercent}%`;
    }

    get progressPercentRounded() {
        return Math.round(this.progressPercent);
    }

    get taskCompletionPercent() {
        if (!this.totalTaskCount) return 0;
        return Math.round((this.completedTaskCount / this.totalTaskCount) * 100);
    }

    get taskCompletionStyle() {
        return `width: ${this.taskCompletionPercent}%`;
    }

    // Quick action handlers
    navigateToTasks() { this.currentTab = 'mytasks'; }
    navigateToDiary() { this.currentTab = 'worklogs'; this.refreshWorkLogs(); }
    navigateToResources() { this.currentTab = 'resources'; this.refreshResources(); }
    navigateToProfile() { this.currentTab = 'profile'; this.refreshProfile(); }
    navigateToMentorship() { this.currentTab = 'mentorship'; this.refreshMentorship(); }

    // Announcements State
    @track announcements = [];

    // Class Session Links State
    @track sessionLinks = [];

    // Time and Date Display
    @track currentTime = '';
    @track currentDate = '';
    timeInterval;

    connectedCallback() {
        this.refreshData();
        this.loadSyllabus();
        this.refreshSessionLinks();
        // Update date/time display
        this.updateDateTime();
        this.timeInterval = setInterval(() => {
            this.updateDateTime();
        }, 1000);
    }

    disconnectedCallback() {
        if (this.timeInterval) {
            clearInterval(this.timeInterval);
        }
    }

    updateDateTime() {
        const now = new Date();

        // Format time (12-hour format with AM/PM)
        let hours = now.getHours();
        const minutes = now.getMinutes();
        const seconds = now.getSeconds();
        const ampm = hours >= 12 ? 'PM' : 'AM';
        hours = hours % 12;
        hours = hours ? hours : 12; // 0 should be 12

        this.currentTime = `${this.padZero(hours)}:${this.padZero(minutes)}:${this.padZero(seconds)} ${ampm}`;

        // Format date
        const options = { weekday: 'short', year: 'numeric', month: 'short', day: 'numeric' };
        this.currentDate = now.toLocaleDateString('en-US', options);
    }

    padZero(num) {
        return num < 10 ? '0' + num : num;
    }

    async refreshAnnouncements() {
        try {
            const data = await getAnnouncements({ token: this.token });
            const processed = data.map(a => {
                let badgeClass = 'notice-badge';
                let typeClass = `announcement-type type-${a.Type__c || 'Info'}`;
                let icon = 'utility:info';
                if (a.Type__c === 'Urgent') { badgeClass += ' badge-urgent'; icon = 'utility:warning'; }
                else if (a.Type__c === 'Celebration') { badgeClass += ' badge-success'; icon = 'utility:favorite'; }
                else if (a.Type__c === 'Alert') { badgeClass += ' badge-alert'; icon = 'utility:alert'; }

                return { ...a, badgeClass, icon, typeClass };
            });

            // Duplicate for seamless marquee if there are enough items
            // If only 1 or 2, maybe don't duplicate or duplicate multiple times
            if (processed.length > 0) {
                const original = processed.map(item => ({ ...item, uniqueKey: item.Id }));
                const copy = processed.map(item => ({ ...item, uniqueKey: item.Id + '_copy' }));
                this.announcements = [...original, ...copy];
            } else {
                this.announcements = [];
            }
        } catch (e) { console.error('Error fetching announcements', e); }
    }

    get hasAnnouncements() {
        return this.announcements && this.announcements.length > 0;
    }

    handleTabSwitch(event) {
        // ... existing logic ...
        const tab = event.currentTarget.dataset.tab;
        if (tab) {
            this.currentTab = tab;
            if (tab === 'leaves') this.refreshLeaves();
            else if (tab === 'leaderboard') this.refreshLeaderboard();
            else if (tab === 'resources') this.refreshResources();
            else if (tab === 'worklogs') this.refreshWorkLogs();
            else if (tab === 'profile') this.refreshProfile();
            else if (tab === 'mentorship') this.refreshMentorship();
        }
    }

    handleViewAllTasks() {
        this.currentTab = 'mytasks';
    }

    // --- Pagination Logic ---
    // Generic helper could be used, but specific getters are clearer for template

    // Leaves Pagination
    @track leavesPage = 1;
    get visibleLeaves() {
        if (!this.leaves) return [];
        const start = (this.leavesPage - 1) * this.pageSize;
        return this.leaves.slice(start, start + this.pageSize);
    }
    get isLeavesFirstPage() { return this.leavesPage === 1; }
    get isLeavesLastPage() { return this.leavesPage >= Math.ceil(this.leaves.length / this.pageSize); }
    get totalLeavesPages() { return Math.ceil(this.leaves.length / this.pageSize) || 1; }

    prevLeavesPage() { if (this.leavesPage > 1) this.leavesPage--; }
    nextLeavesPage() { if (!this.isLeavesLastPage) this.leavesPage++; }

    // Leaderboard Pagination
    @track leaderboardPage = 1;
    get visibleLeaderboard() {
        if (!this.leaderboard) return [];
        const start = (this.leaderboardPage - 1) * this.pageSize;
        return this.leaderboard.slice(start, start + this.pageSize);
    }
    get isLeaderboardFirstPage() { return this.leaderboardPage === 1; }
    get isLeaderboardLastPage() { return this.leaderboardPage >= Math.ceil(this.leaderboard.length / this.pageSize); }
    get totalLeaderboardPages() { return Math.ceil(this.leaderboard.length / this.pageSize) || 1; }

    prevLeaderboardPage() { if (this.leaderboardPage > 1) this.leaderboardPage--; }
    nextLeaderboardPage() { if (!this.isLeaderboardLastPage) this.leaderboardPage++; }

    // Resources Pagination
    @track resourcesPage = 1;
    get visibleResources() {
        if (!this.resources) return [];
        const start = (this.resourcesPage - 1) * this.pageSize;
        return this.resources.slice(start, start + this.pageSize);
    }
    get isResourcesFirstPage() { return this.resourcesPage === 1; }
    get isResourcesLastPage() { return this.resourcesPage >= Math.ceil(this.resources.length / this.pageSize); }
    get totalResourcesPages() { return Math.ceil(this.resources.length / this.pageSize) || 1; }

    prevResourcesPage() { if (this.resourcesPage > 1) this.resourcesPage--; }
    nextResourcesPage() { if (!this.isResourcesLastPage) this.resourcesPage++; }

    // Work Logs Pagination
    @track workLogsPage = 1;
    get visibleWorkLogs() {
        if (!this.dailyLogs) return [];
        const start = (this.workLogsPage - 1) * this.pageSize;
        return this.dailyLogs.slice(start, start + this.pageSize);
    }
    get isWorkLogsFirstPage() { return this.workLogsPage === 1; }
    get isWorkLogsLastPage() { return this.workLogsPage >= Math.ceil(this.dailyLogs.length / this.pageSize); }
    get totalWorkLogsPages() { return Math.ceil(this.dailyLogs.length / this.pageSize) || 1; }

    prevWorkLogsPage() { if (this.workLogsPage > 1) this.workLogsPage--; }
    nextWorkLogsPage() { if (!this.isWorkLogsLastPage) this.workLogsPage++; }


    // Mentorship Pagination
    @track mentorshipPage = 1;
    get visibleMentorshipRequests() {
        if (!this.mentorshipRequests) return [];
        const start = (this.mentorshipPage - 1) * this.pageSize;
        return this.mentorshipRequests.slice(start, start + this.pageSize);
    }
    get isMentorshipFirstPage() { return this.mentorshipPage === 1; }
    get isMentorshipLastPage() { return this.mentorshipPage >= Math.ceil(this.mentorshipRequests.length / this.pageSize); }
    get totalMentorshipPages() { return Math.ceil(this.mentorshipRequests.length / this.pageSize) || 1; }

    prevMentorshipPage() { if (this.mentorshipPage > 1) this.mentorshipPage--; }
    nextMentorshipPage() { if (!this.isMentorshipLastPage) this.mentorshipPage++; }


    // Attendance History Pagination
    @track historyPage = 1;
    get visibleHistory() {
        if (!this.history) return [];
        const start = (this.historyPage - 1) * this.pageSize;
        return this.history.slice(start, start + this.pageSize);
    }
    get isFirstHistoryPage() { return this.historyPage === 1; }
    get isLastHistoryPage() { return this.historyPage >= Math.ceil(this.history.length / this.pageSize); }
    get totalHistoryPages() { return Math.ceil(this.history.length / this.pageSize) || 1; }

    handleHistoryPrev() { if (this.historyPage > 1) this.historyPage--; }
    handleHistoryNext() { if (!this.isLastHistoryPage) this.historyPage++; }



    // Mentorship State
    @track mentorshipRequests = [];
    @track mentorshipForm = {
        type: 'Code Review',
        description: ''
    };

    get requestTypes() {
        return [
            { label: 'Code Review', value: 'Code Review' },
            { label: 'Career Advice', value: 'Career Advice' },
            { label: 'Project Help', value: 'Project Help' },
            { label: 'General Feedback', value: 'General Feedback' }
        ];
    }

    async refreshMentorship() {
        try {
            this.mentorshipRequests = await getMentorshipRequests({ token: this.token });
        } catch (e) {
            console.error('Error fetching mentorship requests', e);
        }
    }

    async refreshSessionLinks() {
        try {
            console.log('Fetching class session links...');
            const data = await getClassSessionLinks();
            console.log('Session links received:', data ? data.length : 0, 'records');
            console.log('Session data:', JSON.stringify(data));

            // Process session links to add computed properties for UI
            this.sessionLinks = data.map((session, index) => {
                // Determine color based on index for variety
                const colors = ['blue', 'purple', 'green', 'orange', 'teal', 'pink'];
                const colorClass = colors[index % colors.length];

                // Check if session is happening today
                const sessionDate = new Date(session.Date__c);
                const today = new Date();
                const isToday = sessionDate.toDateString() === today.toDateString();

                // Check if session is upcoming (future)
                const isUpcoming = sessionDate > today;

                return {
                    ...session,
                    colorClass: colorClass,
                    isToday: isToday,
                    isUpcoming: isUpcoming,
                    formattedDate: this.formatSessionDate(session.Date__c),
                    formattedStartTime: this.formatTime(session.Session_Start__c),
                    formattedEndTime: this.formatTime(session.Session_End__c)
                };
            });
            console.log('Processed session links:', this.sessionLinks);
        } catch (e) {
            console.error('Error fetching session links', e);
            console.error('Error details:', JSON.stringify(e));
        }
    }

    formatSessionDate(dateString) {
        if (!dateString) return '';
        const date = new Date(dateString);
        const options = { weekday: 'short', month: 'short', day: 'numeric' };
        return date.toLocaleDateString('en-US', options);
    }

    formatTime(timeValue) {
        if (!timeValue && timeValue !== 0) return '';

        let hours, minutes;

        // Check if timeValue is a number (milliseconds since midnight)
        if (typeof timeValue === 'number') {
            // Convert milliseconds to hours and minutes
            const totalMinutes = Math.floor(timeValue / 60000);
            hours = Math.floor(totalMinutes / 60);
            minutes = totalMinutes % 60;
        } else {
            // timeValue is a string in format "HH:MM:SS.sss" or "HH:MM:SS"
            const parts = timeValue.split(':');
            if (parts.length < 2) return timeValue;
            hours = parseInt(parts[0]);
            minutes = parts[1];
        }

        // Convert to 12-hour format with AM/PM
        const ampm = hours >= 12 ? 'PM' : 'AM';
        hours = hours % 12;
        hours = hours ? hours : 12; // 0 should be 12

        // Ensure minutes is two digits
        const minutesStr = typeof minutes === 'number' ? minutes.toString().padStart(2, '0') : minutes;

        return `${hours}:${minutesStr} ${ampm}`;
    }

    handleMentorshipInput(event) {
        const field = event.target.dataset.field;
        this.mentorshipForm = { ...this.mentorshipForm, [field]: event.target.value };
    }

    async handleSubmitMentorship() {
        if (!this.mentorshipForm.description) {
            alert('Please explain your request.');
            return;
        }

        this.isLoading = true;
        try {
            await submitMentorshipRequest({
                token: this.token,
                type: this.mentorshipForm.type,
                description: this.mentorshipForm.description
            });
            this.mentorshipForm.description = ''; // Reset description
            await this.refreshMentorship();
            alert('Request Submitted!');
        } catch (e) {
            console.error(e);
            alert('Error submitting request: ' + (e.body ? e.body.message : e.message));
        } finally {
            this.isLoading = false;
        }
    }

    // Work Logs State (Now Diary)
    @track dailyLogs = [];
    @track logForm = {
        date: new Date().toISOString().split('T')[0],
        description: '',
        hours: 0,
        course: '',
        module: [], // Changed to array for multi-select
        topic: '',
        submissionLink: '',
        learnings: '',
        blockers: ''
    };
    get isModuleDisabled() {
        return !this.logForm.course;
    }


    // Syllabus Data
    @track fullSyllabus = [];
    @track courseOptions = [];
    @track moduleOptions = [];

    get maxEntryDate() {
        return new Date().toISOString().split('T')[0];
    }

    get minEntryDate() {
        const d = new Date();
        d.setDate(d.getDate() - 7);
        return d.toISOString().split('T')[0];
    }

    async refreshWorkLogs() {
        try {
            this.dailyLogs = await getDailyLogs({ token: this.token });
        } catch (e) {
            console.error('Error fetching logs', e);
        }
    }

    async loadSyllabus() {
        try {
            this.fullSyllabus = await getSyllabus();
            this.processCourses();
        } catch (e) {
            console.error('Error loading syllabus', e);
        }
    }

    processCourses() {
        const courses = new Set(this.fullSyllabus.map(item => item.Course_Name__c));
        this.courseOptions = Array.from(courses).map(c => ({ label: c, value: c }));
    }

    handleCourseChange(event) {
        const selectedCourse = event.target.value;
        this.logForm = { ...this.logForm, course: selectedCourse, module: [] };

        // Filter Modules for this Course
        const modules = new Set(
            this.fullSyllabus
                .filter(item => item.Course_Name__c === selectedCourse)
                .map(item => item.Module_Name__c)
        );
        this.moduleOptions = Array.from(modules).map(m => ({ label: m, value: m }));
    }

    handleModuleChange(event) {
        // Multi-select returns an array of values
        const selectedModules = event.detail.value;
        this.logForm = { ...this.logForm, module: selectedModules };
    }

    handleLogInput(event) {
        const field = event.target.dataset.field;
        this.logForm = { ...this.logForm, [field]: event.target.value };
    }

    async handleSubmitLog() {
        if (!this.logForm.description || !this.logForm.course) {
            // Simple validation
            alert('Please fill in at least the Course and Description.');
            return;
        }

        this.isLoading = true;
        try {
            await submitDailyLog({
                token: this.token,
                logDate: this.logForm.date,
                description: this.logForm.description,
                hours: this.logForm.hours,
                course: this.logForm.course,
                module: this.logForm.module.join(', '), // Convert array to CSV string
                topic: this.logForm.topic,
                submissionLink: this.logForm.submissionLink,
                learnings: this.logForm.learnings,
                blockers: this.logForm.blockers
            });
            // Reset form and refresh
            this.logForm = {
                date: new Date().toISOString().split('T')[0],
                description: '',
                hours: 0,
                course: '',
                module: [],
                topic: '',
                submissionLink: '',
                learnings: '',
                blockers: ''
            };
            this.moduleOptions = [];

            await this.refreshWorkLogs();
            alert('Diary Entry Submitted Successfully!');
        } catch (e) {
            console.error(e);
            alert('Error submitting log: ' + (e.body ? e.body.message : e.message));
        } finally {
            this.isLoading = false;
        }
    }

    // Profile State
    @track profile = {
        Name: '', Email__c: '', Phone__c: '', Bio__c: '', College_Name__c: '', Roll_Number__c: ''
    };
    @track profilePicUrl; // Stores the URL for the image
    @track isEditingProfile = false;

    async refreshProfile() {
        try {
            const data = await getInternProfile({ token: this.token });

            // Handle the Map response correctly
            // The Apex returns: { intern: ..., profilePicData: ... }
            // Javascript sees this as an object.

            if (data && data.intern) {
                this.profile = data.intern;
                this.internName = this.profile.Name;

                if (data.profilePicData) {
                    this.profilePicUrl = data.profilePicData;
                } else {
                    this.profilePicUrl = null;
                }
            }
        } catch (e) {
            console.error('Error fetching profile', e);
        }
    }

    async handleFileChange(event) {
        const file = event.target.files[0];
        if (file) {
            // 1. File Size Check (Max 3MB to avoid Apex Heap Limit)
            if (file.size > 3000000) {
                LightningAlert.open({
                    message: 'Image is too large. Please use an image smaller than 3MB.',
                    theme: 'error',
                    label: 'Upload Error',
                });
                return;
            }
            console.log('File size safe:', file.size);

            const reader = new FileReader();
            reader.onload = async () => {
                const base64 = reader.result.split(',')[1];
                this.isLoading = true;
                try {
                    await uploadProfileImage({
                        token: this.token,
                        base64Data: base64,
                        filename: file.name,
                        contentType: file.type || 'image/jpeg'
                    });

                    // Force delay to ensure committed
                    // await new Promise(resolve => setTimeout(resolve, 500));

                    await this.refreshProfile(); // Refresh to get new image

                    LightningAlert.open({
                        message: 'Profile picture updated successfully!',
                        theme: 'success',
                        label: 'Success',
                    });

                } catch (e) {
                    console.error('Error uploading image', e);
                    LightningAlert.open({
                        message: 'Error uploading image: ' + (e.body ? e.body.message : e.message),
                        theme: 'error',
                        label: 'Upload Error',
                    });
                } finally {
                    this.isLoading = false;
                }
            };
            reader.readAsDataURL(file);
        }
    }

    handleProfileEdit() {
        this.isEditingProfile = true;
    }

    handleProfileCancel() {
        this.isEditingProfile = false;
        this.refreshProfile(); // Revert changes
    }

    handleProfileInput(event) {
        const field = event.target.dataset.field;
        this.profile = { ...this.profile, [field]: event.target.value };
    }

    async handleProfileSave() {
        this.isLoading = true;
        try {
            await updateProfile({
                token: this.token,
                email: this.profile.Email__c,
                phone: this.profile.Phone__c,
                bio: this.profile.Bio__c
            });
            this.isEditingProfile = false;
            await this.refreshProfile();
            alert('Profile Updated Successfully!');
        } catch (e) {
            console.error(e);
            alert('Error updating profile: ' + (e.body ? e.body.message : e.message));
        } finally {
            this.isLoading = false;
        }
    }

    // Leaderboard State
    @track leaderboard = [];

    async refreshLeaderboard() {
        try {
            const data = await getLeaderboardData();
            // User requested top 5 only
            this.leaderboard = data.slice(0, 5);
        } catch (e) {
            console.error(e);
        }
    }

    // Resources State
    @track resources = [];

    async refreshResources() {
        try {
            this.resources = await getResources({ token: this.token });
            // Add icon properties based on type
            this.resources = this.resources.map(r => {
                let iconName = 'standard:article';
                if (r.Type__c === 'Video') iconName = 'standard:video';
                else if (r.Type__c === 'Website' || r.Type__c === 'Tool') iconName = 'standard:link';
                return { ...r, iconName };
            });
        } catch (e) {
            console.error(e);
        }
    }

    // Leave Request State
    @track leaves = [];
    @track isLeaveModalOpen = false;
    @track leaveForm = {
        startDate: '',
        endDate: '',
        reason: ''
    };

    async refreshLeaves() {
        try {
            this.leaves = await getLeaveRequests({ token: this.token });
        } catch (e) {
            console.error(e);
        }
    }

    openLeaveModal() { this.isLeaveModalOpen = true; }
    closeLeaveModal() { this.isLeaveModalOpen = false; }

    handleLeaveInput(event) {
        const field = event.target.name;
        this.leaveForm = { ...this.leaveForm, [field]: event.target.value };
    }

    async handleLeaveSubmit() {
        const { startDate, endDate, reason } = this.leaveForm;
        if (!startDate || !endDate) {
            alert('Please select start and end dates.');
            return;
        }

        this.isLoading = true;
        try {
            await submitLeaveRequest({
                token: this.token,
                startDate: startDate,
                endDate: endDate,
                reason: reason
            });
            this.isLeaveModalOpen = false;
            this.leaveForm = { startDate: '', endDate: '', reason: '' }; // Reset
            await this.refreshLeaves();
            alert('Leave request submitted!');
        } catch (e) {
            console.error(e);
            alert(e.body ? e.body.message : e.message);
        } finally {
            this.isLoading = false;
        }
    }



    get progressPercent() {
        if (!this.metrics || !this.metrics.weeklyGoal) return 0;
        let pct = (this.metrics.weeklyHours / this.metrics.weeklyGoal) * 100;
        return pct > 100 ? 100 : pct;
    }

    get progressStyle() {
        return `width: ${this.progressPercent}%`;
    }

    get ringStyle() {
        const pct = this.metrics.progressPercent || 0;
        return `background: conic-gradient(#00b894 ${pct}%, #dfe6e9 0)`;
    }

    // Attendance Visualization Getters
    get absentDays() {
        const { totalElapsed, totalPresent, totalLeave } = this.metrics;
        let absent = totalElapsed - totalPresent - totalLeave;
        return absent > 0 ? absent : 0;
    }

    get attendanceSegments() {
        const { totalElapsed, totalPresent, totalLeave } = this.metrics;
        if (!totalElapsed || totalElapsed === 0) return { present: 0, leave: 0, absent: 0 };

        const absent = this.absentDays;
        return {
            present: ((totalPresent / totalElapsed) * 100).toFixed(1),
            leave: ((totalLeave / totalElapsed) * 100).toFixed(1),
            absent: ((absent / totalElapsed) * 100).toFixed(1)
        };
    }

    get attendanceBarStyle() {
        const segs = this.attendanceSegments;
        // Present (Green), Leave (Orange), Absent (Red)
        return `background: linear-gradient(to right, 
            #00b894 0%, #00b894 ${segs.present}%, 
            #fdcb6e ${segs.present}%, #fdcb6e ${parseFloat(segs.present) + parseFloat(segs.leave)}%, 
            #ff7675 ${parseFloat(segs.present) + parseFloat(segs.leave)}%, #ff7675 100%)`;
    }

    async refreshData() {
        this.isLoading = true;
        try {
            // 1. Current Status (Check In/Out)
            const status = await getCurrentStatus({ token: this.token });

            // Handle both legacy boolean (if mixed deploy) and new Map
            if (status && typeof status === 'object') {
                this.isClockedIn = status.isClockedIn;
                this.checkInTime = status.loginTime;
            } else {
                this.isClockedIn = !!status;
                this.checkInTime = null; // Can't calc duration
            }

            // 2. Attendance History
            this.history = await getAttendanceHistory({ token: this.token });
            console.log('DEBUG: Attendance History Data:', JSON.parse(JSON.stringify(this.history)));

            // NORMALIZE STATUS (Handle Field Name Case Sensitivity)
            if (this.history) {
                this.history = this.history.map(row => ({
                    ...row,
                    Status__c: row.Status__c || row.status__c || row.Status || ''
                }));
            }

            this.tasks = await getTasks({ token: this.token });

            // Get Analytics
            const metrics = await getAttendanceMetrics({ token: this.token });
            if (metrics) {
                this.metrics = metrics;
            }

            // Load Leaderboard for Dashboard Widget
            await this.refreshLeaderboard();

            // Add properties for UI
            this.tasks = this.tasks.map(t => {
                let statusClass = 'status-tag ';
                if (t.Status__c === 'Completed') statusClass += 'tag-completed';
                else if (t.Status__c === 'In Progress') statusClass += 'tag-inprogress';
                else statusClass += 'tag-assigned';

                // Priority badge class
                let priorityClass = 'priority-badge ';
                const prio = (t.Priority__c || 'Medium').toLowerCase();
                if (prio === 'high') priorityClass += 'priority-high';
                else if (prio === 'low') priorityClass += 'priority-low';
                else priorityClass += 'priority-medium';

                // Task card accent class
                let taskCardClass = 'task-card animate-slide-up ';
                if (t.Status__c === 'Completed') taskCardClass += 'task-card-completed';
                else if (t.Status__c === 'In Progress') taskCardClass += 'task-card-inprogress';
                else taskCardClass += 'task-card-assigned';

                // Action button class
                let actionBtnClass = 'task-action-btn ';
                if (t.Status__c === 'Completed') actionBtnClass += 'action-completed';
                else if (t.Status__c === 'In Progress') actionBtnClass += 'action-inprogress';
                else actionBtnClass += 'action-assigned';

                return {
                    ...t,
                    Priority__c: t.Priority__c || 'Medium',
                    isCompleted: t.Status__c === 'Completed',
                    computedClass: t.Status__c === 'Completed' ? 'task-item completed' : 'task-item',
                    statusClass: statusClass,
                    priorityClass: priorityClass,
                    taskCardClass: taskCardClass,
                    actionBtnClass: actionBtnClass
                };
            });

        } catch (e) {
            console.error('Error refreshing data', e);
        } finally {
            this.isLoading = false;
        }
    }

    async handleClockIn() {
        this.isLoading = true;
        try {
            await clockIn({ token: this.token });
            await this.refreshData(); // Refresh to update status and history
        } catch (e) {
            this.isLoading = false;
            // Handle Apex exceptions
            const msg = e.body ? e.body.message : e.message;

            if (msg.includes('ALREADY_LOGGED_TODAY') || msg.includes('Script-thrown')) {
                // If we get specific code OR generic script error (likely duplicate in this context)
                this.showAlert('Already Checked In', 'You have already recorded a session for today. Duplicates are not allowed.', 'warning');
            } else {
                this.showAlert('Error', msg, 'error');
            }
        }
    }

    showAlert(title, message, variant) {
        this.alertTitle = title;
        this.alertMessage = message;
        this.alertVariant = variant;
        this.isAlertModalOpen = true;
    }

    closeAlertModal() {
        this.isAlertModalOpen = false;
    }

    get alertIconName() {
        if (this.alertVariant === 'warning') return 'utility:warning';
        if (this.alertVariant === 'success') return 'utility:success';
        return 'utility:error';
    }

    get alertThemeClass() {
        if (this.alertVariant === 'warning') return 'slds-text-color_warning';
        if (this.alertVariant === 'success') return 'slds-text-color_success';
        return 'slds-text-color_error';
    }

    async handleClockOut() {
        // Smart Checkout Logic
        const now = Date.now();
        let durationHours = 0;

        if (this.checkInTime) {
            durationHours = (now - this.checkInTime) / (1000 * 60 * 60);
        }

        // Reset state
        this.checkoutReason = '';
        this.isCheckoutModalOpen = true;

        if (durationHours >= 8) {
            this.isEarlyCheckout = false;
            this.canCheckoutMsg = `Great job! You have completed ${durationHours.toFixed(1)} hours today.`;
        } else {
            this.isEarlyCheckout = true;
            this.canCheckoutMsg = `You have only worked ${durationHours.toFixed(1)} hours today.`;
        }
    }

    get checkoutBtnVariant() {
        return this.isEarlyCheckout ? 'destructive' : 'success';
    }

    handleCheckoutReasonChange(event) {
        this.checkoutReason = event.target.value;
    }

    closeCheckoutModal() {
        this.isCheckoutModalOpen = false;
    }

    async confirmCheckout() {
        if (this.isEarlyCheckout && !this.checkoutReason) {
            alert('Please provide a reason for early checkout.');
            return;
        }

        this.isCheckoutModalOpen = false;
        this.isLoading = true;
        try {
            await clockOut({ token: this.token, checkoutReason: this.checkoutReason });
            await this.refreshData(); // Refresh to update status and history
        } catch (e) {
            console.error(e);
            alert(e.body ? e.body.message : e.message);
            this.isLoading = false;
        }
    }

    // Pagination State
    @track historyPage = 1;
    @track taskPage = 1;
    @track filterStatus = 'All'; // New Filter State
    pageSize = 5;

    // Get subset of history for current page
    get visibleHistory() {
        const start = (this.historyPage - 1) * this.pageSize;
        return this.history.slice(start, start + this.pageSize);
    }

    get isFirstHistoryPage() { return this.historyPage === 1; }
    get isLastHistoryPage() { return this.historyPage * this.pageSize >= this.history.length; }

    handleHistoryPrev() { if (this.historyPage > 1) this.historyPage--; }
    handleHistoryNext() { if (!this.isLastHistoryPage) this.historyPage++; }

    // --- Task Filtering & Pagination ---

    get taskFilterOptions() {
        return [
            { label: 'All Tasks', value: 'All' },
            { label: 'Assigned', value: 'Assigned' },
            { label: 'In Progress', value: 'In Progress' },
            { label: 'Completed', value: 'Completed' }
        ];
    }

    // Task Stats
    get assignedTaskCount() {
        return this.tasks ? this.tasks.filter(t => t.Status__c === 'Assigned').length : 0;
    }

    get inProgressTaskCount() {
        return this.tasks ? this.tasks.filter(t => t.Status__c === 'In Progress').length : 0;
    }

    // Filter pill classes
    get filterAllClass() {
        return `filter-pill pill-all${this.filterStatus === 'All' ? ' active' : ''}`;
    }
    get filterAssignedClass() {
        return `filter-pill pill-assigned${this.filterStatus === 'Assigned' ? ' active' : ''}`;
    }
    get filterInProgressClass() {
        return `filter-pill pill-inprogress${this.filterStatus === 'In Progress' ? ' active' : ''}`;
    }
    get filterCompletedClass() {
        return `filter-pill pill-completed${this.filterStatus === 'Completed' ? ' active' : ''}`;
    }

    handleFilterClick(event) {
        this.filterStatus = event.currentTarget.dataset.filter;
        this.taskPage = 1;
    }

    handleTaskFilterChange(event) {
        this.filterStatus = event.detail.value;
        this.taskPage = 1; // Reset to first page on filter change
    }

    get filteredTasks() {
        if (this.filterStatus === 'All') {
            return this.tasks;
        }
        return this.tasks.filter(t => t.Status__c === this.filterStatus);
    }

    // Get subset of filtered tasks for current page
    get visibleTasks() {
        const start = (this.taskPage - 1) * this.pageSize;
        return this.filteredTasks.slice(start, start + this.pageSize);
    }

    get isFirstTaskPage() { return this.taskPage === 1; }
    get isLastTaskPage() { return this.taskPage * this.pageSize >= this.filteredTasks.length; } // Use filteredTasks length

    handleTaskPrev() { if (this.taskPage > 1) this.taskPage--; }
    handleTaskNext() { if (!this.isLastTaskPage) this.taskPage++; }

    @track selectedTask = null;

    get taskStatusOptions() {
        return [
            { label: 'Assigned', value: 'Assigned' },
            { label: 'In Progress', value: 'In Progress' },
            { label: 'Completed', value: 'Completed' }
        ];
    }

    handleSelectTask(event) {
        const taskId = event.currentTarget.dataset.id;
        // Create a copy to avoid mutating the list directly until save
        this.selectedTask = { ...this.tasks.find(t => t.Id === taskId) };
    }

    handleCloseTask() {
        this.selectedTask = null;
    }

    handleStopPropagation(event) {
        event.stopPropagation();
    }

    handleTaskInput(event) {
        const field = event.target.name;
        this.selectedTask = { ...this.selectedTask, [field]: event.target.value };
    }

    handleStatusCardClick(event) {
        const status = event.currentTarget.dataset.status;
        this.selectedTask = { ...this.selectedTask, Status__c: status };
    }

    // Status Card Classes
    get statusCardAssignedClass() {
        const isSelected = this.selectedTask?.Status__c === 'Assigned';
        return `status-card status-card-assigned${isSelected ? ' status-card-selected' : ''}`;
    }

    get statusCardInProgressClass() {
        const isSelected = this.selectedTask?.Status__c === 'In Progress';
        return `status-card status-card-inprogress${isSelected ? ' status-card-selected' : ''}`;
    }

    get statusCardCompletedClass() {
        const isSelected = this.selectedTask?.Status__c === 'Completed';
        return `status-card status-card-completed${isSelected ? ' status-card-selected' : ''}`;
    }

    // Progress Tracker Classes
    get progressStepAssignedClass() {
        const currentStatus = this.selectedTask?.Status__c;
        let className = 'progress-step progress-step-assigned';
        if (currentStatus === 'Assigned' || currentStatus === 'In Progress' || currentStatus === 'Completed') {
            className += ' progress-step-active';
        }
        if (currentStatus === 'Assigned') {
            className += ' progress-step-current';
        }
        return className;
    }

    get progressStepInProgressClass() {
        const currentStatus = this.selectedTask?.Status__c;
        let className = 'progress-step progress-step-inprogress';
        if (currentStatus === 'In Progress' || currentStatus === 'Completed') {
            className += ' progress-step-active';
        }
        if (currentStatus === 'In Progress') {
            className += ' progress-step-current';
        }
        return className;
    }

    get progressStepCompletedClass() {
        const currentStatus = this.selectedTask?.Status__c;
        let className = 'progress-step progress-step-completed';
        if (currentStatus === 'Completed') {
            className += ' progress-step-active progress-step-current';
        }
        return className;
    }

    get progressLineClass() {
        const currentStatus = this.selectedTask?.Status__c;
        let className = 'progress-line';
        if (currentStatus === 'In Progress') {
            className += ' progress-line-50';
        } else if (currentStatus === 'Completed') {
            className += ' progress-line-100';
        }
        return className;
    }

    async handleSaveTask() {
        if (!this.selectedTask) return;

        this.isLoading = true;
        try {
            await updateTaskStatus({
                taskId: this.selectedTask.Id,
                status: this.selectedTask.Status__c,
                remarks: this.selectedTask.Remarks__c,
                progress: this.selectedTask.Today_Work_Progress__c,
                submissionLink: this.selectedTask.Submission_Link__c
            });

            // Update local list
            this.tasks = this.tasks.map(t =>
                t.Id === this.selectedTask.Id ? {
                    ...this.selectedTask,
                    isCompleted: this.selectedTask.Status__c === 'Completed',
                    computedClass: this.selectedTask.Status__c === 'Completed' ? 'task-item completed' : 'task-item'
                } : t
            );

            // Deselect or keep selected? Let's keep selected to show persistence or maybe show success
            // alert('Saved!'); 
        } catch (e) {
            console.error(e);
            alert(e.body ? e.body.message : e.message);
        } finally {
            this.isLoading = false;
        }
    }

    async handleCompleteTask(event) {
        // Keeps compatibility with list view quick-complete if needed, 
        // but mostly we use the detail view now.
        const taskId = event.target.value;
        try {
            await updateTaskStatus({ taskId: taskId, status: 'Completed', remarks: null, progress: null });
            await this.refreshData();
        } catch (e) {
            console.error(e);
        }
    }

    handleLogout() {
        this.dispatchEvent(new CustomEvent('logout'));
    }
}