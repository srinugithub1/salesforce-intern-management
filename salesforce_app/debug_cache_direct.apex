try {
    System.debug('--- DIRECT CACHE INSPECTION ---');
    List<GoogleSheetCache__c> caches = [SELECT JsonData__c FROM GoogleSheetCache__c WHERE Name = 'Interns' LIMIT 1];
    
    if (caches.isEmpty()) {
        System.debug('CACHE MISSING!');
    } else {
        String jsonString = caches[0].JsonData__c;
        System.debug('Cache Length: ' + jsonString.length());
        
        Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(jsonString);
        List<Object> rows = (List<Object>) responseMap.get('values');
        System.debug('Total Rows in Cache: ' + rows.size());

        String email = 'srinivasusfdc@gmail.com';
        String password = 'hello123';
        
        for (Integer i = 1; i < rows.size(); i++) {
            List<Object> row = (List<Object>) rows[i];
            if (row.size() > 4) {
               String rowEmail = (String) row[2];
               String rowPassword = (String) row[4];
               
               // Debug exact content (check for hidden chars)
               System.debug('Row ' + i + ': "' + rowEmail + '" / "' + rowPassword + '"');
               
               if (rowEmail.trim().equalsIgnoreCase(email) && rowPassword == password) {
                   System.debug('SUCCESS: CREDENTIALS MATCH at Row ' + i);
               }
            }
        }
    }
} catch (Exception e) {
    System.debug('ERROR: ' + e.getMessage());
}
