try {
    System.debug('--- TESTING validateSession(token) ---');
    
    // 1. Get a valid token (simulate login or just pick one)
    // For test, we will just pick the first valid token we find
    List<List<Object>> rows = GoogleSheetsService.getSheetData('Interns', true); 
    String testToken = null;
    
    for (Integer i = 1; i < rows.size(); i++) {
        if (rows[i].size() > 8 && String.isNotBlank((String)rows[i][8])) {
            testToken = (String) rows[i][8];
            System.debug('Found Test Token: ' + testToken);
            break;
        }
    }
    
    if (testToken != null) {
         System.debug('Validating Session...');
         Map<String, Object> result = InternAuthController.validateSession(testToken);
         if (result != null) {
             System.debug('SUCCESS: Valid Session. Name=' + result.get('Name'));
         } else {
             System.debug('FAILURE: Session Invalid (returned null).');
         }
    } else {
        System.debug('SKIPPING: No token found in sheet to test with.');
    }

} catch (Exception e) {
    System.debug('FAILURE: ' + e.getMessage());
}
