// 1. Pick a valid email from Registered_Interns (we saw 'lavanyasdevanga24@gmail.com' in previous logs)
String validEmail = 'lavanyasdevanga24@gmail.com'; 
String uniquePhone = String.valueOf(DateTime.now().getTime()).right(10); // Ensure unique phone if that matters

System.debug('--- TEST: Registering Valid User ---');
try {
    InternAuthController.registerIntern(
        'TestStorage', 
        'User', 
        validEmail, 
        uniquePhone, 
        'password123', 
        'Test College', 
        '12345', 
        'Test Address'
    );
    System.debug('Method executed without exception.');
} catch (Exception e) {
    System.debug('Method FAILED with exception: ' + e.getMessage());
}

// 2. Init immediate check of Interns sheet
System.debug('--- VERIFICATION: Checking Interns Sheet ---');
List<List<Object>> internRows = GoogleSheetsService.getSheetData('Interns');
Boolean found = false;
if (internRows != null) {
    for (Integer i = 0; i < internRows.size(); i++) {
        List<Object> row = internRows[i];
        System.debug('Row ' + i + ': ' + row); // DUMP ALL ROWS
        // Check if our unique phone or name exists (Email might exist from previous tests)
        // Let's check for the Name 'TestStorage User'
        if (row.size() > 1 && String.valueOf(row[1]) == 'TestStorage User') {
            System.debug('SUCCESS: Found record in Interns sheet: ' + row);
            found = true;
            // break; // Don't break, see if there are duplicates
        }
    }
}

if (!found) {
    System.debug('FAILURE: Record NOT found in Interns sheet.');
}
