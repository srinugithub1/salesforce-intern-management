List<String> sheets = new List<String>{
    'Interns', 'Admins', 'Attendance', 'DailyLogs', 'Tasks', 'Leaves', 
    'Mentorships', 'Announcements', 'Resources', 'Syllabus', 'ClassSessionLinks'
};

for (String s : sheets) {
    try {
        List<List<Object>> data = GoogleSheetsService.getSheetData(s);
        System.debug('SUCCESS: Found ' + s + ' with ' + data.size() + ' rows.');
    } catch (Exception e) {
        System.debug('FAILURE: Could not find/read ' + s + '. Error: ' + e.getMessage());
    }
}
