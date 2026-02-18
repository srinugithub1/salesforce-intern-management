// Setup Script for Google Sheets
// Execute via: sf apex run -f scripts/apex/setup_sheets.apex

try {
    // 1. Interns
    GoogleSheetsService.createSheet('Interns');
    GoogleSheetsService.appendRow('Interns', new List<Object>{'Id', 'Name', 'Email__c', 'Phone__c', 'Password__c', 'College_Name__c', 'Roll_Number__c', 'Address__c', 'Session_Token__c', 'CreatedDate', 'Start_Date__c', 'End_Date__c', 'Team_Lead__c'});
    System.debug('Interns Sheet Created');

    // 2. Admins
    GoogleSheetsService.createSheet('Admins');
    GoogleSheetsService.appendRow('Admins', new List<Object>{'Id', 'Name', 'Email__c', 'Password__c', 'Role__c', 'Session_Token__c', 'CreatedDate'});
    System.debug('Admins Sheet Created');

    // 3. Attendance
    GoogleSheetsService.createSheet('Attendance');
    GoogleSheetsService.appendRow('Attendance', new List<Object>{'Id', 'InternId', 'Login_Time__c', 'Logout_Time__c', 'Status__c', 'Date__c', 'Duration__c', 'CreatedDate'});
    System.debug('Attendance Sheet Created');

    // 4. DailyLogs
    GoogleSheetsService.createSheet('DailyLogs');
    GoogleSheetsService.appendRow('DailyLogs', new List<Object>{'Id', 'InternId', 'Log_Date__c', 'Work_Description__c', 'Hours_Spent__c', 'Course__c', 'Module__c', 'Topic__c', 'Submission_Link__c', 'Learnings__c', 'Blockers__c'});
    System.debug('DailyLogs Sheet Created');

    // 5. Tasks
    GoogleSheetsService.createSheet('Tasks');
    GoogleSheetsService.appendRow('Tasks', new List<Object>{'Id', 'InternId', 'Name', 'Description__c', 'Status__c', 'Due_Date__c', 'Remarks__c', 'Today_Work_Progress__c', 'Priority__c', 'Submission_Link__c', 'CreatedDate'});
    System.debug('Tasks Sheet Created');

    // 6. Leaves
    GoogleSheetsService.createSheet('Leaves');
    GoogleSheetsService.appendRow('Leaves', new List<Object>{'Id', 'InternId', 'Start_Date__c', 'End_Date__c', 'Reason__c', 'Status__c', 'CreatedDate'});
    System.debug('Leaves Sheet Created');

    // 7. Mentorships
    GoogleSheetsService.createSheet('Mentorships');
    GoogleSheetsService.appendRow('Mentorships', new List<Object>{'Id', 'InternId', 'Request_Type__c', 'Description__c', 'Status__c', 'Mentor_Response__c', 'CreatedDate'});
    System.debug('Mentorships Sheet Created');

    // 8. Announcements
    GoogleSheetsService.createSheet('Announcements');
    GoogleSheetsService.appendRow('Announcements', new List<Object>{'Id', 'Message__c', 'Type__c', 'Date__c', 'Link__c', 'Active'});
    System.debug('Announcements Sheet Created');

    // 9. Resources
    GoogleSheetsService.createSheet('Resources');
    GoogleSheetsService.appendRow('Resources', new List<Object>{'Id', 'Title__c', 'Description__c', 'Link__c', 'Type__c', 'CreatedDate'});
    System.debug('Resources Sheet Created');

    // 10. Syllabus
    GoogleSheetsService.createSheet('Syllabus');
    GoogleSheetsService.appendRow('Syllabus', new List<Object>{'Id', 'Course_Name__c', 'Module_Name__c'});
    System.debug('Syllabus Sheet Created');

    // 11. ClassSessionLinks
    GoogleSheetsService.createSheet('ClassSessionLinks');
    GoogleSheetsService.appendRow('ClassSessionLinks', new List<Object>{'Id', 'Name', 'Agenda__c', 'Date__c', 'Session_Start__c', 'Session_End__c', 'Session_URL__c', 'Speaker__c'});
    System.debug('ClassSessionLinks Sheet Created');

} catch (Exception e) {
    System.debug('Error in Setup: ' + e.getMessage());
}
