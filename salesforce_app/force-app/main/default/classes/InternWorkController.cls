public without sharing class InternWorkController {
    // Test Comment for Deployment Check
    
    private static Intern__c getInternByToken(String token) {
         if (String.isBlank(token)) throw new AuraHandledException('Invalid Session');
         List<Intern__c> interns = [SELECT Id, Start_Date__c, End_Date__c FROM Intern__c WHERE Session_Token__c = :token LIMIT 1];
         if (interns.isEmpty()) {
             throw new AuraHandledException('Session Expired');
         }
         return interns[0];
    }

    @AuraEnabled
    public static Attendance__c clockIn(String token) {
        try {
            Intern__c intern = getInternByToken(token);
            
            // 1. Check for ANY sessions created TODAY (Closed or Open)
            List<Attendance__c> todaySessions = [SELECT Id FROM Attendance__c 
                                                 WHERE Intern__c = :intern.Id 
                                                 AND CreatedDate = TODAY 
                                                 LIMIT 1];

            if (!todaySessions.isEmpty()) {
                AuraHandledException e = new AuraHandledException('ALREADY_LOGGED_TODAY');
                e.setMessage('ALREADY_LOGGED_TODAY');
                throw e;
            }

            // 2. Create New Session
            Attendance__c att = new Attendance__c();
            att.Intern__c = intern.Id;
            att.Login_Time__c = System.now();
            insert att;
            return att;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled
    public static void clockOut(String token, String checkoutReason) {
        try {
            Intern__c intern = getInternByToken(token);
            
            // Find ALL open attendance records to clean up any "ghosts"
            List<Attendance__c> openAtts = [SELECT Id, Login_Time__c FROM Attendance__c 
                                            WHERE Intern__c = :intern.Id 
                                            AND Logout_Time__c = NULL];
                                            
            if (!openAtts.isEmpty()) {
                for(Attendance__c att : openAtts) {
                    att.Logout_Time__c = System.now();
                    // Log Reason if provided (Early Checkout) directly to Status field
                    if (String.isNotBlank(checkoutReason)) {
                        att.Status__c = checkoutReason;
                    } else {
                        att.Status__c = 'Present'; // Default status if normal checkout
                    }
                }
                update openAtts;

            } else {
                 throw new AuraHandledException('No active session found to clock out.');
            }
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled
    public static Map<String, Object> getCurrentStatus(String token) {
        Intern__c intern = getInternByToken(token);
        Map<String, Object> result = new Map<String, Object>();
        result.put('isClockedIn', false);
        result.put('loginTime', null);

        // Only consider it "Clocked In" if there is an open session created TODAY
        List<Attendance__c> openAtts = [SELECT CreatedDate, Login_Time__c FROM Attendance__c 
                                        WHERE Intern__c = :intern.Id 
                                        AND Logout_Time__c = NULL 
                                        ORDER BY CreatedDate DESC LIMIT 1];
        
        if (!openAtts.isEmpty()) {
             // If the open session is from today, return true details.
             if (openAtts[0].CreatedDate.date() == System.today()) {
                 result.put('isClockedIn', true);
                 result.put('loginTime', openAtts[0].CreatedDate.getTime());
             }
        }
        return result;
    }

    @AuraEnabled
    public static List<Attendance__c> getAttendanceHistory(String token) {
        Intern__c intern = getInternByToken(token);
        return [SELECT Id, Login_Time__c, Logout_Time__c, Date__c, Working_Hours__c, Status__c 
                FROM Attendance__c 
                WHERE Intern__c = :intern.Id 
                ORDER BY CreatedDate DESC LIMIT 20];
    }

    @AuraEnabled(cacheable=true)
    public static List<Intern_Task__c> getTasks(String token) {
        Intern__c intern = getInternByToken(token);
        return [SELECT Id, Name, Description__c, Status__c, Due_Date__c, Remarks__c, Today_Work_Progress__c, Priority__c, Submission_Link__c 
                FROM Intern_Task__c 
                WHERE Intern__c = :intern.Id 
                ORDER BY Due_Date__c ASC];
    }

    @AuraEnabled
    public static void updateTaskStatus(String taskId, String status, String remarks, String progress, String submissionLink) {
        try {
            Intern_Task__c task = [SELECT Id FROM Intern_Task__c WHERE Id = :taskId LIMIT 1];
            task.Status__c = status;
            if (remarks != null) task.Remarks__c = remarks;
            if (progress != null) task.Today_Work_Progress__c = progress;
            if (submissionLink != null) task.Submission_Link__c = submissionLink;
            update task;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled
    public static Map<String, Object> getAttendanceMetrics(String token) {
        Intern__c intern = getInternByToken(token);
        Map<String, Object> metrics = new Map<String, Object>();
        
        // 1. Calculate Weekly Hours (Mon-Sun)
        Date today = System.today();
        Date startOfWeek = today.toStartOfWeek(); // Usually Sunday in US locale, check locale or assume and adjust
        // Adjust for Monday start if needed: Salesforce toStartOfWeek() depends on locale. 
        // Let's perform a safer Query: CreatedDate >= LAST_N_DAYS:7 AND ... 
        // Actually, let's just get records from the last 7 days for simplicity of "Weekly" or explicit logic:
        
        List<Attendance__c> weekAtts = [SELECT Login_Time__c, Logout_Time__c 
                                        FROM Attendance__c 
                                        WHERE Intern__c = :intern.Id 
                                        AND CreatedDate >= :startOfWeek];
        
        Long totalMillis = 0;
        for(Attendance__c a : weekAtts) {
            DateTime logout = a.Logout_Time__c != null ? a.Logout_Time__c : System.now();
            totalMillis += (logout.getTime() - a.Login_Time__c.getTime());
        }
        
        Decimal totalHours = Decimal.valueOf(totalMillis) / (1000 * 60 * 60);
        metrics.put('weeklyHours', totalHours.setScale(1));
        metrics.put('weeklyGoal', 40); // Hardcoded 40h goal
        
        // 2. Calculate Streak
        // Query recent unique dates
        List<AggregateResult> pastDays = [SELECT DAY_ONLY(CreatedDate) dayVal
                                          FROM Attendance__c 
                                          WHERE Intern__c = :intern.Id 
                                          AND CreatedDate >= LAST_N_DAYS:30
                                          GROUP BY DAY_ONLY(CreatedDate)
                                          ORDER BY DAY_ONLY(CreatedDate) DESC];
        
        Integer streak = 0;
        Date checkDate = today;
        
        // If logged in today, start check from today. If not, start from yesterday.
        // The list is DESC, so first item is specific date.
        
        if (pastDays.isEmpty()) {
            streak = 0;
        } else {
            // Convert Aggregate results to simple list of Dates
            List<Date> presentDates = new List<Date>();
            for(AggregateResult ar : pastDays) {
                presentDates.add((Date)ar.get('dayVal'));
            }
            
            // Allow streak to continue if today is not done yet
            // If most recent is today, count it. If most recent is yesterday, count it.
            // If most recent is day-before-yesterday, streak broken.
            
            for(Date d : presentDates) {
                if (d == checkDate) {
                    streak++;
                    checkDate = checkDate.addDays(-1);
                } else if (d == checkDate.addDays(-1)) { // Gap? actually logic above handles this naturally
                    // wait, if checkDate is Today, and d is Yesterday, it means we missed Today?
                    // Streak logic: 
                    // Case A: Today Present (streak 1), Yesterday Present (streak 2)...
                    // Case B: Today Absent, Yesterday Present (streak 1)...
                    
                     // Let's refine:
                     // If the first date is NOT Today, and NOT Yesterday, streak is 0.
                }
            }
             // Simple re-loop for strict consecutive check
             streak = 0;
             checkDate = today;
             
             // Check if today is present
             Boolean todayPresent = false;
             if(presentDates.contains(today)) {
                 streak++;
                 checkDate = today.addDays(-1);
                 todayPresent = true;
             } else {
                 // Check if yesterday is present
                 checkDate = today.addDays(-1);
             }
             
             while(presentDates.contains(checkDate)) {
                 streak++;
                 checkDate = checkDate.addDays(-1);
             }
        }
        
        
        metrics.put('streak', streak);

        // 3. Internship Progress (Gamification)
        if (intern.Start_Date__c != null && intern.End_Date__c != null) {
            Integer totalDays = intern.Start_Date__c.daysBetween(intern.End_Date__c);
            Integer daysCompleted = intern.Start_Date__c.daysBetween(today);
            
            if (daysCompleted < 0) daysCompleted = 0;
            if (daysCompleted > totalDays) daysCompleted = totalDays;
            
            Double progressPct = 0;
            if (totalDays > 0) {
                 progressPct = (Double)daysCompleted / totalDays * 100;
            }
            
            metrics.put('daysCompleted', daysCompleted);
            metrics.put('totalDays', totalDays);
            metrics.put('progressPercent', progressPct.intValue());
        } else {
            metrics.put('daysCompleted', 0);
            metrics.put('totalDays', 60); // Default Goal
            metrics.put('progressPercent', 0);
        }

        // 4. Detailed Attendance Stats (Since Start Date)
        if (intern.Start_Date__c != null) {
            // Unique Present Days
            List<AggregateResult> presentRes = [SELECT DAY_ONLY(CreatedDate)
                                               FROM Attendance__c 
                                               WHERE Intern__c = :intern.Id 
                                               AND CreatedDate >= :intern.Start_Date__c
                                               GROUP BY DAY_ONLY(CreatedDate)];
            metrics.put('totalPresent', presentRes.size());

            // Approved Leave Days (Sum of duration)
            // Note: Duration = End_Date__c - Start_Date__c + 1
            List<Leave_Request__c> leaves = [SELECT Start_Date__c, End_Date__c 
                                            FROM Leave_Request__c 
                                            WHERE Intern__c = :intern.Id 
                                            AND Status__c = 'Approved'
                                            AND Start_Date__c >= :intern.Start_Date__c];
            Integer leaveDays = 0;
            for(Leave_Request__c lr : leaves) {
                if(lr.Start_Date__c != null && lr.End_Date__c != null) {
                    leaveDays += lr.Start_Date__c.daysBetween(lr.End_Date__c) + 1;
                }
            }
            metrics.put('totalLeave', leaveDays);
            
            // Days in Internship so far (Total Potential Days)
            Date checkUntil = System.today() < intern.End_Date__c ? System.today() : intern.End_Date__c;
            Integer totalElapsed = intern.Start_Date__c.daysBetween(checkUntil) + 1;
            if (totalElapsed < 0) totalElapsed = 0;
            metrics.put('totalElapsed', totalElapsed);
        } else {
            metrics.put('totalPresent', 0);
            metrics.put('totalLeave', 0);
            metrics.put('totalElapsed', 0);
        }
        
        return metrics;
    }
    @AuraEnabled
    public static void submitLeaveRequest(String token, Date startDate, Date endDate, String reason) {
        try {
            Intern__c intern = getInternByToken(token);
            Leave_Request__c lr = new Leave_Request__c();
            lr.Intern__c = intern.Id;
            lr.Start_Date__c = startDate;
            lr.End_Date__c = endDate;
            lr.Reason__c = reason;
            lr.Status__c = 'Pending';
            insert lr;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled(cacheable=true)
    public static List<Leave_Request__c> getLeaveRequests(String token) {
        Intern__c intern = getInternByToken(token);
        return [SELECT Id, Start_Date__c, End_Date__c, Reason__c, Status__c, Name 
                FROM Leave_Request__c 
                WHERE Intern__c = :intern.Id 
                ORDER BY CreatedDate DESC];
    }

    @AuraEnabled(cacheable=true)
    public static List<LeaderboardEntry> getLeaderboardData() {
        // 1. Get All Interns
        Map<Id, Intern__c> internMap = new Map<Id, Intern__c>([SELECT Id, Name FROM Intern__c]);
        Map<Id, LeaderboardEntry> stats = new Map<Id, LeaderboardEntry>();

        for (Id iId : internMap.keySet()) {
            LeaderboardEntry entry = new LeaderboardEntry();
            entry.internId = iId;
            entry.name = internMap.get(iId).Name;
            entry.weeklyHours = 0;
            entry.completedTasks = 0;
            entry.score = 0;
            stats.put(iId, entry);
        }

        // 2. Aggregate Weekly Hours
        // Using Apex processing to handle Duration calculation dynamically
        Date weekStart = System.today().toStartOfWeek();
        List<Attendance__c> atts = [SELECT Intern__c, Login_Time__c, Logout_Time__c 
                                    FROM Attendance__c 
                                    WHERE CreatedDate >= :weekStart 
                                    AND Intern__c IN :stats.keySet()];
        
        for (Attendance__c a : atts) {
            if (stats.containsKey(a.Intern__c)) {
                DateTime logout = a.Logout_Time__c != null ? a.Logout_Time__c : System.now();
                Long millis = logout.getTime() - a.Login_Time__c.getTime();
                Decimal hours = Decimal.valueOf(millis) / (1000 * 60 * 60);
                stats.get(a.Intern__c).weeklyHours += hours;
            }
        }

        // 3. Aggregate Completed Tasks (This Week)
        // Note: Using CreatedDate or CompletedDate? Assuming LastModified for completion time approx or CreatedDate for simplicity.
        // Ideally should check a Completed_Date__c but for MVP using LastModifiedDate if Status is Completed.
        List<AggregateResult> taskRes = [SELECT Intern__c, COUNT(Id) cnt 
                                         FROM Intern_Task__c 
                                         WHERE Status__c = 'Completed' 
                                         AND LastModifiedDate >= :weekStart
                                         GROUP BY Intern__c];
        
        for (AggregateResult ar : taskRes) {
            Id iId = (Id)ar.get('Intern__c');
            if (stats.containsKey(iId)) {
                stats.get(iId).completedTasks = (Integer)ar.get('cnt');
            }
        }

        // 4. Calculate Score & Sort
        List<LeaderboardEntry> leaderboard = stats.values();
        for (LeaderboardEntry e : leaderboard) {
            e.weeklyHours = e.weeklyHours.setScale(1);
            // Score Formula: (Hours * 10) + (Tasks * 50)
            e.score = (e.weeklyHours * 10) + (e.completedTasks * 50);
        }

        leaderboard.sort();

        // Assign Rank
        for (Integer i = 0; i < leaderboard.size(); i++) {
            leaderboard[i].rank = i + 1;
        }

        return leaderboard;
    }

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
    public static List<Resource__c> getResources(String token) {
        // Just validate token, we don't need intern ID for public resources, 
        // but it ensures only logged-in users see them.
        getInternByToken(token);
        
        return [SELECT Id, Title__c, Description__c, Link__c, Type__c, CreatedDate
                FROM Resource__c 
                ORDER BY CreatedDate DESC];
    }

    @AuraEnabled(cacheable=true)
    public static List<Announcement__c> getAnnouncements(String token) {
        getInternByToken(token);
        return [SELECT Id, Message__c, Type__c, Post_Date__c, Link__c 
                FROM Announcement__c 
                WHERE Active__c = TRUE 
                ORDER BY Post_Date__c DESC, CreatedDate DESC 
                LIMIT 10];
    }

    @AuraEnabled
    public static void submitDailyLog(String token, Date logDate, String description, Decimal hours, String course, String module, String topic, String submissionLink, String learnings, String blockers) {
        try {
            Intern__c intern = getInternByToken(token);
            Daily_Log__c log = new Daily_Log__c();
            log.Intern__c = intern.Id;
            log.Log_Date__c = logDate;
            log.Work_Description__c = description;
            log.Hours_Spent__c = hours;
            
            // New Fields
            log.Course__c = course;
            log.Module__c = module;
            log.Topic__c = topic;
            log.Submission_Link__c = submissionLink;
            log.Learnings__c = learnings;
            log.Blockers__c = blockers;

            insert log;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled
    public static List<Daily_Log__c> getDailyLogs(String token) {
        Intern__c intern = getInternByToken(token);
        return [SELECT Id, Log_Date__c, Work_Description__c, Hours_Spent__c, 
                       Course__c, Module__c, Topic__c, Submission_Link__c, Learnings__c, Blockers__c
                FROM Daily_Log__c 
                WHERE Intern__c = :intern.Id 
                ORDER BY Log_Date__c DESC 
                LIMIT 20];
    }

    @AuraEnabled(cacheable=true)
    public static List<Course_Syllabus__c> getSyllabus() {
        return [SELECT Id, Course_Name__c, Module_Name__c 
                FROM Course_Syllabus__c 
                ORDER BY Course_Name__c, Module_Name__c];
    }


    @AuraEnabled
    public static Map<String, Object> getInternProfile(String token) {
        Intern__c internRecord = getInternByToken(token);
        Intern__c intern = [SELECT Id, Name, Email__c, Phone__c, Bio__c, College_Name__c, Roll_Number__c 
                            FROM Intern__c 
                            WHERE Id = :internRecord.Id];
        
        String profilePicData = null;
        DateTime latestDate = null;

        // 1. Try fetching latest ContentVersion (File) - e.g. uploaded by Admin
        Set<Id> docIds = new Set<Id>();
        for (ContentDocumentLink cdl : [SELECT ContentDocumentId FROM ContentDocumentLink WHERE LinkedEntityId = :intern.Id]) {
            docIds.add(cdl.ContentDocumentId);
        }

        List<ContentVersion> cvs = new List<ContentVersion>();
        if (!docIds.isEmpty()) {
            cvs = [SELECT Id, VersionData, FileExtension, Title, CreatedDate 
                   FROM ContentVersion 
                   WHERE ContentDocumentId IN :docIds 
                   AND IsLatest = true 
                   ORDER BY CreatedDate DESC 
                   LIMIT 1];
        }
        
        if (!cvs.isEmpty()) {
            ContentVersion cv = cvs[0];
            if (cv.VersionData != null) {
                latestDate = cv.CreatedDate;
                String ext = (cv.FileExtension != null) ? cv.FileExtension.toLowerCase() : 'jpg';
                String mimeType = 'image/jpeg';
                if (ext == 'png') mimeType = 'image/png';
                else if (ext == 'gif') mimeType = 'image/gif';
                profilePicData = 'data:' + mimeType + ';base64,' + EncodingUtil.base64Encode(cv.VersionData);
            }
        }

        // 2. Try fetching latest Attachment - e.g. uploaded by Guest User
        List<Attachment> attachments = [SELECT Id, Body, ContentType, CreatedDate FROM Attachment WHERE ParentId = :intern.Id ORDER BY CreatedDate DESC LIMIT 1];
        if (!attachments.isEmpty()) {
            // Use Attachment if it's newer than the File, or if no File exists
            if (latestDate == null || attachments[0].CreatedDate > latestDate) {
                profilePicData = 'data:' + attachments[0].ContentType + ';base64,' + EncodingUtil.base64Encode(attachments[0].Body);
            }
        }
        
        return new Map<String, Object>{
            'intern' => intern,
            'profilePicData' => profilePicData
        };
    }

    @AuraEnabled
    public static String uploadProfileImage(String token, String base64Data, String filename, String contentType) {
        try {
            Intern__c intern = getInternByToken(token);
            
            if (String.isBlank(base64Data)) {
                 throw new AuraHandledException('File data is empty');
            }

            // GUEST USER FIX: Use Attachment instead of ContentVersion
            // Guest Users often have issues creating ContentVersion (Files) but can create Attachments.
            Attachment att = new Attachment();
            att.ParentId = intern.Id;
            att.Body = EncodingUtil.base64Decode(base64Data);
            att.Name = filename;
            att.ContentType = contentType;
            insert att;

            return att.Id;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled
    public static void updateProfile(String token, String email, String phone, String bio) {
        try {
            Intern__c intern = getInternByToken(token);
            Intern__c toUpdate = new Intern__c(Id = intern.Id);
            toUpdate.Email__c = email;
            toUpdate.Phone__c = phone;
            toUpdate.Bio__c = bio;
            update toUpdate;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled
    public static void submitMentorshipRequest(String token, String type, String description) {
        try {
            Intern__c intern = getInternByToken(token);
            Mentorship_Request__c req = new Mentorship_Request__c();
            req.Intern__c = intern.Id;
            req.Request_Type__c = type;
            req.Description__c = description;
            req.Status__c = 'Open';
            insert req;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled(cacheable=true)
    public static List<Mentorship_Request__c> getMentorshipRequests(String token) {
        Intern__c intern = getInternByToken(token);
        return [SELECT Id, Request_Type__c, Status__c, Description__c, Mentor_Response__c, CreatedDate
                FROM Mentorship_Request__c
                WHERE Intern__c = :intern.Id
                ORDER BY CreatedDate DESC
                LIMIT 20];
    }

    @AuraEnabled(cacheable=true)
    public static List<Class_Session_Links__c> getClassSessionLinks() {
        try {
            // Fetch upcoming and today's sessions, ordered by date and start time
            return [SELECT Id, Name, Agenda__c, Date__c, Session_Start__c, Session_End__c,
                           Session_URL__c, Speaker__c
                    FROM Class_Session_Links__c
                    WHERE Date__c >= TODAY
                    ORDER BY Date__c ASC, Session_Start__c ASC
                    LIMIT 10];
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
}
