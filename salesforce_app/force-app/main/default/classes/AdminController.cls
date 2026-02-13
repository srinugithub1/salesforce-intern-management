public without sharing class AdminController {
    // Sync Version 2.0 - Forced Refresh
    
    public class AdminMetrics {
        @AuraEnabled public Integer totalInterns;
        @AuraEnabled public Integer pendingLeaves;
        @AuraEnabled public Integer totalTasks;
    }

    // --- Helper for Token Validation & Role Fetching ---
    private static Admin_User__c getAuthenticatedAdmin(String token) {
        if (String.isBlank(token)) throw new AuraHandledException('Session Expired. Please login again.');
        List<Admin_User__c> admins = [SELECT Id, Role__c FROM Admin_User__c WHERE Session_Token__c = :token LIMIT 1];
        if (admins.isEmpty()) throw new AuraHandledException('Invalid Session');
        return admins[0];
    }

    // --- Intern Management ---
    @AuraEnabled(cacheable=true)
    public static List<Intern__c> getAllInterns(String token) {
        Admin_User__c admin = getAuthenticatedAdmin(token);
        if (admin.Role__c == 'Super Admin') {
            return [SELECT Id, Name, Email__c, Phone__c, College_Name__c, Roll_Number__c, Address__c, Start_Date__c, End_Date__c, Team_Lead__r.Name 
                    FROM Intern__c 
                    ORDER BY Name ASC];
        } else {
            return [SELECT Id, Name, Email__c, Phone__c, College_Name__c, Roll_Number__c, Address__c, Start_Date__c, End_Date__c, Team_Lead__r.Name 
                    FROM Intern__c 
                    WHERE Team_Lead__c = :admin.Id 
                    ORDER BY Name ASC];
        }
    }

    @AuraEnabled(cacheable=true)
    public static AdminMetrics getAdminMetrics(String token) {
        Admin_User__c admin = getAuthenticatedAdmin(token);
        AdminMetrics m = new AdminMetrics();
        Id adminId = admin.Id;

        if (admin.Role__c == 'Super Admin') {
            m.totalInterns = [SELECT count() FROM Intern__c];
            m.pendingLeaves = [SELECT count() FROM Leave_Request__c WHERE Status__c = 'Pending'];
            m.totalTasks = [SELECT count() FROM Intern_Task__c];
        } else {
            List<Intern__c> myInterns = [SELECT Id FROM Intern__c WHERE Team_Lead__c = :adminId];
            Set<Id> internIds = new Set<Id>();
            for(Intern__c i : myInterns) internIds.add(i.Id);

            m.totalInterns = myInterns.size();
            m.pendingLeaves = [SELECT count() FROM Leave_Request__c WHERE Status__c = 'Pending' AND Intern__c IN :internIds];
            m.totalTasks = [SELECT count() FROM Intern_Task__c WHERE Intern__c IN :internIds];
        }
        return m;
    }

    @AuraEnabled
    public static void saveIntern(Intern__c intern) {
        try { upsert intern; } catch (Exception e) { throw new AuraHandledException(e.getMessage()); }
    }

    @AuraEnabled
    public static void deleteIntern(Id internId) {
        try { delete [SELECT Id FROM Intern__c WHERE Id = :internId]; } catch (Exception e) { throw new AuraHandledException(e.getMessage()); }
    }

    // --- Leave Management ---
    @AuraEnabled(cacheable=true)
    public static List<Leave_Request__c> getAllLeaveRequests(String token) {
        Admin_User__c admin = getAuthenticatedAdmin(token);
        if (admin.Role__c == 'Super Admin') {
            return [SELECT Id, Intern__r.Name, Start_Date__c, End_Date__c, Reason__c, Status__c 
                    FROM Leave_Request__c 
                    ORDER BY CreatedDate DESC];
        } else {
            return [SELECT Id, Intern__r.Name, Start_Date__c, End_Date__c, Reason__c, Status__c 
                    FROM Leave_Request__c 
                    WHERE Intern__r.Team_Lead__c = :admin.Id 
                    ORDER BY CreatedDate DESC];
        }
    }

    @AuraEnabled
    public static void updateLeaveStatus(Id leaveId, String status) {
        try { update new Leave_Request__c(Id = leaveId, Status__c = status); } catch (Exception e) { throw new AuraHandledException(e.getMessage()); }
    }

    // --- Mentorship Management ---
    @AuraEnabled(cacheable=true)
    public static List<Mentorship_Request__c> getAllMentorshipRequests(String token) {
        Admin_User__c admin = getAuthenticatedAdmin(token);
        if (admin.Role__c == 'Super Admin') {
            return [SELECT Id, Intern__r.Name, Request_Type__c, Description__c, Status__c, Mentor_Response__c, CreatedDate 
                    FROM Mentorship_Request__c 
                    ORDER BY CreatedDate DESC];
        } else {
            return [SELECT Id, Intern__r.Name, Request_Type__c, Description__c, Status__c, Mentor_Response__c, CreatedDate 
                    FROM Mentorship_Request__c 
                    WHERE Intern__r.Team_Lead__c = :admin.Id 
                    ORDER BY CreatedDate DESC];
        }
    }

    @AuraEnabled
    public static void replyToMentorship(Id requestId, String response, String status) {
        try { update new Mentorship_Request__c(Id = requestId, Mentor_Response__c = response, Status__c = status); } catch (Exception e) { throw new AuraHandledException(e.getMessage()); }
    }

    // --- Daily Logs ---
    @AuraEnabled(cacheable=true)
    public static List<Daily_Log__c> getAllDailyLogs(String token) {
        Admin_User__c admin = getAuthenticatedAdmin(token);
        if (admin.Role__c == 'Super Admin') {
            return [SELECT Id, Intern__r.Name, Log_Date__c, Hours_Spent__c, Work_Description__c, Course__c, Module__c, Topic__c 
                    FROM Daily_Log__c 
                    ORDER BY Log_Date__c DESC LIMIT 500];
        } else {
            return [SELECT Id, Intern__r.Name, Log_Date__c, Hours_Spent__c, Work_Description__c, Course__c, Module__c, Topic__c 
                    FROM Daily_Log__c 
                    WHERE Intern__r.Team_Lead__c = :admin.Id 
                    ORDER BY Log_Date__c DESC LIMIT 500];
        }
    }

    // --- Announcements ---
    @AuraEnabled(cacheable=true)
    public static List<Announcement__c> getAllAnnouncements() {
        return [SELECT Id, Message__c, Type__c, CreatedDate FROM Announcement__c ORDER BY CreatedDate DESC];
    }

    @AuraEnabled
    public static void saveAnnouncement(Announcement__c announcement) {
        try { upsert announcement; } catch (Exception e) { throw new AuraHandledException(e.getMessage()); }
    }

    @AuraEnabled
    public static void deleteAnnouncement(Id announcementId) {
        try { delete [SELECT Id FROM Announcement__c WHERE Id = :announcementId]; } catch (Exception e) { throw new AuraHandledException(e.getMessage()); }
    }

     // --- Resources ---
    @AuraEnabled(cacheable=true)
    public static List<Resource__c> getAllResources() {
        return [SELECT Id, Title__c, Link__c, Type__c, Description__c FROM Resource__c ORDER BY CreatedDate DESC];
    }

    @AuraEnabled
    public static void saveResource(Resource__c resource) {
        try { upsert resource; } catch (Exception e) { throw new AuraHandledException(e.getMessage()); }
    }

    @AuraEnabled
    public static void deleteResource(Id resourceId) {
        try { delete [SELECT Id FROM Resource__c WHERE Id = :resourceId]; } catch (Exception e) { throw new AuraHandledException(e.getMessage()); }
    }

    // --- Task Management ---
    @AuraEnabled(cacheable=true)
    public static List<Intern_Task__c> getAllTasks(String token) {
        Admin_User__c admin = getAuthenticatedAdmin(token);
        if (admin.Role__c == 'Super Admin') {
            return [SELECT Id, Name, Intern__r.Name, Status__c, Due_Date__c, Priority__c, Description__c 
                    FROM Intern_Task__c 
                    ORDER BY Due_Date__c ASC];
        } else {
            List<Intern__c> myInterns = [SELECT Id FROM Intern__c WHERE Team_Lead__c = :admin.Id];
            Set<Id> internIds = new Set<Id>();
            for(Intern__c i : myInterns) internIds.add(i.Id);
            return [SELECT Id, Name, Intern__r.Name, Status__c, Due_Date__c, Priority__c, Description__c 
                    FROM Intern_Task__c 
                    WHERE Intern__c IN :internIds 
                    ORDER BY Due_Date__c ASC];
        }
    }

    @AuraEnabled
    public static void saveTask(Intern_Task__c task) {
        try { upsert task; } catch (Exception e) { throw new AuraHandledException(e.getMessage()); }
    }

    @AuraEnabled
    public static void deleteTask(Id taskId) {
        try { delete [SELECT Id FROM Intern_Task__c WHERE Id = :taskId]; } catch (Exception e) { throw new AuraHandledException(e.getMessage()); }
    }

    @AuraEnabled
    public static void assignTaskToInterns(Intern_Task__c taskTemplate, List<Id> targetInternIds, Boolean assignToAll, String token) {
        Admin_User__c admin = getAuthenticatedAdmin(token);
        List<Intern_Task__c> tasksToInsert = new List<Intern_Task__c>();
        List<Intern__c> targetInterns = new List<Intern__c>();

        if (assignToAll) {
            if (admin.Role__c == 'Super Admin') {
                targetInterns = [SELECT Id FROM Intern__c];
            } else {
                targetInterns = [SELECT Id FROM Intern__c WHERE Team_Lead__c = :admin.Id];
            }
        } else {
             if (targetInternIds != null && !targetInternIds.isEmpty()) {
                targetInterns = [SELECT Id FROM Intern__c WHERE Id IN :targetInternIds];
             }
        }

        for (Intern__c intern : targetInterns) {
            Intern_Task__c newTask = taskTemplate.clone(false, true, false, false);
            newTask.Intern__c = intern.Id;
            newTask.Status__c = 'Assigned'; 
            tasksToInsert.add(newTask);
        }

        if (!tasksToInsert.isEmpty()) {
            try {
                insert tasksToInsert;
            } catch (Exception e) {
                throw new AuraHandledException(e.getMessage());
            }
        }
    }

    // --- Social & Visual Features ---
    public class ActivityWrapper {
        @AuraEnabled public String id;
        @AuraEnabled public String type; // 'Intern', 'Leave', 'Task'
        @AuraEnabled public String message;
        @AuraEnabled public Datetime activityDate;
        @AuraEnabled public String relativeTime;
    }

    @AuraEnabled(cacheable=true)
    public static List<ActivityWrapper> getRecentActivities(String token) {
        Admin_User__c admin = getAuthenticatedAdmin(token);
        List<ActivityWrapper> activities = new List<ActivityWrapper>();

        // 1. New Interns
        List<Intern__c> interns = [SELECT Id, Name, CreatedDate FROM Intern__c ORDER BY CreatedDate DESC LIMIT 5];
        for (Intern__c i : interns) {
            ActivityWrapper w = new ActivityWrapper();
            w.id = i.Id; w.type = 'Intern'; w.message = 'New Intern: ' + i.Name; w.activityDate = i.CreatedDate;
            activities.add(w);
        }

        // 2. New Leaves
        List<Leave_Request__c> leaves = [SELECT Id, Intern__r.Name, CreatedDate FROM Leave_Request__c ORDER BY CreatedDate DESC LIMIT 5];
        for (Leave_Request__c l : leaves) {
            ActivityWrapper w = new ActivityWrapper();
            w.id = l.Id; w.type = 'Leave'; w.message = 'Leave Request from ' + l.Intern__r.Name; w.activityDate = l.CreatedDate;
            activities.add(w);
        }

        // 3. Task Status Updates (Based on LastModified)
        List<Intern_Task__c> tasks = [SELECT Id, Name, LastModifiedDate FROM Intern_Task__c ORDER BY LastModifiedDate DESC LIMIT 5];
        for (Intern_Task__c t : tasks) {
            ActivityWrapper w = new ActivityWrapper();
            w.id = t.Id; w.type = 'Task'; w.message = 'Task Updated: ' + t.Name; w.activityDate = t.LastModifiedDate;
            activities.add(w);
        }

        // 4. Mentorship Requests
        List<Mentorship_Request__c> mentors = [SELECT Id, Intern__r.Name, CreatedDate FROM Mentorship_Request__c ORDER BY CreatedDate DESC LIMIT 5];
        for (Mentorship_Request__c m : mentors) {
            ActivityWrapper w = new ActivityWrapper();
            w.id = m.Id; w.type = 'Mentorship'; w.message = 'Mentorship Request: ' + m.Intern__r.Name; w.activityDate = m.CreatedDate;
            activities.add(w);
        }

        // 5. Work Logs
        List<Daily_Log__c> logs = [SELECT Id, Intern__r.Name, Hours_Spent__c, CreatedDate FROM Daily_Log__c ORDER BY CreatedDate DESC LIMIT 5];
        for (Daily_Log__c l : logs) {
            ActivityWrapper w = new ActivityWrapper();
            w.id = l.Id; w.type = 'Log'; w.message = l.Intern__r.Name + ' logged ' + l.Hours_Spent__c + 'h'; w.activityDate = l.CreatedDate;
            activities.add(w);
        }

        // Sort by Date DESC
        for (Integer i = 0; i < activities.size(); i++) {
            for (Integer j = i + 1; j < activities.size(); j++) {
                if (activities[i].activityDate < activities[j].activityDate) {
                    ActivityWrapper temp = activities[i];
                    activities[i] = activities[j];
                    activities[j] = temp;
                }
            }
        }

        // Return top 10
        List<ActivityWrapper> result = new List<ActivityWrapper>();
        for (Integer i = 0; i < Math.min(10, activities.size()); i++) result.add(activities[i]);
        return result;
    }

    // --- Filtered Task Management ---
    public class TaskDataTableWrapper {
        @AuraEnabled public List<Intern_Task__c> tasks;
        @AuraEnabled public Integer totalRecords;
    }

    @AuraEnabled(cacheable=true)
    public static TaskDataTableWrapper getFilteredTasks(String internName, String taskName, Date dueDate, String status, Integer pageSize, Integer pageNumber, String token) {
        Admin_User__c admin = getAuthenticatedAdmin(token);
        Integer offset = (pageNumber - 1) * pageSize;
        
        String query = 'SELECT Id, Name, Intern__r.Name, Status__c, Due_Date__c, Priority__c, Description__c FROM Intern_Task__c WHERE ';
        String countQuery = 'SELECT count() FROM Intern_Task__c WHERE ';
        
        List<String> filters = new List<String>();
        
        // Role cleanup
        if (admin.Role__c != 'Super Admin') {
            filters.add('Intern__r.Team_Lead__c = \'' + admin.Id + '\'');
        }

        if (String.isNotBlank(internName)) {
            filters.add('Intern__r.Name LIKE \'%' + String.escapeSingleQuotes(internName) + '%\'');
        }
        if (String.isNotBlank(taskName)) {
            filters.add('Name LIKE \'%' + String.escapeSingleQuotes(taskName) + '%\'');
        }
        if (dueDate != null) {
            DateTime dt = DateTime.newInstance(dueDate.year(), dueDate.month(), dueDate.day());
           filters.add('Due_Date__c = ' + dt.format('yyyy-MM-dd'));
        }
        if (String.isNotBlank(status) && status != 'All') {
            filters.add('Status__c = \'' + String.escapeSingleQuotes(status) + '\'');
        }

        if (filters.isEmpty()) {
            query += 'Id != null'; // Fallback
            countQuery += 'Id != null';
        } else {
            query += String.join(filters, ' AND ');
            countQuery += String.join(filters, ' AND ');
        }

        query += ' ORDER BY Due_Date__c ASC LIMIT :pageSize OFFSET :offset';

        TaskDataTableWrapper wrapper = new TaskDataTableWrapper();
        wrapper.totalRecords = Database.countQuery(countQuery);
        wrapper.tasks = Database.query(query);
        
        return wrapper;
    }

    @AuraEnabled(cacheable=true)
    public static Map<String, Integer> getTaskStats(String token) {
        Admin_User__c admin = getAuthenticatedAdmin(token);
        Map<String, Integer> stats = new Map<String, Integer>();
        
        List<AggregateResult> ar = [SELECT Status__c, count(Id) cnt FROM Intern_Task__c GROUP BY Status__c];
        for (AggregateResult r : ar) {
            stats.put((String)r.get('Status__c'), (Integer)r.get('cnt'));
        }
        return stats;
    }
    public class InternPerformanceWrapper {
        @AuraEnabled public String id;
        @AuraEnabled public String name;
        @AuraEnabled public Integer completedTasks;
    }

    @AuraEnabled(cacheable=true)
    public static List<InternPerformanceWrapper> getTopInterns(String token) {
        Admin_User__c admin = getAuthenticatedAdmin(token);
        List<InternPerformanceWrapper> result = new List<InternPerformanceWrapper>();
        
        List<AggregateResult> groupedResults;
        // Relaxed criteria: Count all tasks (Completed + In Progress) to show activity
        if (admin.Role__c == 'Super Admin') {
            groupedResults = [SELECT Intern__c, Intern__r.Name Name, COUNT(Id) taskCount 
                              FROM Intern_Task__c 
                              WHERE Status__c != 'Assigned' 
                              GROUP BY Intern__c, Intern__r.Name 
                              ORDER BY COUNT(Id) DESC 
                              LIMIT 5];
        } else {
             groupedResults = [SELECT Intern__c, Intern__r.Name Name, COUNT(Id) taskCount 
                              FROM Intern_Task__c 
                              WHERE Status__c != 'Assigned' AND Intern__r.Team_Lead__c = :admin.Id
                              GROUP BY Intern__c, Intern__r.Name 
                              ORDER BY COUNT(Id) DESC 
                              LIMIT 5];
        }

        for (AggregateResult ar : groupedResults) {
            InternPerformanceWrapper w = new InternPerformanceWrapper();
            w.id = (String)ar.get('Intern__c');
            w.name = (String)ar.get('Name');
            w.completedTasks = (Integer)ar.get('taskCount');
            result.add(w);
        }
        return result;
    }

    @AuraEnabled(cacheable=true)
    public static List<Intern_Task__c> getUpcomingDeadlines(String token) {
        Admin_User__c admin = getAuthenticatedAdmin(token);
        Date today = Date.today();
        Date futureScope = today.addDays(30);
        
        // Include Overdue tasks! (Removed Due_Date__c >= :today)
        // Show ALL upcoming deadlines regardless of date or team lead (per user request for visibility)
        if (admin.Role__c == 'Super Admin') {
            return [SELECT Id, Name, Intern__r.Name, Due_Date__c, Priority__c 
                    FROM Intern_Task__c 
                    WHERE Status__c != 'Completed'
                    ORDER BY Due_Date__c ASC 
                    LIMIT 50];
        } else {
             return [SELECT Id, Name, Intern__r.Name, Due_Date__c, Priority__c 
                    FROM Intern_Task__c 
                    WHERE Status__c != 'Completed'
                    // Relaxed Team Lead Filter to match getTaskStats behavior
                    // AND Intern__c IN (SELECT Id FROM Intern__c WHERE Team_Lead__c = :admin.Id)
                    ORDER BY Due_Date__c ASC 
                    LIMIT 50];
        }
    }

    @AuraEnabled(cacheable=true)
    public static Map<String, Integer> getLeaveStats(String token) {
        Admin_User__c admin = getAuthenticatedAdmin(token);
        Map<String, Integer> stats = new Map<String, Integer>();
        String query = 'SELECT Status__c, count(Id) cnt FROM Leave_Request__c ';
        
        if (admin.Role__c != 'Super Admin') {
            query += 'WHERE Intern__r.Team_Lead__c = \'' + admin.Id + '\' ';
        }
        query += 'GROUP BY Status__c';

        List<AggregateResult> ar = Database.query(query);
        for (AggregateResult r : ar) {
            stats.put((String)r.get('Status__c'), (Integer)r.get('cnt'));
        }
        return stats;
    }

    @AuraEnabled(cacheable=true)
    public static Map<String, Integer> getTaskPriorityStats(String token) {
        Admin_User__c admin = getAuthenticatedAdmin(token);
        Map<String, Integer> stats = new Map<String, Integer>();
        // Fetch Priority Stats for Chart
        String query = 'SELECT Priority__c, count(Id) cnt FROM Intern_Task__c ';
        
        if (admin.Role__c != 'Super Admin') {
            // Relaxed filter to show global stats if needed, or strictly own team.
            // Matching getTaskStats behavior which shows ALL.
            // query += 'WHERE Intern__r.Team_Lead__c = \'' + admin.Id + '\' ';
        }
        query += 'GROUP BY Priority__c';

        List<AggregateResult> ar = Database.query(query);
        for (AggregateResult r : ar) {
            stats.put((String)r.get('Priority__c'), (Integer)r.get('cnt'));
        }
        return stats;
    }

    // --- Course Syllabus Management ---
    @AuraEnabled(cacheable=true)
    public static List<Course_Syllabus__c> getAllSyllabus() {
        return [SELECT Id, Course_Name__c, Module_Name__c 
                FROM Course_Syllabus__c 
                ORDER BY Course_Name__c, Module_Name__c];
    }

    @AuraEnabled
    public static void saveSyllabus(Course_Syllabus__c syllabus) {
        try { 
            // Handle required Topic_Name__c constraint if field exists
            // We set a default value to satisfy database requirements even though the field is hidden in UI
            syllabus.Topic_Name__c = 'General'; 
            upsert syllabus; 
        } catch (Exception e) { throw new AuraHandledException(e.getMessage()); }
    }

    @AuraEnabled
    public static void deleteSyllabus(Id syllabusId) {
        try { delete [SELECT Id FROM Course_Syllabus__c WHERE Id = :syllabusId]; } catch (Exception e) { throw new AuraHandledException(e.getMessage()); }
    }

    // --- Class Session Links Management ---
    @AuraEnabled(cacheable=true)
    public static List<Class_Session_Links__c> getAllSessionLinks() {
        return [SELECT Id, Name, Agenda__c, Date__c, Session_Start__c,
                       Session_End__c, Session_URL__c, Speaker__c,
                       CreatedDate, LastModifiedDate
                FROM Class_Session_Links__c
                ORDER BY Date__c DESC, Session_Start__c ASC];
    }

    @AuraEnabled
    public static void saveSessionLink(Class_Session_Links__c sessionLink) {
        try {
            upsert sessionLink;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled
    public static void deleteSessionLink(Id sessionLinkId) {
        try {
            delete [SELECT Id FROM Class_Session_Links__c WHERE Id = :sessionLinkId];
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
}
