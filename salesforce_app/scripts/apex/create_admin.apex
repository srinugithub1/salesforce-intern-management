try {
    // Check if exists
    List<List<Object>> rows = GoogleSheetsService.getSheetData('Admins');
    Boolean found = false;
    for (Integer i = 1; i < rows.size(); i++) {
        if (rows[i].size() > 2 && (String)rows[i][2] == 'admin@example.com') {
            found = true;
            break;
        }
    }
    
    if (!found) {
        String newId = 'admin-id-12345'; // Simple ID
        List<Object> newRow = new List<Object>();
        newRow.add(newId);
        newRow.add('Super Admin');
        newRow.add('admin@example.com');
        newRow.add('password123');
        newRow.add('Super Admin');
        newRow.add('');
        newRow.add(String.valueOf(System.now()));
        
        GoogleSheetsService.appendRow('Admins', newRow);
        System.debug('Default Admin Created Directly');
    } else {
        System.debug('Default Admin Already Exists');
    }
} catch (Exception e) {
    System.debug('Error creating admin: ' + e.getMessage());
    System.debug('Stack Trace: ' + e.getStackTraceString());
}
