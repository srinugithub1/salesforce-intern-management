try {
    // We can't call InternAuthController.login directly if it throws AuraHandledException in anonymous apex context
    // So we will replicate the logic here to see the debugs
    System.debug('--- MANUAL DEBUG START ---');
    List<List<Object>> rows = GoogleSheetsService.getSheetData('Interns');
    System.debug('Total Rows: ' + rows.size());
    String email = 'srinivasusfdc@gmail.com';
    String password = 'hello123';
    
    for (Integer i = 1; i < rows.size(); i++) {
        List<Object> row = rows[i];
        if (row.size() > 4) {
            String rowEmail = (String) row[2];
            String rowPassword = (String) row[4];
            System.debug('Row ' + i + ': [' + rowEmail + '] / [' + rowPassword + ']');
            
            if (rowEmail != null && rowEmail.trim().equalsIgnoreCase(email) && rowPassword != null && rowPassword.equals(password)) {
                System.debug('MATCH FOUND at Row ' + i);
            }
        } else {
             System.debug('Row ' + i + ' has insufficient columns: ' + row.size());
        }
    }
    System.debug('--- MANUAL DEBUG END ---');
} catch (Exception e) {
    System.debug('ERROR: ' + e.getMessage());
}
