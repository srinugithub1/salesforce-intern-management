public without sharing class InternWorkController {
    
    // --- Helper for Intern Lookup ---
    private static Map<String, Object> getInternByToken(String token) {
        if (String.isBlank(token)) throw new AuraHandledException('Invalid Session');
        List<List<Object>> rows = GoogleSheetsService.getSheetData('Interns', true);
        for (Integer i = 1; i < rows.size(); i++) {
            List<Object> row = rows[i];
            // Intern Schema: 0:Id, ... 8:Token
            if (row.size() > 8 && (String) row[8] == token) {
                return rowToInternMap(row);
            }
        }
        throw new AuraHandledException('Session Expired');
    }

    private static Map<String, Object> rowToInternMap(List<Object> row) {
        Map<String, Object> intern = new Map<String, Object>();
        if (row.size() > 0) intern.put('Id', row[0]); // UUID
        if (row.size() > 1) intern.put('Name', row[1]);
        if (row.size() > 2) intern.put('Email__c', row[2]);
        if (row.size() > 3) intern.put('Phone__c', row[3]);
        if (row.size() > 5) intern.put('College_Name__c', row[5]);
        if (row.size() > 6) intern.put('Roll_Number__c', row[6]);
        if (row.size() > 7) intern.put('Address__c', row[7]);
        if (row.size() > 10) intern.put('Start_Date__c', parseDate(row[10]));
        if (row.size() > 11) intern.put('End_Date__c', parseDate(row[11]));
        return intern;
    }
    
    private static Date parseDate(Object val) {
        if (val == null || String.isBlank(String.valueOf(val))) return null;
        try { return Date.valueOf((String)val); } catch(Exception e) { return null; }
    }
    
    private static DateTime parseDateTime(Object val) {
        if (val == null || String.isBlank(String.valueOf(val))) return null;
        try { return DateTime.valueOf((String)val); } catch(Exception e) { return null; }
    }
    
    // --- CACHE WARMER (Fix for 429 Errors) ---
    @AuraEnabled
    public static void refreshSystemCache() {
        try {
            // Probabilistic Throttling: Only 10% of requests trigger a refresh if cache is expired.
            // This prevents "Thundering Herd" where 2000 users all hit the API simultaneously on cache expiry.
            Double chance = Math.random(); 
            Boolean shouldRefresh = (chance < 0.10); 

            // Interns
            if (!GoogleSheetsService.isCacheValid('Interns') && shouldRefresh) {
                 GoogleSheetsService.getSheetData('Interns', false);
            }

            // Attendance
            if (!GoogleSheetsService.isCacheValid('Attendance') && shouldRefresh) {
                 GoogleSheetsService.getSheetData('Attendance', false);
            }

            // Tasks
            if (!GoogleSheetsService.isCacheValid('Tasks') && shouldRefresh) {
                 GoogleSheetsService.getSheetData('Tasks', false);
            }

            // Announcements
            if (!GoogleSheetsService.isCacheValid('Announcements') && shouldRefresh) {
                 GoogleSheetsService.getSheetData('Announcements', false);
            }

            // Leaves
            if (!GoogleSheetsService.isCacheValid('Leaves') && shouldRefresh) {
                 GoogleSheetsService.getSheetData('Leaves', false);
            }
            
            // Resources & Syllabus (Long TTL, less critical)
            if (!GoogleSheetsService.isCacheValid('Resources') && shouldRefresh) {
                 GoogleSheetsService.getSheetData('Resources', false);
            }
             if (!GoogleSheetsService.isCacheValid('Syllabus') && shouldRefresh) {
                 GoogleSheetsService.getSheetData('Syllabus', false);
            }

        } catch(Exception e) {
            System.debug('Cache Refresh Failed: ' + e.getMessage());
            // Do not throw to UI, as this is a background optimization
        }
    }

    // --- ATTENDANCE ---
    
    @AuraEnabled
    public static Map<String, Object> clockIn(String token, String todayStr) {
        try {
            Map<String, Object> intern = getInternByToken(token);
            String internId = (String) intern.get('Id');
            
            List<List<Object>> rows = GoogleSheetsService.getSheetData('Attendance', true);
            Date today = parseDate(todayStr);
            if (today == null) today = System.today(); // Fallback
            
            for (Integer i = 1; i < rows.size(); i++) {
                List<Object> row = rows[i];
                if (row.size() > 1 && (String) row[1] == internId) {
                    if (row.size() > 5) {
                        Date rowDate = parseDate(row[5]);
                        if (rowDate != null && rowDate.isSameDay(today)) {
                            AuraHandledException e = new AuraHandledException('ALREADY_LOGGED_TODAY');
                            e.setMessage('ALREADY_LOGGED_TODAY');
                            throw e;
                        }
                    }
                }
            }

            String newId = generateUUID();
            DateTime now = System.now();
            List<Object> newRow = new List<Object>{
                newId, internId, String.valueOf(now), '', 'Present', String.valueOf(today), '', String.valueOf(now)
            };
            GoogleSheetsService.appendRow('Attendance', newRow);
            
            Map<String, Object> att = new Map<String, Object>();
            att.put('Id', newId);
            return att;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled
    public static void clockOut(String token, String checkoutReason) {
        try {
            Map<String, Object> intern = getInternByToken(token);
            String internId = (String) intern.get('Id');
            
            List<List<Object>> rows = GoogleSheetsService.getSheetData('Attendance', true);
            for (Integer i = 1; i < rows.size(); i++) {
                List<Object> row = rows[i];
                if (row.size() > 1 && (String) row[1] == internId) {
                    if (row.size() > 3 && String.isBlank((String) row[3])) {
                        DateTime now = System.now();
                        List<Object> newRow = row.clone();
                        while (newRow.size() <= 4) newRow.add('');
                        
                        newRow[3] = String.valueOf(now);
                        if (String.isNotBlank(checkoutReason)) {
                            newRow[4] = checkoutReason;
                        }
                        
                        GoogleSheetsService.updateRow('Attendance', i + 1, newRow);
                        return;
                    }
                }
            }
            throw new AuraHandledException('No active session found to clock out.');
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled
    public static Map<String, Object> getCurrentStatus(String token, String todayStr) {
        Map<String, Object> intern = getInternByToken(token);
        String internId = (String) intern.get('Id');
        
        Map<String, Object> result = new Map<String, Object>();
        result.put('isClockedIn', false);
        
        List<List<Object>> rows = GoogleSheetsService.getSheetData('Attendance', true);
        Date today = parseDate(todayStr);
        if (today == null) today = System.today(); // Fallback

        for (Integer i = rows.size() - 1; i >= 1; i--) {
             List<Object> row = rows[i];
             if (row.size() > 1 && (String) row[1] == internId) {
                 if (row.size() > 5) {
                     Date rowDate = parseDate(row[5]);
                     if (rowDate != null && rowDate.isSameDay(today)) {
                         result.put('isClockedIn', String.isBlank((String)row[3]));
                         if (row.size() > 7 && String.isNotBlank((String)row[7])) {
                             DateTime createdDate = parseDateTime(row[7]);
                             result.put('loginTime', createdDate.getTime());
                         }
                         break;
                     }
                 }
             }
        }
        return result;
    }

    @AuraEnabled
    public static List<Map<String, Object>> getAttendanceHistory(String token) {
        Map<String, Object> intern = getInternByToken(token);
        String internId = (String) intern.get('Id');
        
        List<Map<String, Object>> history = new List<Map<String, Object>>();
        List<List<Object>> rows = GoogleSheetsService.getSheetData('Attendance');
        
        for (Integer i = rows.size() - 1; i >= 1; i--) {
            List<Object> row = rows[i];
            if (row.size() > 1 && (String) row[1] == internId) {
                Map<String, Object> record = new Map<String, Object>();
                record.put('Id', row[0]);
                record.put('Login_Time__c', parseDateTime(row[2]));
                record.put('Logout_Time__c', parseDateTime(row[3]));
                
                // Calculate Working Hours
                DateTime loginTime = parseDateTime(row[2]);
                DateTime logoutTime = parseDateTime(row[3]);
                if (loginTime != null && logoutTime != null) {
                    Long diff = logoutTime.getTime() - loginTime.getTime();
                    Decimal hours = Decimal.valueOf(diff) / 3600000;
                    record.put('Working_Hours__c', hours.setScale(1) + ' hrs');
                } else {
                    record.put('Working_Hours__c', '-');
                }

                record.put('Status__c', row.size() > 4 ? row[4] : '');
                record.put('Date__c', parseDate(row[5]));
                history.add(record);
                if (history.size() >= 20) break;
            }
        }
        return history;
    }

    @AuraEnabled
    public static Map<String, Object> getAttendanceMetrics(String token) {
        Map<String, Object> intern = getInternByToken(token);
        String internId = (String) intern.get('Id');
        
        Map<String, Object> metrics = new Map<String, Object>();
        metrics.put('weeklyGoal', 40);
        
        List<List<Object>> rows = GoogleSheetsService.getSheetData('Attendance');
        
        Long totalMillis = 0;
        Set<Date> presentDates = new Set<Date>();
        Date startOfWeek = System.today().toStartOfWeek();
        
        for (Integer i = 1; i < rows.size(); i++) {
            List<Object> row = rows[i];
            if (row.size() > 1 && (String) row[1] == internId) {
                DateTime login = parseDateTime(row[2]);
                DateTime logout = parseDateTime(row[3]);
                Date attDate = parseDate(row[5]);
                
                if (attDate != null) presentDates.add(attDate);
                
                if (login != null && login.date() >= startOfWeek) {
                     DateTime endTime = (logout != null) ? logout : System.now(); // Fixed variable name
                     totalMillis += (endTime.getTime() - login.getTime());
                }
            }
        }
        
        metrics.put('weeklyHours', (Decimal.valueOf(totalMillis) / 3600000).setScale(1));
        metrics.put('streak', calculateStreak(presentDates));
        
        // Simplified progress
        metrics.put('daysCompleted', 0);
        metrics.put('totalDays', 60);
        metrics.put('progressPercent', 0);
        metrics.put('totalPresent', presentDates.size());
        metrics.put('totalLeave', 0); 
        metrics.put('totalElapsed', 0);
        
        return metrics;
    }
    
    private static Integer calculateStreak(Set<Date> dates) {
        Integer streak = 0;
        Date d = System.today();
        if (!dates.contains(d)) d = d.addDays(-1);
        
        while (dates.contains(d)) {
            streak++;
            d = d.addDays(-1);
        }
        return streak;
    }

    // --- LOGS ---
    @AuraEnabled
    public static void submitDailyLog(String token, Date logDate, String description, Decimal hours, String course, String module, String topic, String submissionLink, String learnings, String blockers) {
        try {
            Map<String, Object> intern = getInternByToken(token);
            String internId = (String) intern.get('Id');
            
            String newId = generateUUID();
            List<Object> newRow = new List<Object>{
                newId, internId, String.valueOf(logDate), description, hours, course, module, topic, submissionLink, learnings, blockers
            };
            GoogleSheetsService.appendRow('DailyLogs', newRow);
        } catch (Exception e) { throw new AuraHandledException(e.getMessage()); }
    }

    @AuraEnabled
    public static List<Map<String, Object>> getDailyLogs(String token) {
        Map<String, Object> intern = getInternByToken(token);
        String internId = (String) intern.get('Id');
        List<Map<String, Object>> logs = new List<Map<String, Object>>();
        List<List<Object>> rows = GoogleSheetsService.getSheetData('DailyLogs');
        for (Integer i = rows.size() - 1; i >= 1; i--) {
            List<Object> row = rows[i];
            if (row.size() > 1 && (String) row[1] == internId) {
                Map<String, Object> r = new Map<String, Object>();
                r.put('Id', row[0]);
                r.put('Log_Date__c', parseDate(row[2]));
                r.put('Work_Description__c', row.size()>3?row[3]:'');
                r.put('Hours_Spent__c', row.size()>4?row[4]:0);
                r.put('Course__c', row.size()>5?row[5]:'');
                r.put('Module__c', row.size()>6?row[6]:'');
                r.put('Topic__c', row.size()>7?row[7]:'');
                r.put('Submission_Link__c', row.size()>8?row[8]:'');
                r.put('Learnings__c', row.size()>9?row[9]:'');
                r.put('Blockers__c', row.size()>10?row[10]:'');
                logs.add(r);
                if (logs.size() >= 20) break;
            }
        }
        return logs;
    }

    // --- TASKS ---
    @AuraEnabled(cacheable=true)
    public static List<Map<String, Object>> getTasks(String token) {
        Map<String, Object> intern = getInternByToken(token);
        String internId = (String) intern.get('Id');
        List<Map<String, Object>> tasks = new List<Map<String, Object>>();
        List<List<Object>> rows = GoogleSheetsService.getSheetData('Tasks', true);
        for (Integer i = 1; i < rows.size(); i++) {
             List<Object> row = rows[i];
             if (row.size() > 1 && (String) row[1] == internId) {
                 Map<String, Object> t = new Map<String, Object>();
                 t.put('Id', row[0]);
                 t.put('Name', row[2]);
                 t.put('Description__c', row[3]);
                 t.put('Status__c', row[4]);
                 t.put('Due_Date__c', parseDate(row[5]));
                 t.put('Remarks__c', row.size()>6?row[6]:'');
                 t.put('Today_Work_Progress__c', row.size()>7?row[7]:'');
                 t.put('Priority__c', row.size()>8?row[8]:'');
                 t.put('Submission_Link__c', row.size()>9?row[9]:'');
                 tasks.add(t);
             }
        }
        return tasks;
    }

    @AuraEnabled
    public static void updateTaskStatus(String taskId, String status, String remarks, String progress, String submissionLink) {
         try {
             List<List<Object>> rows = GoogleSheetsService.getSheetData('Tasks');
             for (Integer i = 1; i < rows.size(); i++) {
                 if ((String) rows[i][0] == taskId) {
                     List<Object> newRow = rows[i].clone();
                     while (newRow.size() <= 9) newRow.add('');
                     newRow[4] = status;
                     if (remarks != null) newRow[6] = remarks;
                     if (progress != null) newRow[7] = progress;
                     if (submissionLink != null) newRow[9] = submissionLink;
                     GoogleSheetsService.updateRow('Tasks', i + 1, newRow);
                     return;
                 }
             }
         } catch (Exception e) { throw new AuraHandledException(e.getMessage()); }
    }

    // --- MENTORSHIP ---
    @AuraEnabled
    public static void submitMentorshipRequest(String token, String type, String description) {
         try {
             Map<String, Object> intern = getInternByToken(token);
             String newId = generateUUID();
             List<Object> newRow = new List<Object>{ newId, intern.get('Id'), type, description, 'Open', '', String.valueOf(System.now()) };
             GoogleSheetsService.appendRow('Mentorships', newRow);
         } catch(Exception e) { throw new AuraHandledException(e.getMessage()); }
    }
    
    @AuraEnabled(cacheable=true)
    public static List<Map<String, Object>> getMentorshipRequests(String token) {
        Map<String, Object> intern = getInternByToken(token);
        String internId = (String) intern.get('Id');
        List<Map<String, Object>> reqs = new List<Map<String, Object>>();
        List<List<Object>> rows = GoogleSheetsService.getSheetData('Mentorships', true);
        for (Integer i = rows.size() - 1; i >= 1; i--) {
            if (rows[i].size() > 1 && (String) rows[i][1] == internId) {
                Map<String, Object> r = new Map<String, Object>();
                r.put('Id', rows[i][0]);
                r.put('Request_Type__c', rows[i][2]);
                r.put('Description__c', rows[i][3]);
                r.put('Status__c', rows[i][4]);
                r.put('Mentor_Response__c', rows[i].size()>5?rows[i][5]:'');
                r.put('CreatedDate', parseDateTime(rows[i].size()>6?rows[i][6]:null));
                reqs.add(r);
            }
        }
        return reqs;
    }
    
    // --- OTHERS ---
    @AuraEnabled(cacheable=true)
    public static List<Map<String, Object>> getSyllabus() {
        List<List<Object>> rows = GoogleSheetsService.getSheetData('Syllabus', true);
        List<Map<String, Object>> listData = new List<Map<String, Object>>();
        for (Integer i = 1; i < rows.size(); i++) {
             // 0:Id, 1:Course, 2:Module
             Map<String, Object> r = new Map<String, Object>();
             r.put('Id', rows[i][0]);
             r.put('Course_Name__c', rows[i][1]);
             r.put('Module_Name__c', rows[i][2]);
             listData.add(r);
        }
        return listData;
    }
    
    @AuraEnabled(cacheable=true)
    public static List<Map<String, Object>> getResources(String token) {
         List<List<Object>> rows = GoogleSheetsService.getSheetData('Resources', true);
         List<Map<String, Object>> listData = new List<Map<String, Object>>();
         for (Integer i = 1; i < rows.size(); i++) {
             List<Object> row = rows[i];
             Map<String, Object> r = new Map<String, Object>();
             r.put('Id', row.size()>0 ? row[0] : '');
             r.put('Title__c', row.size()>1 ? row[1] : '');
             r.put('Description__c', row.size()>2 ? row[2] : '');
             r.put('Link__c', row.size()>3 ? row[3] : '');
             r.put('Type__c', row.size()>4 ? row[4] : '');
             listData.add(r);
         }
         return listData;
    }
    
    @AuraEnabled(cacheable=true)
    public static List<Map<String, Object>> getAnnouncements(String token) {
         List<List<Object>> rows = GoogleSheetsService.getSheetData('Announcements', true);
         // 0:Id, 1:Msg, 2:Type, 3:Date, 4:Link, 5:Active
         List<Map<String, Object>> listData = new List<Map<String, Object>>();
         for (Integer i = 1; i < rows.size(); i++) {
             if (rows[i].size() > 5 && (String)rows[i][5] == 'TRUE') {
                 Map<String, Object> r = new Map<String, Object>();
                 r.put('Id', rows[i][0]);
                 r.put('Message__c', rows[i][1]);
                 r.put('Type__c', rows[i][2]);
                 listData.add(r);
             }
         }
         return listData;
    }
    
    @AuraEnabled(cacheable=true)
    public static List<Map<String, Object>> getClassSessionLinks() {
         List<List<Object>> rows = GoogleSheetsService.getSheetData('ClassSessionLinks', true);
         List<Map<String, Object>> listData = new List<Map<String, Object>>();
         for (Integer i = 1; i < rows.size(); i++) {
              List<Object> row = rows[i];
              Map<String, Object> r = new Map<String, Object>();
              r.put('Id', row.size()>0 ? row[0] : '');
              r.put('Name', row.size()>1 ? row[1] : '');
              r.put('Agenda__c', row.size()>2 ? row[2] : '');
              r.put('Date__c', parseDate(row.size()>3 ? row[3] : null));
              r.put('Session_Start__c', row.size()>4 ? row[4] : ''); 
              r.put('Session_End__c', row.size()>5 ? row[5] : '');
              r.put('Session_URL__c', row.size()>6 ? row[6] : '');
              r.put('Speaker__c', row.size()>7 ? row[7] : '');
              listData.add(r);
         }
         return listData;
    }

    // --- LEAVES ---
    @AuraEnabled
    public static void submitLeaveRequest(String token, Date startDate, Date endDate, String reason) {
         try {
             Map<String, Object> intern = getInternByToken(token);
             String newId = generateUUID();
             List<Object> newRow = new List<Object>{ newId, intern.get('Id'), String.valueOf(startDate), String.valueOf(endDate), reason, 'Pending', String.valueOf(System.now()) };
             GoogleSheetsService.appendRow('Leaves', newRow);
         } catch(Exception e) { throw new AuraHandledException(e.getMessage()); }
    }
    
    @AuraEnabled(cacheable=true)
    public static List<Map<String, Object>> getLeaveRequests(String token) {
         Map<String, Object> intern = getInternByToken(token);
         String internId = (String) intern.get('Id');
         List<Map<String, Object>> listData = new List<Map<String, Object>>();
         List<List<Object>> rows = GoogleSheetsService.getSheetData('Leaves', true);
         for (Integer i = rows.size() - 1; i >= 1; i--) {
             if (rows[i].size() > 1 && (String)rows[i][1] == internId) {
                 Map<String, Object> r = new Map<String, Object>();
                 r.put('Id', rows[i][0]);
                 r.put('Start_Date__c', parseDate(rows[i][2]));
                 r.put('End_Date__c', parseDate(rows[i][3]));
                 r.put('Reason__c', rows[i][4]);
                 r.put('Status__c', rows[i][5]);
                 listData.add(r);
             }
         }
         return listData;
    }
    
    @AuraEnabled
    public static Map<String, Object> getInternProfile(String token) {
         Map<String, Object> intern = getInternByToken(token);
         return new Map<String, Object>{ 'intern' => intern, 'profilePicData' => null };
    }
    
    @AuraEnabled
    public static void updateProfile(String token, String email, String phone, String bio) {
         try {
             if (String.isBlank(token)) return;
             List<List<Object>> rows = GoogleSheetsService.getSheetData('Interns');
             for (Integer i = 1; i < rows.size(); i++) {
                List<Object> row = rows[i];
                if (row.size() > 8 && (String) row[8] == token) {
                    List<Object> newRow = row.clone();
                    newRow[2] = email;
                    newRow[3] = (phone.startsWith('\'') ? phone : '\'' + phone);
                    GoogleSheetsService.updateRow('Interns', i+1, newRow);
                    return;
                }
             }
         } catch(Exception e) {}
    }

    @AuraEnabled
    public static String uploadProfileImage(String token, String base64Data, String filename, String contentType) {
        return 'Image upload not supported in Sheets mode';
    }
    
    // Leaderboard
    public class LeaderboardEntry implements Comparable {
        @AuraEnabled public String internId;
        @AuraEnabled public String name;
        @AuraEnabled public Decimal weeklyHours;
        @AuraEnabled public Integer completedTasks;
        @AuraEnabled public Decimal score;
        @AuraEnabled public Integer rank;

        public Integer compareTo(Object compareTo) {
            LeaderboardEntry other = (LeaderboardEntry)compareTo;
            if (score == other.score) return 0;
            return (score > other.score) ? -1 : 1;
        }
    }
    
    @AuraEnabled(cacheable=true)
    public static List<LeaderboardEntry> getLeaderboardData() {
        // Fetch All Interns
        Map<String, LeaderboardEntry> stats = new Map<String, LeaderboardEntry>();
        List<List<Object>> internRows = GoogleSheetsService.getSheetData('Interns', true);
        for (Integer i = 1; i < internRows.size(); i++) {
             String iId = (String) internRows[i][0];
             LeaderboardEntry e = new LeaderboardEntry();
             e.internId = iId;
             e.name = (String) internRows[i][1];
             e.weeklyHours = 0;
             e.completedTasks = 0;
             e.score = 0;
             stats.put(iId, e);
        }
        
        // Fetch Attendance for Weekly Hours
        Date startOfWeek = System.today().toStartOfWeek();
        List<List<Object>> attRows = GoogleSheetsService.getSheetData('Attendance', true);
        for (Integer i = 1; i < attRows.size(); i++) {
            String iId = (String) attRows[i][1]; // InternId
            if (stats.containsKey(iId)) {
                DateTime login = parseDateTime(attRows[i][2]);
                DateTime logout = parseDateTime(attRows[i][3]);
                 if (login != null && login.date() >= startOfWeek) {
                     DateTime endTime = (logout != null) ? logout : System.now();
                     Long millis = endTime.getTime() - login.getTime();
                     Decimal hours = Decimal.valueOf(millis) / (1000 * 60 * 60);
                     stats.get(iId).weeklyHours += hours;
                }
            }
        }
        
        // Fetch Tasks for Completed Count
        List<List<Object>> taskRows = GoogleSheetsService.getSheetData('Tasks', true);
        for (Integer i = 1; i < taskRows.size(); i++) {
            String iId = (String) taskRows[i][1];
            String status = (String) taskRows[i][4];
            if (stats.containsKey(iId) && status == 'Completed') {
                stats.get(iId).completedTasks++;
            }
        }
        
        List<LeaderboardEntry> leaderboard = stats.values();
        for(LeaderboardEntry e : leaderboard) {
             e.weeklyHours = e.weeklyHours.setScale(1);
             e.score = (e.weeklyHours * 10) + (e.completedTasks * 50);
        }
        leaderboard.sort();
        for (Integer i = 0; i < leaderboard.size(); i++) {
            leaderboard[i].rank = i + 1;
        }
        return leaderboard;
    }

    private static String generateUUID() {
        Blob b = Crypto.generateAesKey(128);
        String h = EncodingUtil.convertToHex(b);
        return h.substring(0,8)+'-'+h.substring(8,12)+'-'+h.substring(12,16)+'-'+h.substring(16,20)+'-'+h.substring(20);
    }
}
