public without sharing class AdminController {
    
    // --- Helper for Token Validation ---
    private static Map<String, Object> getAuthenticatedAdmin(String token) {
        if (String.isBlank(token)) throw new AuraHandledException('Session Expired. Please login again.');
        if (String.isBlank(token)) throw new AuraHandledException('Session Expired. Please login again.');
        List<List<Object>> rows = GoogleSheetsService.getSheetData('Admins', true);
        for (Integer i = 1; i < rows.size(); i++) {
            List<Object> row = rows[i];
            if (row.size() > 5 && (String) row[5] == token) {
                Map<String, Object> admin = new Map<String, Object>();
                admin.put('Id', row[0]);
                admin.put('Role__c', row.size()>4 ? row[4] : 'Team Lead');
                return admin;
            }
        }
        throw new AuraHandledException('Invalid Session');
    }
    
    private static Date parseDate(Object val) {
        if (val == null || String.isBlank(String.valueOf(val))) return null;
        try { return Date.valueOf((String)val); } catch(Exception e) { return null; }
    }
    
    private static DateTime parseDateTime(Object val) {
        if (val == null || String.isBlank(String.valueOf(val))) return null;
        try { return DateTime.valueOf((String)val); } catch(Exception e) { return null; }
    }
    
    private static String generateUUID() {
        Blob b = Crypto.generateAesKey(128);
        String h = EncodingUtil.convertToHex(b);
        return h.substring(0,8)+'-'+h.substring(8,12)+'-'+h.substring(12,16)+'-'+h.substring(16,20)+'-'+h.substring(20);
    }
    
    // --- INTERNS ---
    @AuraEnabled(cacheable=true)
    public static List<Map<String, Object>> getAllInterns(String token) {
        Map<String, Object> admin = getAuthenticatedAdmin(token);
        String adminId = (String) admin.get('Id');
        String role = (String) admin.get('Role__c');
        List<Map<String, Object>> interns = new List<Map<String, Object>>();
        List<List<Object>> rows = GoogleSheetsService.getSheetData('Interns', true);
        for (Integer i = 1; i < rows.size(); i++) {
             List<Object> r = rows[i];
             String tlId = r.size()>12 ? (String)r[12] : '';
             if (role == 'Super Admin' || tlId == adminId) {
                 Map<String, Object> m = new Map<String, Object>();
                 m.put('Id', r[0]);
                 m.put('Name', r[1]);
                 m.put('Email__c', r[2]);
                 m.put('Phone__c', r[3]);
                 m.put('College_Name__c', r.size()>5?r[5]:'');
                 m.put('Roll_Number__c', r.size()>6?r[6]:'');
                 m.put('Address__c', r.size()>7?r[7]:'');
                 m.put('Start_Date__c', parseDate(r.size()>10?r[10]:null));
                 m.put('End_Date__c', parseDate(r.size()>11?r[11]:null));
                 interns.add(m);
             }
        }
        return interns;
    }
    
    @AuraEnabled
    public static void saveIntern(Map<String, Object> intern) {
         try {
             String id = (String) intern.get('Id');
             List<List<Object>> rows = GoogleSheetsService.getSheetData('Interns');
             for (Integer i = 1; i < rows.size(); i++) {
                 if ((String) rows[i][0] == id) {
                     List<Object> newRow = rows[i].clone();
                     if (intern.containsKey('Start_Date__c')) newRow[10] = String.valueOf(intern.get('Start_Date__c'));
                     if (intern.containsKey('End_Date__c')) newRow[11] = String.valueOf(intern.get('End_Date__c'));
                     if (intern.containsKey('Team_Lead__c')) {
                         while (newRow.size() <= 12) newRow.add('');
                         newRow[12] = intern.get('Team_Lead__c');
                     }
                     GoogleSheetsService.updateRow('Interns', i + 1, newRow);
                     return;
                 }
             }
         } catch(Exception e) { throw new AuraHandledException(e.getMessage()); }
    }
    
    @AuraEnabled
    public static void deleteIntern(String internId) {
        try { deleteRowById('Interns', internId); } catch(Exception e) { throw new AuraHandledException(e.getMessage()); }
    }

    // --- LEAVES ---
    @AuraEnabled(cacheable=true)
    public static List<Map<String, Object>> getAllLeaveRequests(String token) {
        Map<String, Object> admin = getAuthenticatedAdmin(token);
        String adminId = (String) admin.get('Id');
        String role = (String) admin.get('Role__c');
        Map<String, String> internNames = getInternNameMap();
        List<Map<String, Object>> leaves = new List<Map<String, Object>>();
        List<List<Object>> rows = GoogleSheetsService.getSheetData('Leaves', true);
        List<List<Object>> internRows = GoogleSheetsService.getSheetData('Interns', true);
        for (Integer i = rows.size() - 1; i >= 1; i--) {
             String iId = (String) rows[i][1];
             if (hasAccess(role, adminId, iId, internRows)) {
                 Map<String, Object> r = new Map<String, Object>();
                 r.put('Id', rows[i][0]);
                 Map<String, Object> internRel = new Map<String, Object>();
                 internRel.put('Name', internNames.get(iId));
                 r.put('Intern__r', internRel);
                 r.put('Start_Date__c', parseDate(rows[i][2]));
                 r.put('End_Date__c', parseDate(rows[i][3]));
                 r.put('Reason__c', rows[i][4]);
                 r.put('Status__c', rows[i][5]);
                 leaves.add(r);
             }
        }
        return leaves;
    }
    
    @AuraEnabled
    public static void updateLeaveStatus(String leaveId, String status) {
        try {
            List<List<Object>> rows = GoogleSheetsService.getSheetData('Leaves');
            for (Integer i = 1; i < rows.size(); i++) {
                if ((String) rows[i][0] == leaveId) {
                    List<Object> newRow = rows[i].clone();
                    newRow[5] = status;
                    GoogleSheetsService.updateRow('Leaves', i+1, newRow);
                    return;
                }
            }
        } catch(Exception e) { throw new AuraHandledException(e.getMessage()); }
    }

    // --- MENTORSHIP ---
    @AuraEnabled(cacheable=true)
    public static List<Map<String, Object>> getAllMentorshipRequests(String token) {
         Map<String, Object> admin = getAuthenticatedAdmin(token);
         Map<String, String> names = getInternNameMap();
         List<Map<String, Object>> res = new List<Map<String, Object>>();
         List<List<Object>> rows = GoogleSheetsService.getSheetData('Mentorships');
         for (Integer i = rows.size()-1; i>=1; i--) {
             String iId = (String) rows[i][1];
             Map<String, Object> r = new Map<String, Object>();
             r.put('Id', rows[i][0]);
             Map<String, Object> ir = new Map<String, Object>();
             ir.put('Name', names.get(iId));
             r.put('Intern__r', ir);
             r.put('Request_Type__c', rows[i][2]);
             r.put('Description__c', rows[i][3]);
             r.put('Status__c', rows[i][4]);
             r.put('Mentor_Response__c', rows[i].size()>5?rows[i][5]:'');
             r.put('CreatedDate', parseDateTime(rows[i].size()>6?rows[i][6]:null));
             res.add(r);
         }
         return res;
    }
    
    @AuraEnabled
    public static void replyToMentorship(String requestId, String response, String status) {
         try {
            List<List<Object>> rows = GoogleSheetsService.getSheetData('Mentorships', true);
            for (Integer i = 1; i < rows.size(); i++) {
                if ((String) rows[i][0] == requestId) {
                    List<Object> newRow = rows[i].clone();
                    while (newRow.size() <= 5) newRow.add('');
                    newRow[4] = status;
                    newRow[5] = response;
                    GoogleSheetsService.updateRow('Mentorships', i+1, newRow);
                    return;
                }
            }
         } catch(Exception e) { throw new AuraHandledException(e.getMessage()); }
    }

    // --- DAILY LOGS ---
    @AuraEnabled(cacheable=true)
    public static List<Map<String, Object>> getAllDailyLogs(String token) {
        Map<String, String> names = getInternNameMap();
        List<Map<String, Object>> res = new List<Map<String, Object>>();
        List<List<Object>> rows = GoogleSheetsService.getSheetData('DailyLogs', true);
        for (Integer i = rows.size()-1; i>=1; i--) {
             String iId = (String) rows[i][1];
             Map<String, Object> r = new Map<String, Object>();
             r.put('Id', rows[i][0]);
             Map<String, Object> ir = new Map<String, Object>();
             ir.put('Name', names.get(iId));
             r.put('Intern__r', ir);
             r.put('Log_Date__c', parseDate(rows[i][2]));
             r.put('Work_Description__c', rows[i].size()>3?rows[i][3]:'');
             r.put('Hours_Spent__c', rows[i].size()>4?rows[i][4]:0);
             r.put('Course__c', rows[i].size()>5?rows[i][5]:'');
             r.put('Module__c', rows[i].size()>6?rows[i][6]:'');
             r.put('Topic__c', rows[i].size()>7?rows[i][7]:'');
             res.add(r);
             if (res.size() >= 500) break;
        }
        return res;
    }

    // --- ANNOUNCEMENTS ---
    @AuraEnabled(cacheable=true)
    public static List<Map<String, Object>> getAllAnnouncements() {
        return InternWorkController.getAnnouncements(null); 
    }
    
    @AuraEnabled
    public static void saveAnnouncement(Map<String, Object> announcement) {
         try {
             String msg = (String) announcement.get('Message__c');
             String type = (String) announcement.get('Type__c');
             String id = (String) announcement.get('Id');
             if (String.isBlank(id)) {
                 List<Object> newRow = new List<Object>{ generateUUID(), msg, type, String.valueOf(System.today()), '', 'TRUE' };
                 GoogleSheetsService.appendRow('Announcements', newRow);
             }
         } catch(Exception e) { throw new AuraHandledException(e.getMessage()); }
    }
    
    @AuraEnabled
    public static void deleteAnnouncement(String announcementId) { deleteRowById('Announcements', announcementId); }
    
    @AuraEnabled
    public static void deleteResource(String resourceId) { deleteRowById('Resources', resourceId); }
    
    @AuraEnabled(cacheable=true)
    public static List<Map<String, Object>> getAllResources(String token) {
        return InternWorkController.getResources(token); 
    }
    
    @AuraEnabled
    public static void saveResource(Map<String, Object> resource) {
         try {
             String t = (String) resource.get('Title__c');
             String l = (String) resource.get('Link__c');
             String type = (String) resource.get('Type__c');
             String d = (String) resource.get('Description__c');
             List<Object> newRow = new List<Object>{ generateUUID(), t, d, l, type, String.valueOf(System.now()) };
             GoogleSheetsService.appendRow('Resources', newRow);
         } catch(Exception e) {}
    }

    // --- TASKS ---
    @AuraEnabled
    public static List<Map<String, Object>> getAllTasks(String token) {
         Map<String, String> names = getInternNameMap();
         List<Map<String, Object>> res = new List<Map<String, Object>>();
         List<List<Object>> rows = GoogleSheetsService.getSheetData('Tasks');
         for (Integer i = 1; i < rows.size(); i++) {
             List<Object> row = rows[i];
             String iId = row.size() > 1 ? (String) row[1] : '';
             Map<String, Object> r = new Map<String, Object>();
             r.put('Id', row.size() > 0 ? row[0] : '');
             r.put('Name', row.size() > 2 ? row[2] : '');
             Map<String, Object> ir = new Map<String, Object>();
             ir.put('Name', names.get(iId));
             r.put('Intern__r', ir);
             r.put('Status__c', row.size() > 4 ? row[4] : '');
             r.put('Due_Date__c', parseDate(row.size() > 5 ? row[5] : null));
             r.put('Priority__c', row.size() > 8 ? row[8] : '');
             r.put('Description__c', row.size() > 3 ? row[3] : '');
             if(row.size() > 10) r.put('CreatedDate', parseDateTime(row[10]));
             res.add(r);
         }
         return res;
    }
    
    @AuraEnabled
    public static void saveTask(Map<String, Object> task) {
         try {
             String id = (String) task.get('Id');
             String name = (String) task.get('Name');
             String descriptionStr = (String) task.get('Description__c');
             String pri = (String) task.get('Priority__c');
             Date due = parseDate(task.get('Due_Date__c'));
             String internId = (String) task.get('Intern__c');
             String status = (String) task.get('Status__c');
             
             if (String.isNotBlank(id)) {
                 List<List<Object>> rows = GoogleSheetsService.getSheetData('Tasks', true);
                 for (Integer i = 1; i < rows.size(); i++) {
                     if (rows[i].size() > 0 && (String) rows[i][0] == id) {
                         List<Object> row = rows[i].clone();
                         while(row.size() <= 8) row.add('');
                         row[2] = name;
                         row[3] = descriptionStr;
                         if (status != null) row[4] = status;
                         row[5] = String.valueOf(due);
                         row[8] = pri;
                         if (internId != null) row[1] = internId;
                         
                         GoogleSheetsService.updateRow('Tasks', i + 1, row);
                         return;
                     }
                 }
             } else {
                 // Fallback if ID is passing but not found, or used incorrectly as create.
             }
         } catch(Exception e) { throw new AuraHandledException(e.getMessage()); }
    }
    
    @AuraEnabled
    public static void deleteTask(String taskId) { deleteRowById('Tasks', taskId); }

    @AuraEnabled
    public static void assignTaskToInterns(Map<String, Object> taskTemplate, List<String> targetInternIds, Boolean assignToAll, String token) {
         try {
             List<List<Object>> interns = GoogleSheetsService.getSheetData('Interns', true);
             for (Integer i = 1; i < interns.size(); i++) {
                 if (interns[i].size() > 0) {
                     String iId = (String) interns[i][0];
                     Boolean match = assignToAll;
                     if (!match && targetInternIds != null) match = targetInternIds.contains(iId);
                     
                     if (match) {
                         String name = (String) taskTemplate.get('Name');
                         String descriptionStr = (String) taskTemplate.get('Description__c');
                         String pri = (String) taskTemplate.get('Priority__c');
                         Date due = parseDate(taskTemplate.get('Due_Date__c'));
                         List<Object> newRow = new List<Object>{ generateUUID(), iId, name, descriptionStr, 'Assigned', String.valueOf(due), '', '', pri, '', String.valueOf(System.now()) };
                         GoogleSheetsService.appendRow('Tasks', newRow);
                     }
                 }
             }
         } catch(Exception e) { throw new AuraHandledException(e.getMessage()); }
    }

    // --- HELPERS ---
    private static Map<String, String> getInternNameMap() {
        Map<String, String> m = new Map<String, String>();
        List<List<Object>> rows = GoogleSheetsService.getSheetData('Interns', true);
        for (Integer i = 1; i < rows.size(); i++) {
            if (rows[i].size() > 1) m.put((String)rows[i][0], (String)rows[i][1]);
        }
        return m;
    }
    
    private static Boolean hasAccess(String role, String adminId, String internId, List<List<Object>> internRows) {
        if (role == 'Super Admin') return true;
        for (Integer i = 1; i < internRows.size(); i++) {
            if ((String) internRows[i][0] == internId) {
                if (internRows[i].size() > 12 && (String) internRows[i][12] == adminId) return true;
            }
        }
        return false;
    }

    private static void deleteRowById(String sheetName, String id) {
        List<List<Object>> rows = GoogleSheetsService.getSheetData(sheetName, true);
        for (Integer i = 1; i < rows.size(); i++) {
            if ((String) rows[i][0] == id) {
                GoogleSheetsService.deleteRow(sheetName, i + 1);
                return;
            }
        }
    }
    
    public class ActivityWrapper {
        @AuraEnabled public String id;
        @AuraEnabled public String type;
        @AuraEnabled public String message;
        @AuraEnabled public Datetime activityDate;
    }
    
    @AuraEnabled(cacheable=true)
    public static List<ActivityWrapper> getRecentActivities(String token) {
        return new List<ActivityWrapper>();
    }
    
    @AuraEnabled
    public static Map<String, Object> getFilteredTasks(String internName, String taskName, Date dueDate, String status, Integer pageSize, Integer pageNumber, String token) {
        List<Map<String, Object>> allTasks = getAllTasks(token);
        List<Map<String, Object>> filtered = new List<Map<String, Object>>();
        
        String iName = (internName == null) ? '' : internName.toLowerCase();
        String tName = (taskName == null) ? '' : taskName.toLowerCase();
        
        for (Map<String, Object> t : allTasks) {
            Boolean match = true;
            
            // Filter by Intern Name
            if (String.isNotBlank(iName)) {
                Map<String, Object> intern = (Map<String, Object>) t.get('Intern__r');
                String name = (intern != null && intern.containsKey('Name')) ? (String) intern.get('Name') : '';
                if (name == null || !name.toLowerCase().contains(iName)) match = false;
            }
            
            // Filter by Task Name
            if (match && String.isNotBlank(tName)) {
                String name = (String) t.get('Name');
                if (name == null || !name.toLowerCase().contains(tName)) match = false;
            }
            
            // Filter by Due Date
            if (match && dueDate != null) {
                Date d = (Date) t.get('Due_Date__c');
                if (d == null || d != dueDate) match = false;
            }
            
            // Filter by Status
            if (match && String.isNotBlank(status) && status != 'All') {
                String s = (String) t.get('Status__c');
                if (s == null || s != status) match = false;
            }
            
            if (match) filtered.add(t);
        }
        
        // Sorting (Optional, by Date DESC)
        // ...
        
        // Pagination
        Integer total = filtered.size();
        Integer startIdx = (pageNumber - 1) * pageSize;
        Integer endIdx = Math.min(startIdx + pageSize, total);
        
        List<Map<String, Object>> paged = new List<Map<String, Object>>();
        if (startIdx < total) {
            for (Integer i = startIdx; i < endIdx; i++) {
                paged.add(filtered[i]);
            }
        }
        
        Map<String, Object> result = new Map<String, Object>();
        result.put('tasks', paged);
        result.put('totalRecords', total);
        return result;
    }
    
    @AuraEnabled
    public static Map<String, Integer> getTaskStats(String token) {
        Map<String, Integer> stats = new Map<String, Integer>{'Assigned' => 0, 'In Progress' => 0, 'Completed' => 0};
        List<Map<String, Object>> tasks = getAllTasks(token);
        for(Map<String, Object> t : tasks) {
            String s = (String) t.get('Status__c');
            if(String.isNotBlank(s)) {
                if(!stats.containsKey(s)) stats.put(s, 0);
                stats.put(s, stats.get(s) + 1);
            }
        }
        return stats;
    }
    
    @AuraEnabled
    public static List<Map<String, Object>> getTopInterns(String token) {
        List<Map<String, Object>> tasks = getAllTasks(token);
        Map<String, Integer> finishCounts = new Map<String, Integer>();
        Map<String, String> internNames = getInternNameMap(); // Helper
        
        for(Map<String, Object> t : tasks) {
            if((String)t.get('Status__c') == 'Completed') {
                Map<String, Object> intern = (Map<String, Object>) t.get('Intern__r');
                String iName = (String) intern.get('Name'); // Logic in getAllTasks puts Name here but getting ID to map back might be safer? 
                // getAllTasks puts: r.put('Intern__r', {Name: ...});
                // We don't have the Intern ID directly on the task row in the Map returned by getAllTasks? 
                // distinct getAllTasks implementation:
                // r.put('Intern__r', ir); -> ir has Name.
                // But we used existing getInternNameMap() inside getAllTasks.
                // Let's assume Unique Name for now or better, check raw rows?
                // Actually getAllTasks reads 'iId' from row[1]. 
                // But getAllTasks output doesn't expose ID directly? 
                // Wait, examining getAllTasks: 
                // r.put('Intern__r', ir); 
                // We should expose InternId in getAllTasks or fetch raw here.
                // Let's fetch raw tasks to get InternId.
            }
        }
        
        // Re-approach: Count raw from sheet to use IDs
        List<List<Object>> rows = GoogleSheetsService.getSheetData('Tasks', true);
        for(Integer i=1; i<rows.size(); i++) {
            if(rows[i].size() > 4 && (String)rows[i][4] == 'Completed') {
                String iId = (String)rows[i][1];
                if(!finishCounts.containsKey(iId)) finishCounts.put(iId, 0);
                finishCounts.put(iId, finishCounts.get(iId) + 1);
            }
        }
        
        List<Map<String, Object>> result = new List<Map<String, Object>>();
        for(String iId : finishCounts.keySet()) {
            result.add(new Map<String, Object>{
                'Id' => iId,
                'Name' => internNames.containsKey(iId) ? internNames.get(iId) : 'Unknown',
                'completedTasks' => finishCounts.get(iId)
            });
        }
        
        // Simple Bubble Sort DESC
        for(Integer i=0; i<result.size(); i++) {
            for(Integer j=1; j<result.size()-i; j++) {
                Integer c1 = (Integer) result[j-1].get('completedTasks');
                Integer c2 = (Integer) result[j].get('completedTasks');
                if(c1 < c2) {
                    Map<String, Object> temp = result[j-1];
                    result[j-1] = result[j];
                    result[j] = temp;
                }
            }
        }
        
        // Top 5
        List<Map<String, Object>> top = new List<Map<String, Object>>();
        for(Integer k=0; k<Math.min(5, result.size()); k++) top.add(result[k]);
        return top;
    }
    
    @AuraEnabled
    public static List<Map<String, Object>> getUpcomingDeadlines(String token) {
        List<Map<String, Object>> tasks = getAllTasks(token);
        List<Map<String, Object>> pending = new List<Map<String, Object>>();
        for(Map<String, Object> t : tasks) {
            if((String)t.get('Status__c') != 'Completed' && t.get('Due_Date__c') != null) {
                pending.add(t);
            }
        }
        
        // Sort by Date ASC
        for(Integer i=0; i<pending.size(); i++) {
            for(Integer j=1; j<pending.size()-i; j++) {
                Date d1 = (Date) pending[j-1].get('Due_Date__c');
                Date d2 = (Date) pending[j].get('Due_Date__c');
                if(d1 > d2) {
                    Map<String, Object> temp = pending[j-1];
                    pending[j-1] = pending[j];
                    pending[j] = temp;
                }
            }
        }
        
        return pending;
    }
    
    @AuraEnabled
    public static Map<String, Integer> getLeaveStats(String token) {
        Map<String, Integer> stats = new Map<String, Integer>{'Approved'=>0, 'Pending'=>0, 'Rejected'=>0};
        List<Map<String, Object>> leaves = getAllLeaveRequests(token);
        for(Map<String, Object> l : leaves) {
            String s = (String) l.get('Status__c');
            if(String.isNotBlank(s)) {
                if(!stats.containsKey(s)) stats.put(s, 0);
                stats.put(s, stats.get(s) + 1);
            }
        }
        return stats;
    }
    
    @AuraEnabled
    public static Map<String, Integer> getTaskPriorityStats(String token) {
        Map<String, Integer> stats = new Map<String, Integer>{'High'=>0, 'Medium'=>0, 'Low'=>0};
        List<Map<String, Object>> tasks = getAllTasks(token);
        for(Map<String, Object> t : tasks) {
            String p = (String) t.get('Priority__c');
            if(String.isNotBlank(p)) {
                if(!stats.containsKey(p)) stats.put(p, 0);
                stats.put(p, stats.get(p) + 1);
            }
        }
        return stats;
    }

    @AuraEnabled(cacheable=true)
    public static List<Map<String, Object>> getAllSyllabus() { return InternWorkController.getSyllabus(); }
    
    @AuraEnabled
    public static void saveSyllabus(Map<String, Object> syllabus) {
         try {
             String cProps = (String) syllabus.get('Course_Name__c');
             String mProps = (String) syllabus.get('Module_Name__c');
             String tProps = (String) syllabus.get('Topic_Name__c');
             
             List<Object> newRow = new List<Object>{ generateUUID(), cProps, mProps, tProps == null ? '' : tProps };
             GoogleSheetsService.appendRow('Syllabus', newRow);
         } catch(Exception e) { throw new AuraHandledException(e.getMessage()); }
    }
    
    @AuraEnabled
    public static void deleteSyllabus(String syllabusId) { deleteRowById('Syllabus', syllabusId); }
    
    @AuraEnabled(cacheable=true)
    public static List<Map<String, Object>> getAllSessionLinks() { return InternWorkController.getClassSessionLinks(); }
    
    @AuraEnabled
    public static void saveSessionLink(Map<String, Object> sessionLink) {
         try {
             String id = (String) sessionLink.get('Id');
             String agenda = (String) sessionLink.get('Agenda__c');
             String dateStr = String.valueOf(sessionLink.get('Date__c'));
             String startT = (String) sessionLink.get('Session_Start__c');
             String endT = (String) sessionLink.get('Session_End__c');
             String url = (String) sessionLink.get('Session_URL__c');
             String speaker = (String) sessionLink.get('Speaker__c');
             
             if (String.isNotBlank(id)) {
                 List<List<Object>> rows = GoogleSheetsService.getSheetData('ClassSessionLinks', true);
                 for (Integer i = 1; i < rows.size(); i++) {
                     if ((String)rows[i][0] == id) {
                         List<Object> row = new List<Object>{ id, agenda, agenda, dateStr, startT, endT, url, speaker };
                         GoogleSheetsService.updateRow('ClassSessionLinks', i + 1, row);
                         return;
                     }
                 }
             } else {
                 List<Object> newRow = new List<Object>{ generateUUID(), agenda, agenda, dateStr, startT, endT, url, speaker };
                 GoogleSheetsService.appendRow('ClassSessionLinks', newRow);
             }
         } catch(Exception e) { throw new AuraHandledException(e.getMessage()); }
    }
    
    @AuraEnabled
    public static void deleteSessionLink(String linkId) { deleteRowById('ClassSessionLinks', linkId); }
    
     public class AdminMetrics {
        @AuraEnabled public Integer totalInterns;
        @AuraEnabled public Integer pendingLeaves;
        @AuraEnabled public Integer totalTasks;
    }
    
    @AuraEnabled(cacheable=true)
    public static AdminMetrics getAdminMetrics(String token) {
         AdminMetrics m = new AdminMetrics();
         m.totalInterns = GoogleSheetsService.getSheetData('Interns', true).size() - 1;
         m.pendingLeaves = 0;
         m.totalTasks = GoogleSheetsService.getSheetData('Tasks', true).size() - 1;
         return m;
    }
}
