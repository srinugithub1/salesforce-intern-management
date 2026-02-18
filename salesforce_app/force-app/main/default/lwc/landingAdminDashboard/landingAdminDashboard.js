import { LightningElement, track, wire, api } from 'lwc';
import { refreshApex } from '@salesforce/apex';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import LOGO from '@salesforce/resourceUrl/LearnersByteExpertpedia';

import getAllInterns from '@salesforce/apex/AdminController.getAllInterns';
import deleteIntern from '@salesforce/apex/AdminController.deleteIntern';

import getAllLeaveRequests from '@salesforce/apex/AdminController.getAllLeaveRequests';
import updateLeaveStatus from '@salesforce/apex/AdminController.updateLeaveStatus';

import getAllMentorshipRequests from '@salesforce/apex/AdminController.getAllMentorshipRequests';
import replyToMentorship from '@salesforce/apex/AdminController.replyToMentorship';

import getAllDailyLogs from '@salesforce/apex/AdminController.getAllDailyLogs';

import getAllAnnouncements from '@salesforce/apex/AdminController.getAllAnnouncements';
import saveAnnouncement from '@salesforce/apex/AdminController.saveAnnouncement';
import deleteAnnouncement from '@salesforce/apex/AdminController.deleteAnnouncement';

import getAllResources from '@salesforce/apex/AdminController.getAllResources';
import saveResource from '@salesforce/apex/AdminController.saveResource';
import deleteResource from '@salesforce/apex/AdminController.deleteResource';

import getAllSyllabus from '@salesforce/apex/AdminController.getAllSyllabus';
import saveSyllabus from '@salesforce/apex/AdminController.saveSyllabus';
import deleteSyllabus from '@salesforce/apex/AdminController.deleteSyllabus';

import getAllSessionLinks from '@salesforce/apex/AdminController.getAllSessionLinks';
import saveSessionLink from '@salesforce/apex/AdminController.saveSessionLink';
import deleteSessionLink from '@salesforce/apex/AdminController.deleteSessionLink';

import getAdminMetrics from '@salesforce/apex/AdminController.getAdminMetrics';
import getFilteredTasks from '@salesforce/apex/AdminController.getFilteredTasks';
import getTaskStats from '@salesforce/apex/AdminController.getTaskStats';
import getLeaveStats from '@salesforce/apex/AdminController.getLeaveStats';
import getTaskPriorityStats from '@salesforce/apex/AdminController.getTaskPriorityStats';

import getRecentActivities from '@salesforce/apex/AdminController.getRecentActivities';
import getTopInterns from '@salesforce/apex/AdminController.getTopInterns';
import getUpcomingDeadlines from '@salesforce/apex/AdminController.getUpcomingDeadlines';
import saveTask from '@salesforce/apex/AdminController.saveTask';
import deleteTask from '@salesforce/apex/AdminController.deleteTask';
import assignTaskToInterns from '@salesforce/apex/AdminController.assignTaskToInterns';
import saveIntern from '@salesforce/apex/AdminController.saveIntern';
import refreshSystemCache from '@salesforce/apex/InternWorkController.refreshSystemCache';

export default class LandingAdminDashboard extends LightningElement {
    @api token;
    @api role;

    // Logo
    logoUrl = LOGO;

    // Time and Date
    @track currentTime = '';
    @track currentDate = '';
    timeInterval;

    get isSuperAdmin() {
        return this.role === 'Super Admin';
    }

    @track currentTab = 'dashboard';
    @track metrics = { totalInterns: 0, pendingLeaves: 0, totalTasks: 0 };
    @track taskStats = { Completed: 0, InProgress: 0, Assigned: 0 };
    @track leaveStats = { Approved: 0, Pending: 0, Rejected: 0 };
    @track priorityStats = { High: 0, Medium: 0, Low: 0 };
    @track deadlineStats = { Urgent: 0, Upcoming: 0 };
    // @track debugRawData = ''; // Removed for cleaner production code

    // --- Dashboard Enhancements ---
    async loadDashboardData() {
        try {
            this.metrics = await getAdminMetrics({ token: this.token });

            const taskStatsRaw = await getTaskStats({ token: this.token });
            this.taskStats = {
                Completed: taskStatsRaw['Completed'] || 0,
                InProgress: taskStatsRaw['In Progress'] || 0,
                Assigned: taskStatsRaw['Assigned'] || 0
            };

            this.debugRawData += 'Fetching LeaveStats...\n';
            this.leaveStats = await getLeaveStats({ token: this.token });

            // 1. Priority Stats with Normalization
            try {
                const priorityData = await getTaskPriorityStats({ token: this.token });

                const processed = { High: 0, Medium: 0, Low: 0 };
                if (priorityData) {
                    Object.keys(priorityData).forEach(key => {
                        const lowerKey = key ? key.toLowerCase() : '';
                        const val = priorityData[key] || 0;
                        if (lowerKey === 'high') processed.High += val;
                        else if (lowerKey === 'medium' || lowerKey === 'normal') processed.Medium += val;
                        else if (lowerKey === 'low') processed.Low += val;
                    });
                }
                this.priorityStats = processed;
            } catch (pErr) {
                console.error('Priority Fetch Error:', pErr);
            }

            // Fetch Syllabus
            try {
                this.debugRawData += 'Fetching Syllabus...\n';
                const syllabus = await getAllSyllabus({ token: this.token });
                this.metrics = { ...this.metrics, syllabusCount: syllabus ? syllabus.length : 0 };
            } catch (sErr) {
                this.debugRawData += `[SYLLABUS ERROR]: ${sErr}\n`;
            }

            // Activities
            const acts = await getRecentActivities({ token: this.token });
            this.processActivities(acts);

            // Top Interns
            this.topInterns = await getTopInterns({ token: this.token });
            if (this.topInterns && this.topInterns.length > 0) {
                const maxTasks = this.topInterns[0].completedTasks || 1;
                this.topInterns = this.topInterns.map((intern) => {
                    const width = (intern.completedTasks / maxTasks) * 100;
                    return { ...intern, barStyle: `width: ${width}%` };
                });
            }

            // 2. Deadline Stats (Urgent vs Upcoming)
            try {
                this.debugRawData += 'Fetching Deadlines...\n';
                const rawDeadlines = await getUpcomingDeadlines({ token: this.token });
                this.debugRawData += `[DEADLINES RAW]: ${rawDeadlines ? rawDeadlines.length : 0} items\n`;
                console.log('Upcoming Deadlines Raw API v6:', JSON.stringify(rawDeadlines));
                this.upcomingDeadlines = rawDeadlines || [];

                let urgent = 0;
                let upcoming = 0;
                const today = new Date();
                const tomorrow = new Date(today); tomorrow.setDate(today.getDate() + 1);

                if (this.upcomingDeadlines) {
                    this.upcomingDeadlines.forEach(task => {
                        if (!task.Due_Date__c) return;
                        const dueDate = new Date(task.Due_Date__c);
                        if (dueDate <= tomorrow) urgent++;
                        else upcoming++;
                    });
                }
                this.deadlineStats = { Urgent: urgent, Upcoming: upcoming };
                this.debugRawData += `[DEADLINES PROCESSED]: ${JSON.stringify(this.deadlineStats)}\n`;
                console.log('Deadline Stats Computed v6:', JSON.stringify(this.deadlineStats));
            } catch (dErr) {
                console.error('Deadline Fetch Error:', dErr);
                this.debugRawData += `[DEADLINES ERROR]: ${dErr && dErr.body ? dErr.body.message : JSON.stringify(dErr)}\n`;
            }

        } catch (error) {
            console.error('Error loading dashboard:', error);
            this.debugRawData += `\n[FATAL ERROR]: ${error && error.body ? error.body.message : JSON.stringify(error)}`;
        }
    }

    // --- Chart Getters ---
    get taskCompletionRate() {
        const completed = parseInt(this.taskStats.Completed || 0, 10);
        const inProgress = parseInt(this.taskStats.InProgress || 0, 10);
        const assigned = parseInt(this.taskStats.Assigned || 0, 10);
        const total = completed + inProgress + assigned;

        if (total === 0) return 0;
        return Math.round((completed / total) * 100);
    }

    get taskChartData() {
        return `${this.taskCompletionRate}, 100`;
    }

    // SVG Donut Chart for Deadlines
    get deadlineUrgentStroke() {
        if (!this.deadlineStats) return '0, 100';
        const total = (this.deadlineStats.Urgent || 0) + (this.deadlineStats.Upcoming || 0);
        if (total === 0) return '0, 100';
        const pct = ((this.deadlineStats.Urgent || 0) / total) * 100;
        return `${pct} 100`;
    }

    get deadlineUpcomingStroke() {
        if (!this.deadlineStats) return '0, 100';
        const total = (this.deadlineStats.Urgent || 0) + (this.deadlineStats.Upcoming || 0);
        if (total === 0) return '0, 100';
        const pct = ((this.deadlineStats.Upcoming || 0) / total) * 100;
        return `${pct} 100`;
    }

    // Offset the Upcoming segment to start after the Urgent segment
    get deadlineUpcomingOffset() {
        if (!this.deadlineStats) return 0;
        const total = (this.deadlineStats.Urgent || 0) + (this.deadlineStats.Upcoming || 0);
        if (total === 0) return 0;
        const urgentPct = ((this.deadlineStats.Urgent || 0) / total) * 100;
        return -urgentPct; // Negative offset rotates it clockwise to the end of the previous segment
    }

    get priorityHighPercent() {
        if (!this.priorityStats) return 0;
        const total = this.taskCompletionRateTotal || 1; // Avoid div by zero
        return Math.round(((this.priorityStats.High || 0) / total) * 100);
    }

    get priorityMediumPercent() {
        if (!this.priorityStats) return 0;
        const total = this.taskCompletionRateTotal || 1;
        return Math.round(((this.priorityStats.Medium || this.priorityStats.Normal || 0) / total) * 100);
    }

    get taskCompletionRateTotal() {
        return (parseInt(this.taskStats.Completed || 0, 10) +
            parseInt(this.taskStats.InProgress || 0, 10) +
            parseInt(this.taskStats.Assigned || 0, 10));
    }



    // Priority Stacked Bar
    get priorityHighStyle() { return `width: ${this.getPriorityPct('High')}%`; }
    get priorityMedStyle() { return `width: ${this.getPriorityPct('Medium')}%`; } // Fixed Normal->Medium
    get priorityLowStyle() { return `width: ${this.getPriorityPct('Low')}%`; }

    // Stats Mapping for Legend
    get priorityDisplayStats() {
        return {
            High: this.priorityStats.High || 0,
            Medium: this.priorityStats.Medium || this.priorityStats.Normal || 0,
            Low: this.priorityStats.Low || 0
        };
    }

    getPriorityPct(type) {
        const high = this.priorityStats.High || 0;
        const med = this.priorityStats.Medium || this.priorityStats.Normal || 0;
        const low = this.priorityStats.Low || 0;
        const total = (high + med + low) || 1;

        let val = 0;
        if (type === 'High') val = high;
        else if (type === 'Medium' || type === 'Normal') val = med; // Handle both
        else if (type === 'Low') val = low;

        // console.log(`Priority PCT for ${type}: ${val} / ${total} = ${(val/total)*100}%`);
        return (val / total) * 100;
    }
    @track topInterns = [];
    @track upcomingDeadlines = [];

    // Intern Modal State
    @track isInternModalOpen = false;
    @track internForm = { Name: '', Email__c: '', Phone__c: '', College_Name__c: '', Roll_Number__c: '' };
    @track internErrors = { name: false, email: false };

    // --- Getters for UI State ---
    get currentTabTitle() {
        switch (this.currentTab) {
            case 'interns': return 'Intern Management';
            case 'leaves': return 'Leave Requests';
            case 'mentorship': return 'Mentorship Feedback';
            case 'logs': return null;
            case 'announcements': return 'Notice Board';
            case 'resources': return 'Learning Resources';
            case 'tasks': return 'Task Management';
            case 'syllabus': return null;
            default: return 'Dashboard';
        }
    }

    get showTopHeader() {
        // Hiding header for all tabs as they have their own specific card headers
        return false;
    }

    get taskModalTitle() {
        return this.selectedTaskId ? 'Edit Task' : 'Assign New Task';
    }

    get isDashboardTab() { return this.currentTab === 'dashboard'; }
    get isInternsTab() { return this.currentTab === 'interns'; }
    get isLeavesTab() { return this.currentTab === 'leaves'; }
    get isMentorshipTab() { return this.currentTab === 'mentorship'; }
    get isLogsTab() { return this.currentTab === 'logs'; }
    get isAnnouncementsTab() { return this.currentTab === 'announcements'; }
    get isResourcesTab() { return this.currentTab === 'resources'; }
    get isTasksTab() { return this.currentTab === 'tasks'; }
    get isSyllabusTab() { return this.currentTab === 'syllabus'; }

    // Nav Classes
    get navClassDashboard() { return this.currentTab === 'dashboard' ? 'active' : ''; }
    get navClassInterns() { return this.currentTab === 'interns' ? 'active' : ''; }
    get navClassLeaves() { return this.currentTab === 'leaves' ? 'active' : ''; }
    get navClassMentorship() { return this.currentTab === 'mentorship' ? 'active' : ''; }
    get navClassLogs() { return this.currentTab === 'logs' ? 'active' : ''; }
    get navClassAnnouncements() { return this.currentTab === 'announcements' ? 'active' : ''; }
    get navClassResources() { return this.currentTab === 'resources' ? 'active' : ''; }
    get navClassTasks() { return this.currentTab === 'tasks' ? 'active' : ''; }
    get navClassSyllabus() { return this.currentTab === 'syllabus' ? 'active' : ''; }
    get navClassSessionLinks() { return this.currentTab === 'sessionlinks' ? 'active' : ''; }

    get isSessionLinksTab() { return this.currentTab === 'sessionlinks'; }

    get userRoleLabel() {
        return this.role === 'Super Admin' ? 'Super Admin' : 'Team Lead';
    }

    get formattedRole() {
        return this.role === 'Super Admin' ? 'Admin' : 'Team Lead';
    }

    get isSuperAdmin() { return this.role === 'Super Admin'; }

    // --- Chart Calculations ---


    // --- Columns Definitions ---
    get internColumns() {
        const cols = [
            { label: 'Name', fieldName: 'Name' },
            { label: 'Email', fieldName: 'Email__c', type: 'email' },
            { label: 'College', fieldName: 'College_Name__c' }
        ];

        // Add Team Lead column only for Super Admins
        if (this.role === 'Super Admin') {
            cols.push({ label: 'Team Lead', fieldName: 'TeamLeadName' });
        }

        cols.push({
            type: 'action', typeAttributes: {
                rowActions: [
                    { label: 'Delete', name: 'delete' }
                ]
            }
        });
        return cols;
    }

    leaveColumns = [
        { label: 'Intern', fieldName: 'InternName' },
        { label: 'Date', fieldName: 'Start_Date__c', type: 'date' },
        { label: 'Reason', fieldName: 'Reason__c' },
        {
            label: 'Status', fieldName: 'Status__c',
            cellAttributes: { class: { fieldName: 'statusClass' } }
        },
        {
            type: 'action', typeAttributes: {
                rowActions: [
                    { label: 'Approve', name: 'approve' },
                    { label: 'Reject', name: 'reject' }
                ]
            }
        }
    ];

    mentorshipColumns = [
        { label: 'Intern', fieldName: 'InternName' },
        { label: 'Type', fieldName: 'Request_Type__c' },
        {
            label: 'Status', fieldName: 'Status__c',
            cellAttributes: { class: { fieldName: 'statusClass' } }
        },
        { label: 'Description', fieldName: 'Description__c' },
        {
            type: 'action', typeAttributes: {
                rowActions: [
                    { label: 'Reply', name: 'reply' }
                ]
            }
        }
    ];

    logColumns = [
        { label: 'Intern', fieldName: 'InternName' },
        { label: 'Date', fieldName: 'Log_Date__c', type: 'date' },
        { label: 'Course', fieldName: 'Course__c' },
        { label: 'Module', fieldName: 'Module__c' },
        { label: 'Topic', fieldName: 'Topic__c' },
        { label: 'Hours', fieldName: 'Hours_Spent__c', type: 'number' },
        { label: 'Description', fieldName: 'Work_Description__c' }
    ];

    announcementColumns = [
        { label: 'Message', fieldName: 'Message__c' },
        {
            label: 'Type', fieldName: 'Type__c',
            cellAttributes: { class: { fieldName: 'typeClass' } }
        },
        {
            type: 'action', typeAttributes: {
                rowActions: [
                    { label: 'Delete', name: 'delete' }
                ]
            }
        }
    ];

    resourceColumns = [
        { label: 'Title', fieldName: 'Title__c' },
        { label: 'Link', fieldName: 'Link__c', type: 'url' },
        {
            label: 'Type', fieldName: 'Type__c',
            cellAttributes: { class: { fieldName: 'typeClass' } }
        },
        {
            type: 'action', typeAttributes: {
                rowActions: [
                    { label: 'Delete', name: 'delete' }
                ]
            }
        }
    ];

    syllabusColumns = [
        { label: 'Course', fieldName: 'Course_Name__c', sortable: true },
        { label: 'Module', fieldName: 'Module_Name__c', sortable: true },
        { label: 'Topic', fieldName: 'Topic_Name__c', sortable: true },
        {
            type: 'action', typeAttributes: {
                rowActions: [
                    { label: 'Delete', name: 'delete' }
                ]
            }
        }
    ];

    get taskColumns() {
        return [
            { label: 'Task Name', fieldName: 'Name', sortable: true },
            { label: 'Assigned To', fieldName: 'InternName', sortable: true },
            { label: 'Priority', fieldName: 'Priority__c', sortable: true },
            {
                label: 'Due Date', fieldName: 'Due_Date__c', type: 'date', sortable: true,
                typeAttributes: {
                    year: "numeric",
                    month: "short",
                    day: "2-digit"
                }
            },
            {
                label: 'Status', fieldName: 'Status__c', sortable: true,
                cellAttributes: {
                    class: { fieldName: 'statusClass' }
                }
            },
            {
                type: 'action', typeAttributes: {
                    rowActions: [
                        { label: 'Edit', name: 'edit' },
                        { label: 'Delete', name: 'delete' }
                    ]
                }
            }
        ];
    }


    // --- Data Properties ---
    @track interns = [];
    @track leaves = [];
    @track mentorships = [];
    @track logs = [];
    @track announcements = [];
    @track announcementForm = { Message__c: '', Type__c: 'Primary' };

    @track resources = [];
    @track resourceForm = { Title__c: '', Link__c: '', Type__c: 'Video', Description__c: '' };

    @track tasks = [];
    @track taskStats = { Completed: 0, InProgress: 0, Assigned: 0 };
    @track activities = [];

    get internOptions() {
        return this.interns.map(i => ({ label: i.Name, value: i.Id }));
    }

    get priorityOptions() {
        return [
            { label: 'High', value: 'High', selected: this.taskForm.Priority__c === 'High' },
            { label: 'Medium', value: 'Medium', selected: this.taskForm.Priority__c === 'Medium' },
            { label: 'Low', value: 'Low', selected: this.taskForm.Priority__c === 'Low' }
        ];
    }

    get announcementTypeOptions() {
        return [
            { label: 'Primary', value: 'primary' },
            { label: 'Success', value: 'success' },
            { label: 'Warning', value: 'warning' },
            { label: 'Danger', value: 'danger' }
        ];
    }

    get resourceTypeOptions() {
        return [
            { label: 'Video', value: 'Video' },
            { label: 'Document', value: 'Document' },
            { label: 'Link', value: 'Link' }
        ];
    }

    // --- Modals State ---
    @track isMentorshipModalOpen = false;
    @track isAnnouncementModalOpen = false;
    @track isResourceModalOpen = false;
    @track isTaskModalOpen = false;

    // --- Wired Data ---
    wiredInternsResult;
    wiredLeavesResult;
    wiredMentorshipResult;
    wiredLogsResult;
    wiredAnnouncementsResult;
    wiredResourcesResult;
    wiredMetricsResult;
    wiredTasksResult;
    wiredStatsResult;
    wiredActivitiesResult;

    @wire(getTaskStats, { token: '$token' })
    wiredStats(result) {
        this.wiredStatsResult = result;
        if (result.data) {
            this.taskStats = {
                Completed: result.data['Completed'] || 0,
                InProgress: result.data['In Progress'] || 0,
                Assigned: result.data['Assigned'] || 0
            };
        }
    }

    @wire(getRecentActivities, { token: '$token' })
    wiredActivities(result) {
        this.wiredActivitiesResult = result;
        if (result.data) {
            this.activities = result.data.map(a => ({
                ...a,
                typeClass: `type-indicator ${a.type.toLowerCase()}`,
                activityDate: new Date(a.activityDate).toLocaleString([], { month: 'short', day: 'numeric', hour: '2-digit', minute: '2-digit' })
            }));
        }
    }

    @wire(getAdminMetrics, { token: '$token' })
    wiredMetrics(result) {
        this.wiredMetricsResult = result;
        if (result.data) this.metrics = result.data;
    }

    // --- Filter & Pagination State ---
    @track filterInternName = '';
    @track filterInternEmail = '';
    @track filterInternRoll = '';
    @track filterInternCollege = '';

    @track filterTaskName = '';
    @track filterDate = null;
    @track filterStatus = 'All';
    @track currentPage = 1;
    @track pageSize = 10;
    @track totalRecords = 0;

    handleInternFilterChange(event) {
        const field = event.target.dataset.field;
        const value = event.target.value ? event.target.value.toLowerCase() : '';

        if (field === 'internName') this.filterInternName = value;
        else if (field === 'internEmail') this.filterInternEmail = value;
        else if (field === 'internRoll') this.filterInternRoll = value;
        else if (field === 'internCollege') this.filterInternCollege = value;

        this.currentPageInterns = 1; // Reset pagination
    }

    // Mentorship Filters
    @track filterMentorshipInternName = '';
    @track filterMentorshipType = '';
    @track filterMentorshipStatus = '';

    handleMentorshipFilterChange(event) {
        const field = event.target.dataset.field;
        const value = event.target.value;

        if (field === 'mentorshipInternName') this.filterMentorshipInternName = value.toLowerCase();
        else if (field === 'mentorshipType') this.filterMentorshipType = value;
        else if (field === 'mentorshipStatus') this.filterMentorshipStatus = value;

        this.currentPageMentorship = 1;
    }

    get filteredInterns() {
        if (!this.interns) return [];
        return this.interns.filter(intern => {
            const matchName = !this.filterInternName || (intern.Name && intern.Name.toLowerCase().includes(this.filterInternName));
            const matchEmail = !this.filterInternEmail || (intern.Email__c && intern.Email__c.toLowerCase().includes(this.filterInternEmail));
            const matchRoll = !this.filterInternRoll || (intern.Roll_Number__c && intern.Roll_Number__c.toLowerCase().includes(this.filterInternRoll));
            const matchCollege = !this.filterInternCollege || (intern.College_Name__c && intern.College_Name__c.toLowerCase().includes(this.filterInternCollege));
            return matchName && matchEmail && matchRoll && matchCollege;
        });
    }

    get totalInternsCount() { return this.filteredInterns.length; }


    get totalPages() {
        return Math.ceil(this.totalRecords / this.pageSize);
    }

    get isFirstPage() { return this.currentPage === 1; }
    get isLastPage() { return this.currentPage >= this.totalPages; }

    get statusOptions() {
        return [
            { label: 'All Status', value: 'All' },
            { label: 'Assigned', value: 'Assigned' },
            { label: 'In Progress', value: 'In Progress' },
            { label: 'Completed', value: 'Completed' }
        ].map(opt => ({
            ...opt,
            selected: opt.value === this.filterStatus
        }));
    }

    connectedCallback() {
        this.loadTasks();
        this.loadDashboardData();
        this.updateDateTime();

        // Background Cache Refresh (Fix for 429 Errors)
        refreshSystemCache().catch(e => console.log('Cache Refresh Background:', e));

        // Update time every second
        this.timeInterval = setInterval(() => {
            this.updateDateTime();
        }, 1000);
    }

    disconnectedCallback() {
        // Clear interval when component is destroyed
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

    // Replace wiredTasks with this imperative method
    loadTasks() {
        getFilteredTasks({
            internName: this.filterInternName,
            taskName: this.filterTaskName,
            dueDate: this.filterDate,
            status: this.filterStatus,
            pageSize: this.pageSize,
            pageNumber: this.currentPage,
            token: this.token
        })
            .then(result => {
                this.tasks = result.tasks.map(t => {
                    let sClass = 'status-cell ';
                    if (t.Status__c === 'Completed') sClass += 'status-completed';
                    else if (t.Status__c === 'In Progress') sClass += 'status-inprogress';
                    else sClass += 'status-assigned';

                    return {
                        ...t,
                        InternName: t.Intern__r ? t.Intern__r.Name : 'Unassigned',
                        statusClass: sClass,
                        formattedDate: this.formatDate(t.Due_Date__c)
                    };
                });
                this.totalRecords = result.totalRecords;
            })
            .catch(error => {
                this.showToast('Error', 'Failed to load tasks', 'error');
                console.error(error);
            });
    }

    // Debounce timer
    searchTimer;

    handleFilterChange(event) {
        const field = event.target.dataset.field;
        this.currentPage = 1; // Reset to page 1 on filter change
        if (field === 'internName') this.filterInternName = event.target.value;
        if (field === 'taskName') this.filterTaskName = event.target.value;
        if (field === 'dueDate') this.filterDate = event.target.value;
        if (field === 'status') this.filterStatus = event.target.value;

        // Clear previous timer
        if (this.searchTimer) {
            clearTimeout(this.searchTimer);
        }

        // Set new timer for 300ms debounce
        this.searchTimer = setTimeout(() => {
            this.loadTasks();
        }, 300);
    }

    applyFilters() {
        this.currentPage = 1;
        this.loadTasks();
    }

    resetFilters() {
        this.filterInternName = '';
        this.filterTaskName = '';
        this.filterDate = null;
        this.filterStatus = 'All';
        this.currentPage = 1;
        this.loadTasks();
    }

    handlePreviousPage() {
        if (this.currentPage > 1) {
            this.currentPage--;
            this.loadTasks();
        }
    }

    handleNextPage() {
        if (this.currentPage < this.totalPages) {
            this.currentPage++;
            this.loadTasks();
        }
    }

    // --- Helper for Dates ---
    formatDate(dateStr) {
        if (!dateStr) return '';
        const options = { year: 'numeric', month: 'short', day: '2-digit' };
        return new Date(dateStr).toLocaleDateString(undefined, options);
    }

    // --- Helper for Times ---
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

    // --- Dashboard Enhancements ---
    async loadDashboardData() {
        try {
            console.log('--- Loading Dashboard Data ---');
            this.metrics = await getAdminMetrics({ token: this.token });
            this.taskStats = await getTaskStats({ token: this.token });

            // --- New Charts Data with Debugging ---
            try {
                const leaveData = await getLeaveStats({ token: this.token });
                console.log('Leave Stats Raw:', JSON.stringify(leaveData));
                // Ensure defaults
                this.leaveStats = { Approved: 0, Pending: 0, Rejected: 0, ...leaveData };
            } catch (e) {
                console.error('Error fetching Leave Stats:', e);
            }

            try {
                const priorityData = await getTaskPriorityStats({ token: this.token });
                console.log('Priority Stats Raw:', JSON.stringify(priorityData));

                // Robust Case-Insensitive Mapping
                let normalized = { High: 0, Medium: 0, Low: 0 };
                if (priorityData) {
                    for (const [key, value] of Object.entries(priorityData)) {
                        if (!key) {
                            normalized.Medium += value; // Default null to Medium
                            continue;
                        }
                        const lowerKey = key.toLowerCase();
                        if (lowerKey === 'high' || lowerKey.includes('urgent')) normalized.High += value;
                        else if (lowerKey === 'medium' || lowerKey === 'normal' || lowerKey.includes('med')) normalized.Medium += value;
                        else if (lowerKey === 'low') normalized.Low += value;
                        else normalized.Medium += value; // Fallback
                    }
                }
                this.priorityStats = normalized;
            } catch (e) {
                console.error('Error fetching Priority Stats:', e);
            }
            // -------------------------------------

            const acts = await getRecentActivities({ token: this.token });
            this.processActivities(acts);

            this.topInterns = await getTopInterns({ token: this.token });

            // Calculate Bar Widths for Top Performers
            if (this.topInterns && this.topInterns.length > 0) {
                const maxTasks = this.topInterns[0].completedTasks || 1;
                this.topInterns = this.topInterns.map((intern, index) => {
                    const width = (intern.completedTasks / maxTasks) * 100;
                    return {
                        ...intern,
                        rank: index + 1,
                        barStyle: `width: ${width}%`
                    };
                });
            }

            // Calculate Deadline Stats (Urgent vs Upcoming)
            this.upcomingDeadlines = await getUpcomingDeadlines({ token: this.token });

            let urgentCount = 0;
            let upcomingCount = 0;
            const today = new Date();
            const threeDaysFromNow = new Date();
            threeDaysFromNow.setDate(today.getDate() + 3);

            if (this.upcomingDeadlines) {
                this.upcomingDeadlines.forEach(task => {
                    if (task.Due_Date__c) {
                        const dueDate = new Date(task.Due_Date__c);
                        if (dueDate <= threeDaysFromNow) urgentCount++;
                        else upcomingCount++;
                    }
                });
            }
            this.deadlineStats = { Urgent: urgentCount, Upcoming: upcomingCount };

        } catch (error) {
            console.error('Error loading dashboard:', error);
        }
    }

    processActivities(acts) {
        if (!acts) return;
        this.activities = acts.map(act => {
            let typeClass = 'activity-icon';
            if (act.type === 'Intern') typeClass += ' icon-intern';
            else if (act.type === 'Leave') typeClass += ' icon-leave';
            else if (act.type === 'Task') typeClass += ' icon-task';
            else if (act.type === 'Mentorship') typeClass += ' icon-mentorship';
            else typeClass += ' icon-log';

            // Sanitize message to remove any stray HTML tags (like </div>) from data
            const cleanMessage = act.message ? act.message.replace(/<\/?[^>]+(>|$)/g, "") : '';

            return { ...act, message: cleanMessage, typeClass };
        });
    }

    // --- Intern Modal Logic ---
    openNewInternModal() {
        this.internForm = { Name: '', Email__c: '', Phone__c: '', College_Name__c: '', Roll_Number__c: '' };
        this.internErrors = { name: false, email: false };
        this.isInternModalOpen = true;
    }

    closeInternModal() { this.isInternModalOpen = false; }

    handleInternInputChange(e) {
        const field = e.target.dataset.field;
        this.internForm = { ...this.internForm, [field]: e.target.value };
        if (field === 'Name') this.internErrors.name = false;
        if (field === 'Email__c') this.internErrors.email = false;
    }

    get internNameClass() { return `premium-input ${this.internErrors.name ? 'input-error' : ''}`; }
    get internEmailClass() { return `premium-input ${this.internErrors.email ? 'input-error' : ''}`; }

    async saveInternRecord() {
        this.internErrors = { name: !this.internForm.Name, email: !this.internForm.Email__c };
        if (this.internErrors.name || this.internErrors.email) return;

        try {
            await saveIntern({ intern: this.internForm });
            this.showToast('Success', 'Intern Registered Successfully', 'success');
            this.closeInternModal();
            refreshApex(this.wiredInternsResult);
            this.loadDashboardData();
        } catch (error) {
            this.showToast('Error', 'Failed to register intern', 'error');
        }
    }

    @wire(getAllInterns, { token: '$token' })
    wiredInterns(result) {
        this.wiredInternsResult = result;

        if (result.data) {
            this.interns = result.data.map(row => ({
                ...row,
                TeamLeadName: row.Team_Lead__r ? row.Team_Lead__r.Name : 'None',
                mailtoEmail: 'mailto:' + row.Email__c
            }));
        } else if (result.error) {
            console.error('Interns Fetch Error:', result.error);
        }
    }

    @wire(getAllLeaveRequests, { token: '$token' })
    wiredLeaves(result) {
        this.wiredLeavesResult = result;
        if (result.data) {
            this.leaves = result.data.map(row => {
                let sClass = 'status-cell ';
                if (row.Status__c === 'Approved') sClass += 'status-completed'; // Green
                else if (row.Status__c === 'Rejected') sClass += 'status-rejected'; // Red
                else sClass += 'status-inprogress'; // Orange (Pending)

                return {
                    ...row,
                    InternName: row.Intern__r ? row.Intern__r.Name : '',
                    statusClass: sClass,
                    formattedDate: this.formatDate(row.Start_Date__c)
                };
            });
        }
    }

    @wire(getAllMentorshipRequests, { token: '$token' })
    wiredMentorship(result) {
        this.wiredMentorshipResult = result;
        if (result.data) {
            this.mentorships = result.data.map(row => {
                let sClass = 'status-cell ';
                if (row.Status__c === 'Completed') sClass += 'status-completed';
                else sClass += 'status-inprogress'; // Pending

                return {
                    ...row,
                    InternName: row.Intern__r ? row.Intern__r.Name : '',
                    statusClass: sClass
                };
            });
        }
    }

    @wire(getAllDailyLogs, { token: '$token' })
    wiredLogs(result) {
        this.wiredLogsResult = result;
        if (result.data) {
            this.logs = result.data.map(row => ({
                ...row,
                InternName: row.Intern__r ? row.Intern__r.Name : '',
                formattedDate: this.formatDate(row.Log_Date__c)
            }));
        } else if (result.error) {
            console.error('Error fetching Daily Logs:', result.error);
        }
    }

    @wire(getAllAnnouncements)
    wiredAnnouncements(result) {
        this.wiredAnnouncementsResult = result;
        if (result.data) {
            this.announcements = result.data.map(row => {
                let sClass = 'status-cell ';
                const type = (row.Type__c || 'primary').toLowerCase();
                if (type === 'success') sClass += 'status-success';
                else if (type === 'warning') sClass += 'status-warning';
                else if (type === 'danger') sClass += 'status-danger';
                else sClass += 'status-primary';

                return { ...row, typeClass: sClass };
            });
        }
    }

    @wire(getAllResources)
    wiredResources(result) {
        this.wiredResourcesResult = result;
        if (result.data) {
            this.resources = result.data.map(row => {
                let sClass = 'status-cell ';
                const type = (row.Type__c || 'Link');
                if (type === 'Video') sClass += 'status-video';
                else if (type === 'Document') sClass += 'status-document';
                else sClass += 'status-link';

                return { ...row, typeClass: sClass };
            });
        }
    }

    // --- Pagination Logic (Client-Side) ---
    @track currentPageInterns = 1;
    @track currentPageLeaves = 1;
    @track currentPageMentorship = 1;
    @track currentPageLogs = 1;
    @track currentPageAnnouncements = 1;
    @track currentPageResources = 1;


    // Helper to slice data
    paginateData(data, page) {
        if (!data) return [];
        const start = (page - 1) * this.pageSize;
        return data.slice(start, start + this.pageSize);
    }

    // --- Getters for Paginated Data & Counts ---
    get visibleInterns() { return this.paginateData(this.filteredInterns, this.currentPageInterns); }
    get totalInternsPages() { return Math.ceil(this.totalInternsCount / this.pageSize); }
    get isInternsFirstPage() { return this.currentPageInterns === 1; }
    get isInternsLastPage() { return this.currentPageInterns >= this.totalInternsPages; }

    get visibleLeaves() { return this.paginateData(this.leaves, this.currentPageLeaves); }
    get totalLeavesCount() { return this.leaves ? this.leaves.length : 0; }
    get totalLeavesPages() { return Math.ceil(this.totalLeavesCount / this.pageSize); }
    get isLeavesFirstPage() { return this.currentPageLeaves === 1; }
    get isLeavesLastPage() { return this.currentPageLeaves >= this.totalLeavesPages; }

    get filteredMentorshipRequests() {
        if (!this.mentorships) return [];
        return this.mentorships.filter(req => {
            const matchName = !this.filterMentorshipInternName || (req.InternName && req.InternName.toLowerCase().includes(this.filterMentorshipInternName));
            const matchType = !this.filterMentorshipType || (req.Request_Type__c === this.filterMentorshipType);
            const matchStatus = !this.filterMentorshipStatus || (req.Status__c === this.filterMentorshipStatus);
            return matchName && matchType && matchStatus;
        });
    }

    get visibleMentorships() { return this.paginateData(this.filteredMentorshipRequests, this.currentPageMentorship); }
    get totalMentorshipCount() { return this.filteredMentorshipRequests.length; }
    get totalMentorshipPages() { return Math.ceil(this.totalMentorshipCount / this.pageSize); }
    get isMentorshipFirstPage() { return this.currentPageMentorship === 1; }
    get isMentorshipLastPage() { return this.currentPageMentorship >= this.totalMentorshipPages; }

    // --- Logs Filter State ---
    @track logFilterInternName = '';
    @track selectedCourse = '';
    @track selectedModule = '';


    // --- Logs Filter Getters ---
    get courseOptions() {
        if (!this.syllabus) return [];
        const courses = [...new Set(this.syllabus.map(item => item.Course_Name__c))];
        return [{ label: 'All Courses', value: '' }, ...courses.map(c => ({ label: c, value: c }))];
    }

    get moduleOptions() {
        if (!this.selectedCourse || !this.syllabus) return [{ label: 'All Modules', value: '' }];
        const modules = [...new Set(this.syllabus
            .filter(item => item.Course_Name__c === this.selectedCourse)
            .map(item => item.Module_Name__c))];
        return [{ label: 'All Modules', value: '' }, ...modules.map(m => ({ label: m, value: m }))];
    }



    handleLogFilterChange(event) {
        const field = event.target.dataset.field;
        const value = event.target.value;

        if (field === 'internName') this.logFilterInternName = value;
        else if (field === 'course') {
            this.selectedCourse = value;
            this.selectedModule = '';
        }
        else if (field === 'module') {
            this.selectedModule = value;
        }

        this.currentPageLogs = 1; // Reset pagination
    }

    get visibleLogs() {
        let filtered = this.logs;

        if (this.logFilterInternName) {
            const lowerName = this.logFilterInternName.toLowerCase();
            filtered = filtered.filter(log => log.InternName && log.InternName.toLowerCase().includes(lowerName));
        }
        if (this.selectedCourse) {
            filtered = filtered.filter(log => log.Course__c === this.selectedCourse);
        }
        if (this.selectedModule) {
            filtered = filtered.filter(log => log.Module__c === this.selectedModule);
        }

        return this.paginateData(filtered, this.currentPageLogs);
    }
    get totalLogsCount() {
        let filtered = this.logs;
        if (filtered) {
            if (this.logFilterInternName) {
                const lowerName = this.logFilterInternName.toLowerCase();
                filtered = filtered.filter(log => log.InternName && log.InternName.toLowerCase().includes(lowerName));
            }
            if (this.selectedCourse) {
                filtered = filtered.filter(log => log.Course__c === this.selectedCourse);
            }
            if (this.selectedModule) {
                filtered = filtered.filter(log => log.Module__c === this.selectedModule);
            }
            return filtered.length;
        }
        return 0;
    }
    get totalLogsPages() { return Math.ceil(this.totalLogsCount / this.pageSize); }
    get isLogsFirstPage() { return this.currentPageLogs === 1; }
    get isLogsLastPage() { return this.currentPageLogs >= this.totalLogsPages; }

    get visibleAnnouncements() { return this.paginateData(this.announcements, this.currentPageAnnouncements); }
    get totalAnnouncementsCount() { return this.announcements ? this.announcements.length : 0; }
    get totalAnnouncementsPages() { return Math.ceil(this.totalAnnouncementsCount / this.pageSize); }
    get isAnnouncementsFirstPage() { return this.currentPageAnnouncements === 1; }
    get isAnnouncementsLastPage() { return this.currentPageAnnouncements >= this.totalAnnouncementsPages; }

    get visibleResources() { return this.paginateData(this.resources, this.currentPageResources); }
    get totalResourcesCount() { return this.resources ? this.resources.length : 0; }
    get totalResourcesPages() { return Math.ceil(this.totalResourcesCount / this.pageSize); }
    get isResourcesFirstPage() { return this.currentPageResources === 1; }
    get isResourcesLastPage() { return this.currentPageResources >= this.totalResourcesPages; }


    // --- Syllabus Logic ---
    @track syllabus = [];
    @track isSyllabusModalOpen = false;
    @track syllabusForm = { Course_Name__c: '', Module_Name__c: '', Topic_Name__c: '' };

    wiredSyllabusResult;

    @wire(getAllSyllabus)
    wiredSyllabus(result) {
        this.wiredSyllabusResult = result;
        if (result.data) {
            this.syllabus = result.data;
        } else if (result.error) {
            console.error('Error loading syllabus', result.error);
        }
    }

    // --- Syllabus Modal & Actions ---
    @track isSyllabusModalOpen = false;
    @track syllabusForm = {
        Id: null,
        Course_Name__c: '',
        Module_Name__c: ''
    };

    get syllabusModalTitle() {
        return this.syllabusForm.Id ? 'Edit Syllabus Topic' : 'Add Syllabus Topic';
    }

    openSyllabusModal() {
        this.syllabusForm = {
            Id: null,
            Course_Name__c: '',
            Module_Name__c: ''
        };
        this.isSyllabusModalOpen = true;
    }

    closeSyllabusModal() {
        this.isSyllabusModalOpen = false;
    }

    handleSyllabusInputChange(event) {
        const field = event.target.dataset.field;
        this.syllabusForm[field] = event.target.value;
    }

    handleSyllabusAction(event) {
        const action = event.currentTarget.dataset.action;
        const rowId = event.currentTarget.dataset.id;
        const row = this.syllabus.find(r => r.Id === rowId);

        if (action === 'delete') {
            if (confirm('Are you sure you want to delete this topic?')) { // Simple confirm for now
                deleteSyllabus({ syllabusId: rowId })
                    .then(() => {
                        this.showToast('Success', 'Topic deleted', 'success');
                        return refreshApex(this.wiredSyllabusResult);
                    })
                    .catch(error => {
                        this.showToast('Error', error.body.message, 'error');
                    });
            }
        } else if (action === 'edit') {
            this.syllabusForm = { ...row }; // Populate form
            this.isSyllabusModalOpen = true;
        }
    }

    saveSyllabusRecord() {
        const { Course_Name__c, Module_Name__c } = this.syllabusForm;
        if (!Course_Name__c || !Module_Name__c) {
            this.showToast('Error', 'All fields are required', 'error');
            return;
        }

        saveSyllabus({ syllabus: this.syllabusForm })
            .then(() => {
                this.showToast('Success', 'Syllabus saved successfully', 'success');
                this.closeSyllabusModal();
                return refreshApex(this.wiredSyllabusResult);
            })
            .catch(error => {
                this.showToast('Error', error.body.message, 'error');
            });
    }

    // --- Pagination for Syllabus ---
    @track currentPageSyllabus = 1;
    get visibleSyllabus() { return this.paginateData(this.syllabus, this.currentPageSyllabus); }
    get totalSyllabusCount() { return this.syllabus ? this.syllabus.length : 0; }
    get totalSyllabusPages() { return Math.ceil(this.totalSyllabusCount / this.pageSize); }
    get isSyllabusFirstPage() { return this.currentPageSyllabus === 1; }
    get isSyllabusLastPage() { return this.currentPageSyllabus >= this.totalSyllabusPages; }

    // --- Session Links Logic ---
    @track sessionLinks = [];
    @track currentPageSessionLinks = 1;
    @track isSessionLinksModalOpen = false;
    @track sessionLinksForm = {
        Id: null,
        Agenda__c: '',
        Date__c: '',
        Session_Start__c: '',
        Session_End__c: '',
        Session_URL__c: '',
        Speaker__c: ''
    };
    @track sessionLinksErrors = {
        agenda: false,
        date: false,
        startTime: false,
        endTime: false,
        url: false
    };
    wiredSessionLinksResult;

    @wire(getAllSessionLinks)
    wiredSessionLinks(result) {
        console.log('Wire getAllSessionLinks fired');
        console.log('Result:', JSON.stringify(result));

        this.wiredSessionLinksResult = result;
        if (result.data) {
            console.log('Session links data received:', result.data.length, 'records');
            this.sessionLinks = result.data.map(row => ({
                ...row,
                formattedDate: this.formatDate(row.Date__c),
                formattedStartTime: this.formatTime(row.Session_Start__c),
                formattedEndTime: this.formatTime(row.Session_End__c)
            }));
            console.log('Processed session links:', this.sessionLinks);
        } else if (result.error) {
            console.error('Error loading session links:', result.error);
            console.error('Error details:', JSON.stringify(result.error));
        }
    }

    get sessionLinksModalTitle() {
        return this.sessionLinksForm.Id ? 'Edit Session Link' : 'Add New Session Link';
    }

    get agendaInputClass() {
        return `premium-input ${this.sessionLinksErrors.agenda ? 'has-error' : ''}`;
    }

    get dateInputClass() {
        return `premium-input ${this.sessionLinksErrors.date ? 'has-error' : ''}`;
    }

    get startTimeInputClass() {
        return `premium-input ${this.sessionLinksErrors.startTime ? 'has-error' : ''}`;
    }

    get endTimeInputClass() {
        return `premium-input ${this.sessionLinksErrors.endTime ? 'has-error' : ''}`;
    }

    get urlInputClass() {
        return `premium-input ${this.sessionLinksErrors.url ? 'has-error' : ''}`;
    }

    openSessionLinksModal() {
        this.sessionLinksForm = {
            Id: null,
            Agenda__c: '',
            Date__c: '',
            Session_Start__c: '',
            Session_End__c: '',
            Session_URL__c: '',
            Speaker__c: ''
        };
        this.sessionLinksErrors = {
            agenda: false,
            date: false,
            startTime: false,
            endTime: false,
            url: false
        };
        this.isSessionLinksModalOpen = true;
    }

    closeSessionLinksModal() {
        this.isSessionLinksModalOpen = false;
    }

    handleSessionLinksInputChange(event) {
        const field = event.target.dataset.field;
        const value = event.target.value;
        this.sessionLinksForm = { ...this.sessionLinksForm, [field]: value };

        // Clear errors on input
        if (field === 'Agenda__c') {
            this.sessionLinksErrors = { ...this.sessionLinksErrors, agenda: false };
        } else if (field === 'Date__c') {
            this.sessionLinksErrors = { ...this.sessionLinksErrors, date: false };
        } else if (field === 'Session_Start__c') {
            this.sessionLinksErrors = { ...this.sessionLinksErrors, startTime: false };
        } else if (field === 'Session_End__c') {
            this.sessionLinksErrors = { ...this.sessionLinksErrors, endTime: false };
        } else if (field === 'Session_URL__c') {
            this.sessionLinksErrors = { ...this.sessionLinksErrors, url: false };
        }
    }

    async saveSessionLinksRecord() {
        // Validation
        let isValid = true;
        const newErrors = {
            agenda: false,
            date: false,
            startTime: false,
            endTime: false,
            url: false
        };

        if (!this.sessionLinksForm.Agenda__c?.trim()) {
            newErrors.agenda = true;
            isValid = false;
        }
        if (!this.sessionLinksForm.Date__c) {
            newErrors.date = true;
            isValid = false;
        }
        if (!this.sessionLinksForm.Session_Start__c) {
            newErrors.startTime = true;
            isValid = false;
        }
        if (!this.sessionLinksForm.Session_End__c) {
            newErrors.endTime = true;
            isValid = false;
        }
        if (!this.sessionLinksForm.Session_URL__c?.trim()) {
            newErrors.url = true;
            isValid = false;
        }

        this.sessionLinksErrors = newErrors;

        if (!isValid) {
            this.showToast('Error', 'Please fill in all required fields', 'error');
            return;
        }

        // Additional validation: End time should be after start time
        if (this.sessionLinksForm.Session_Start__c && this.sessionLinksForm.Session_End__c) {
            if (this.sessionLinksForm.Session_End__c <= this.sessionLinksForm.Session_Start__c) {
                this.sessionLinksErrors = { ...this.sessionLinksErrors, endTime: true };
                this.showToast('Error', 'End time must be after start time', 'error');
                return;
            }
        }

        try {
            console.log('Saving session link...');
            console.log('Session link form data:', JSON.stringify(this.sessionLinksForm));

            // Build the session link object properly
            // Remove Id field if it's null (for new records)
            const sessionLinkToSave = {
                Agenda__c: this.sessionLinksForm.Agenda__c,
                Date__c: this.sessionLinksForm.Date__c,
                Session_Start__c: this.sessionLinksForm.Session_Start__c + ':00.000', // Add seconds and milliseconds
                Session_End__c: this.sessionLinksForm.Session_End__c + ':00.000',     // Add seconds and milliseconds
                Session_URL__c: this.sessionLinksForm.Session_URL__c
            };

            // Only include Speaker if it has a value
            if (this.sessionLinksForm.Speaker__c && this.sessionLinksForm.Speaker__c.trim()) {
                sessionLinkToSave.Speaker__c = this.sessionLinksForm.Speaker__c;
            }

            // Only include Id if it exists (for updates)
            if (this.sessionLinksForm.Id) {
                sessionLinkToSave.Id = this.sessionLinksForm.Id;
            }

            console.log('Processed session link data:', JSON.stringify(sessionLinkToSave));

            await saveSessionLink({
                sessionLink: sessionLinkToSave
            });

            const message = this.sessionLinksForm.Id
                ? 'Session link updated successfully'
                : 'Session link created successfully';
            this.showToast('Success', message, 'success');

            this.closeSessionLinksModal();
            return refreshApex(this.wiredSessionLinksResult);
        } catch (error) {
            console.error('Error saving session link:', error);
            console.error('Error details:', JSON.stringify(error));

            // Handle different error structures
            let errorMessage = 'An error occurred while saving';
            if (error.body && error.body.message) {
                errorMessage = error.body.message;
            } else if (error.message) {
                errorMessage = error.message;
            } else if (typeof error === 'string') {
                errorMessage = error;
            }

            this.showToast('Error', errorMessage, 'error');
        }
    }

    async handleSessionLinksAction(event) {
        const action = event.currentTarget.dataset.action;
        const rowId = event.currentTarget.dataset.id;

        if (action === 'edit') {
            const row = this.sessionLinks.find(r => r.Id === rowId);
            if (row) {
                this.sessionLinksForm = {
                    Id: row.Id,
                    Agenda__c: row.Agenda__c || '',
                    Date__c: row.Date__c || '',
                    Session_Start__c: row.Session_Start__c || '',
                    Session_End__c: row.Session_End__c || '',
                    Session_URL__c: row.Session_URL__c || '',
                    Speaker__c: row.Speaker__c || ''
                };
                this.sessionLinksErrors = {
                    agenda: false,
                    date: false,
                    startTime: false,
                    endTime: false,
                    url: false
                };
                this.isSessionLinksModalOpen = true;
            }
        } else if (action === 'delete') {
            if (confirm('Are you sure you want to delete this session link? This action cannot be undone.')) {
                try {
                    await deleteSessionLink({
                        sessionLinkId: rowId
                    });
                    this.showToast('Success', 'Session link deleted successfully', 'success');

                    // Reset to first page if current page becomes empty
                    if (this.visibleSessionLinks.length === 1 && this.currentPageSessionLinks > 1) {
                        this.currentPageSessionLinks--;
                    }

                    return refreshApex(this.wiredSessionLinksResult);
                } catch (error) {
                    this.showToast('Error', error.body.message, 'error');
                }
            }
        }
    }

    // --- Pagination for Session Links ---
    get visibleSessionLinks() { return this.paginateData(this.sessionLinks, this.currentPageSessionLinks); }
    get totalSessionLinksCount() { return this.sessionLinks ? this.sessionLinks.length : 0; }
    get totalSessionLinksPages() { return Math.ceil(this.totalSessionLinksCount / this.pageSize); }
    get isSessionLinksFirstPage() { return this.currentPageSessionLinks === 1; }
    get isSessionLinksLastPage() { return this.currentPageSessionLinks >= this.totalSessionLinksPages; }


    // --- Pagination Handlers ---
    handlePrev(event) {
        const tab = event.target.dataset.tab;
        if (tab === 'interns' && this.currentPageInterns > 1) this.currentPageInterns--;
        if (tab === 'leaves' && this.currentPageLeaves > 1) this.currentPageLeaves--;
        if (tab === 'mentorship' && this.currentPageMentorship > 1) this.currentPageMentorship--;
        if (tab === 'logs' && this.currentPageLogs > 1) this.currentPageLogs--;
        if (tab === 'announcements' && this.currentPageAnnouncements > 1) this.currentPageAnnouncements--;
        if (tab === 'resources' && this.currentPageResources > 1) this.currentPageResources--;
        if (tab === 'syllabus' && this.currentPageSyllabus > 1) this.currentPageSyllabus--;
        if (tab === 'sessionlinks' && this.currentPageSessionLinks > 1) this.currentPageSessionLinks--;
    }

    handleNext(event) {
        const tab = event.target.dataset.tab;
        if (tab === 'interns' && this.currentPageInterns < this.totalInternsPages) this.currentPageInterns++;
        if (tab === 'leaves' && this.currentPageLeaves < this.totalLeavesPages) this.currentPageLeaves++;
        if (tab === 'mentorship' && this.currentPageMentorship < this.totalMentorshipPages) this.currentPageMentorship++;
        if (tab === 'logs' && this.currentPageLogs < this.totalLogsPages) this.currentPageLogs++;
        if (tab === 'announcements' && this.currentPageAnnouncements < this.totalAnnouncementsPages) this.currentPageAnnouncements++;
        if (tab === 'resources' && this.currentPageResources < this.totalResourcesPages) this.currentPageResources++;
        if (tab === 'syllabus' && this.currentPageSyllabus < this.totalSyllabusPages) this.currentPageSyllabus++;
        if (tab === 'sessionlinks' && this.currentPageSessionLinks < this.totalSessionLinksPages) this.currentPageSessionLinks++;
    }

    // --- Navigation ---
    handleTabSwitch(event) {
        this.currentTab = event.currentTarget.dataset.tab;
    }

    handleLogout() {
        this.dispatchEvent(new CustomEvent('logout'));
    }


    handleNavigateToTasks() {
        this.currentTab = 'tasks';
    }

    refreshDashboard() {
        refreshApex(this.wiredMetricsResult);
        refreshApex(this.wiredStatsResult);
        refreshApex(this.wiredActivitiesResult);
        refreshApex(this.wiredLogsResult);
    }

    // --- Actions ---
    async handleInternAction(event) {
        const action = event.currentTarget.dataset.action;
        const rowId = event.currentTarget.dataset.id;

        if (action === 'delete') {
            await deleteIntern({ internId: rowId });
            refreshApex(this.wiredInternsResult);
            this.refreshDashboard();
            this.showToast('Success', 'Intern deleted', 'success');
        }
    }

    async handleLeaveAction(event) {
        const action = event.currentTarget.dataset.action;
        const rowId = event.currentTarget.dataset.id;
        const status = action === 'approve' ? 'Approved' : 'Rejected';

        await updateLeaveStatus({ leaveId: rowId, status: status });
        refreshApex(this.wiredLeavesResult);
        this.refreshDashboard();
        this.showToast('Success', `Leave ${status}`, 'success');
    }

    // Mentorship Reply Logic
    @track selectedMentorshipId;
    @track mentorResponse = '';
    @track mentorErrors = { response: false };

    handleMentorshipAction(event) {
        const action = event.currentTarget.dataset.action;
        const rowId = event.currentTarget.dataset.id;
        const row = this.mentorships.find(r => r.Id === rowId);

        if (action === 'reply') {
            this.selectedMentorshipId = rowId;
            this.mentorResponse = row.Mentor_Response__c || '';
            this.mentorErrors = { response: false };
            this.isMentorshipModalOpen = true;
        }
    }

    closeMentorshipModal() { this.isMentorshipModalOpen = false; }

    handleResponseChangeCustom(e) {
        this.mentorResponse = e.target.value;
        this.mentorErrors = { response: false };
    }

    get mentorResponseClass() { return `premium-input ${this.mentorErrors.response ? 'has-error' : ''}`; }

    async saveMentorshipReply() {
        if (!this.mentorResponse) {
            this.mentorErrors = { response: true };
            this.showToast('Error', 'Response is required.', 'error');
            return;
        }

        try {
            await replyToMentorship({ requestId: this.selectedMentorshipId, response: this.mentorResponse, status: 'Completed' });
            this.isMentorshipModalOpen = false;
            refreshApex(this.wiredMentorshipResult);
            this.refreshDashboard();
            this.showToast('Success', 'Reply sent', 'success');
        } catch (error) {
            this.showToast('Error', error.body.message, 'error');
        }
    }

    // --- Announcement Logic ---
    @track announcementErrors = { message: false };

    async handleAnnouncementAction(event) {
        const action = event.detail.action.name;
        const rowId = event.detail.row.Id;
        if (action === 'delete') {
            await deleteAnnouncement({ announcementId: rowId });
            refreshApex(this.wiredAnnouncementsResult);
            this.showToast('Success', 'Announcement deleted', 'success');
        }
    }

    openAnnouncementModal() {
        this.announcementForm = { Message__c: '', Type__c: 'primary' };
        this.announcementErrors = { message: false };
        this.isAnnouncementModalOpen = true;
    }
    closeAnnouncementModal() { this.isAnnouncementModalOpen = false; }

    handleAnnouncementInputChangeCustom(event) {
        const field = event.target.dataset.field;
        const value = event.target.value;
        this.announcementForm = { ...this.announcementForm, [field]: value };

        // Clear errors
        if (field === 'Message__c') this.announcementErrors = { ...this.announcementErrors, message: false };
    }

    get announcementMessageClass() { return `premium-input ${this.announcementErrors.message ? 'has-error' : ''}`; }

    get announcementTypeOptionsComputed() {
        return [
            { label: 'Primary', value: 'primary' },
            { label: 'Success', value: 'success' },
            { label: 'Warning', value: 'warning' },
            { label: 'Danger', value: 'danger' }
        ].map(opt => ({
            ...opt,
            selected: opt.value === this.announcementForm.Type__c
        }));
    }

    async saveAnnouncementRecord() {
        // Validation
        let isValid = true;

        if (!this.announcementForm.Message__c) {
            this.announcementErrors = { message: true };
            isValid = false;
        }

        if (!isValid) {
            this.showToast('Error', 'Message is required.', 'error');
            return;
        }

        try {
            await saveAnnouncement({ announcement: this.announcementForm });
            this.showToast('Success', 'Announcement saved', 'success');
            this.closeAnnouncementModal();
            refreshApex(this.wiredAnnouncementsResult);
        } catch (error) {
            this.showToast('Error', error.body.message, 'error');
        }
    }

    // --- Resource Logic ---
    @track resourceErrors = { title: false, link: false };

    async handleResourceAction(event) {
        const action = event.detail.action.name;
        const row = event.detail.row;
        if (action === 'delete') {
            await deleteResource({ resourceId: row.Id });
            refreshApex(this.wiredResourcesResult);
            this.showToast('Success', 'Resource deleted', 'success');
        }
    }

    openResourceModal() {
        this.resourceForm = { Title__c: '', Link__c: '', Type__c: 'Video', Description__c: '' };
        this.resourceErrors = { title: false, link: false };
        this.isResourceModalOpen = true;
    }
    closeResourceModal() { this.isResourceModalOpen = false; }

    handleResourceInputChangeCustom(event) {
        const field = event.target.dataset.field;
        const value = event.target.value;
        this.resourceForm = { ...this.resourceForm, [field]: value };

        // Clear errors
        if (field === 'Title__c') this.resourceErrors = { ...this.resourceErrors, title: false };
        if (field === 'Link__c') this.resourceErrors = { ...this.resourceErrors, link: false };
    }

    get resourceTitleClass() { return `premium-input ${this.resourceErrors.title ? 'has-error' : ''}`; }
    get resourceLinkClass() { return `premium-input ${this.resourceErrors.link ? 'has-error' : ''}`; }

    get resourceTypeOptionsComputed() {
        return [
            { label: 'Video', value: 'Video' },
            { label: 'Document', value: 'Document' },
            { label: 'Link', value: 'Link' }
        ].map(opt => ({
            ...opt,
            selected: opt.value === this.resourceForm.Type__c
        }));
    }

    async saveResourceRecord() {
        // Validation
        let isValid = true;
        const newErrors = { title: false, link: false };

        if (!this.resourceForm.Title__c) {
            newErrors.title = true;
            isValid = false;
        }
        if (!this.resourceForm.Link__c) {
            newErrors.link = true;
            isValid = false;
        }

        this.resourceErrors = newErrors;

        if (!isValid) {
            this.showToast('Error', 'Please correct the errors.', 'error');
            return;
        }

        try {
            await saveResource({ resource: this.resourceForm });
            this.showToast('Success', 'Resource saved', 'success');
            this.closeResourceModal();
            refreshApex(this.wiredResourcesResult);
        } catch (error) {
            this.showToast('Error', error.body.message, 'error');
        }
    }

    // --- Task Logic ---
    @track selectedTaskId;
    @track taskForm = { Name: '', Intern__c: '', Priority__c: 'Medium', Due_Date__c: '', Description__c: '', Status__c: 'Assigned' };
    @track errors = { name: false, date: false, assign: false };

    async handleTaskAction(event) {
        const action = event.currentTarget.dataset.action;
        const rowId = event.currentTarget.dataset.id;

        if (action === 'delete') {
            const confirmed = await LightningConfirm.open({
                message: 'Are you sure you want to delete this task?',
                variant: 'headerless',
                label: 'Confirm Delete',
            });
            if (confirmed) {
                this.handleDeleteTask(rowId);
            }
        } else if (action === 'edit') {
            const row = this.tasks.find(r => r.Id === rowId);
            if (row) {
                this.selectedTaskId = row.Id;
                // Map formatting back to raw values if needed, mainly Intern__r -> Intern__c
                this.taskForm = {
                    ...row,
                    Intern__c: row.Intern__c || (row.Intern__r ? row.Intern__r.Id : ''),
                    Due_Date__c: row.Due_Date__c // Use raw date for input
                };
                this.isTaskModalOpen = true;
            }
        }
    }

    openTaskModal() {
        this.selectedTaskId = null;
        this.taskForm = { Name: '', Intern__c: '', Priority__c: 'Medium', Due_Date__c: '', Description__c: '', Status__c: 'Assigned' };
        this.searchTerm = '';
        this.isSelectAll = false;
        this.errors = { name: false, date: false, assign: false }; // Reset errors
        this.isTaskModalOpen = true;
    }

    closeTaskModal() { this.isTaskModalOpen = false; }

    handleTaskInputChangeCustom(event) {
        const field = event.target.dataset.field;
        const value = event.target.value;
        this.taskForm = { ...this.taskForm, [field]: value };

        // Clear error on input
        if (field === 'Name') this.errors = { ...this.errors, name: false };
        if (field === 'Due_Date__c') this.errors = { ...this.errors, date: false };
    }

    // --- Error Class Getters ---
    get nameInputClass() { return `premium-input ${this.errors.name ? 'has-error' : ''}`; }
    get dateInputClass() { return `premium-input ${this.errors.date ? 'has-error' : ''}`; }
    get assignContainerClass() { return `slds-form-element ${this.errors.assign ? 'has-error-boundary' : ''}`; }

    // --- New Task Assignment Logic ---
    @track searchTerm = '';
    @track isSelectAll = false;

    get showInternList() {
        return this.searchTerm && this.searchTerm.length > 0;
    }

    get taskInternOptions() {
        if (!this.interns) return [];
        // If select all is on, we don't show the list (handled in HTML via if:false={isSelectAll})
        if (this.isSelectAll) return [];

        const lowerTerm = this.searchTerm.toLowerCase();

        // Return empty if no search term
        if (!lowerTerm) return [];

        return this.interns
            .filter(intern => (intern.Name && intern.Name.toLowerCase().includes(lowerTerm)))
            .map(intern => {
                const isChecked = this.taskForm.Intern__c === intern.Id;
                const names = intern.Name ? intern.Name.split(' ') : ['?'];
                const initials = names.length > 1
                    ? names[0][0] + names[names.length - 1][0]
                    : names[0].substring(0, 2);

                return {
                    ...intern,
                    isChecked: isChecked,
                    cardClass: `intern-option-card ${isChecked ? 'selected' : ''}`,
                    initials: initials.toUpperCase()
                };
            });
    }

    handleInternSearch(event) {
        this.searchTerm = event.target.value;
    }

    clearSearch() {
        this.searchTerm = '';
    }

    handleSelectAll(event) {
        this.isSelectAll = event.target.checked;
        if (this.isSelectAll) {
            this.taskForm = { ...this.taskForm, Intern__c: null };
            this.searchTerm = '';
            this.errors = { ...this.errors, assign: false };
        }
    }

    handleInternSelect(event) {
        this.taskForm = { ...this.taskForm, Intern__c: event.target.value };
        this.isSelectAll = false;
        this.errors = { ...this.errors, assign: false };
    }

    async saveTaskRecord() {
        // --- Validation ---
        let isValid = true;
        const newErrors = { name: false, date: false, assign: false };

        if (!this.taskForm.Name) {
            newErrors.name = true;
            isValid = false;
        }
        if (!this.taskForm.Due_Date__c) {
            newErrors.date = true;
            isValid = false;
        }
        // Must select all OR pick a specific intern
        if (!this.isSelectAll && !this.taskForm.Intern__c) {
            newErrors.assign = true;
            isValid = false;
        }

        this.errors = newErrors;

        if (!isValid) {
            this.showToast('Error', 'Please correct the errors in the form.', 'error');
            return;
        }

        try {
            if (this.selectedTaskId) {
                // Edit Mode - Single Update
                const taskToSave = {
                    Id: this.selectedTaskId,
                    Name: this.taskForm.Name,
                    Intern__c: this.taskForm.Intern__c,
                    Priority__c: this.taskForm.Priority__c,
                    Due_Date__c: this.taskForm.Due_Date__c,
                    Description__c: this.taskForm.Description__c,
                    Status__c: this.taskForm.Status__c
                };
                await saveTask({ task: taskToSave });
            } else {
                // Create Mode - Potentially Bulk
                await assignTaskToInterns({
                    taskTemplate: this.taskForm,
                    targetInternIds: this.taskForm.Intern__c ? [this.taskForm.Intern__c] : [],
                    assignToAll: this.isSelectAll,
                    token: this.token
                });
            }

            this.showToast('Success', 'Task(s) saved successfully', 'success');
            this.closeTaskModal();
            this.loadTasks();
            this.refreshDashboard();
        } catch (error) {
            this.showToast('Error', error.body ? error.body.message : error.message, 'error');
        }
    }

    async handleDeleteTask(taskId) {
        try {
            await deleteTask({ taskId });
            this.showToast('Success', 'Task deleted', 'success');
            this.loadTasks();
            this.refreshDashboard();
        } catch (error) {
            this.showToast('Error', error.body.message, 'error');
        }
    }

    // --- Helpers ---
    showToast(title, message, variant) {
        let finalMessage = message;
        if (variant === 'error' && typeof message === 'string') {
            const lowerMsg = message.toLowerCase();
            if (lowerMsg.includes('429') || lowerMsg.includes('quota') || lowerMsg.includes('limit') || lowerMsg.includes('resource_exhausted')) {
                finalMessage = 'The server is currently busy. Please wait a moment and try again.';
            }
        }
        this.dispatchEvent(new ShowToastEvent({ title, message: finalMessage, variant }));
    }

    // --- Navigation ---
    handleTabSwitch(event) {
        this.currentTab = event.currentTarget.dataset.tab;
    }

    handleLogout() {
        this.dispatchEvent(new CustomEvent('logout'));
    }

    handleNavigateToTasks() {
        this.currentTab = 'tasks';
    }
}
