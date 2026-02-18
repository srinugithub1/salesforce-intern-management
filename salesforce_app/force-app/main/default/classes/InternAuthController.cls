public without sharing class InternAuthController {
    
    @AuraEnabled
    public static Map<String, Object> login(String email, String password) {
        try {
            System.debug('Login Attempt: ' + email + ' / ' + password);
            // Use avoidDml=true to prevent "Uncommitted Work Pending" error if cache is updated before updateRow callout
            List<List<Object>> rows = GoogleSheetsService.getSheetData('Interns', true);
            System.debug('Total Rows Fetched: ' + rows.size());
            
            for (Integer i = 1; i < rows.size(); i++) { // Skip header
                List<Object> row = rows[i];
                if (row.size() > 4) {
                    String rowEmail = (String) row[2];
                    String rowPassword = (String) row[4];
                    
                    System.debug('Row ' + i + ': ' + rowEmail + ' / ' + rowPassword);
                    
                    if (rowEmail != null && rowEmail.trim().equalsIgnoreCase(email.trim()) && rowPassword != null && rowPassword.equals(password)) {
                         String token = EncodingUtil.base64Encode(Crypto.generateAesKey(128));
                         
                         List<Object> newRow = row.clone();
                         while (newRow.size() <= 8) newRow.add('');
                         newRow[8] = token;
                         
                         GoogleSheetsService.updateRow('Interns', i + 1, newRow);
                         
                         return rowToInternMap(newRow);
                    }
                }
            }
            System.debug('No matching user found.');
            throw new AuraHandledException('Invalid email or password.');
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled
    public static void logout(String token) {
        try {
            if (String.isBlank(token)) return;
            List<List<Object>> rows = GoogleSheetsService.getSheetData('Interns');
             for (Integer i = 1; i < rows.size(); i++) {
                List<Object> row = rows[i];
                if (row.size() > 8 && (String) row[8] == token) {
                    List<Object> newRow = row.clone();
                    newRow[8] = ''; // Clear token
                    GoogleSheetsService.updateRow('Interns', i + 1, newRow);
                    return;
                }
             }
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
    
    @AuraEnabled(cacheable=true)
    public static Map<String, Object> validateSession(String token) {
         if (String.isBlank(token)) return null;
         try {
             List<List<Object>> rows = GoogleSheetsService.getSheetData('Interns', true);
             for (Integer i = 1; i < rows.size(); i++) { // Skip header
                List<Object> row = rows[i];
                if (row.size() > 8 && (String) row[8] == token) {
                    return rowToInternMap(row);
                }
             }
         } catch(Exception e) {
             System.debug('Session Validation Failed: ' + e.getMessage());
             throw new AuraHandledException('Session check failed: ' + e.getMessage());
         }
         return null;
    }

    @AuraEnabled
    public static void registerIntern(String firstName, String lastName, String email, String phone, String password, String college, String rollNo, String address) {
        System.debug('--- Intern Registration Start: ' + email + ' ---');
        try {
            // 1. Validation: Check if email exists in Google Sheet 'Registered_Interns' (Whitelist)
            List<List<Object>> registeredRows = GoogleSheetsService.getSheetData('Registered_Interns', true);
            boolean isWhitelisted = false;
            
            for (Integer i = 1; i < registeredRows.size(); i++) {
                if (registeredRows[i].size() > 0 && (String) registeredRows[i][0] == email) {
                    isWhitelisted = true;
                    break;
                }
            }
            
            if (!isWhitelisted) {
                 throw new AuraHandledException('This email is not registered in our system. Please contact the Administrator.');
            }

            // 2. Duplicate Check: Ensure user is not already registered in Google Sheet 'Interns'
            List<List<Object>> internRows = GoogleSheetsService.getSheetData('Interns', true);
            for (Integer i = 1; i < internRows.size(); i++) {
                if (internRows[i].size() > 2 && (String) internRows[i][2] == email) {
                     if (internRows[i].size() > 4 && String.isNotBlank((String)internRows[i][4])) {
                         throw new AuraHandledException('User with this email already exists. Please login.');
                     }
                     throw new AuraHandledException('User with this email already exists.');
                }
            }

            // 3. Create New Record
            String newId = generateUUID();
            String name = firstName + ' ' + lastName;
            String now = String.valueOf(DateTime.now());
            
            List<Object> newRow = new List<Object>{
                newId, name, email, (phone.startsWith('\'') ? phone : '\'' + phone), password, college, rollNo, address, '', now
            };
            
            GoogleSheetsService.appendRow('Interns!A1', newRow);
            
        } catch (Exception e) {
            System.debug('Registration Error: ' + e.getMessage());
            // Important: Throwing AuraHandledException allows LWC to catch it.
            // We must preserve the message.
            String msg = e.getMessage();
            if (msg.contains('Script-thrown exception')) {
                msg = msg.replace('Script-thrown exception', '').trim();
                // If it was already AuraHandled, try to extract real message if buried
            }
            throw new AuraHandledException(msg);
        }
    }
    
    private static Map<String, Object> rowToInternMap(List<Object> row) {
        Map<String, Object> intern = new Map<String, Object>();
        if (row.size() > 0) intern.put('Id', (String) row[0]);
        if (row.size() > 1) intern.put('Name', (String) row[1]);
        if (row.size() > 2) intern.put('Email__c', (String) row[2]);
        if (row.size() > 3) intern.put('Phone__c', (String) row[3]);
        if (row.size() > 5) intern.put('College_Name__c', (String) row[5]);
        if (row.size() > 6) intern.put('Roll_Number__c', (String) row[6]);
        if (row.size() > 7) intern.put('Address__c', (String) row[7]);
        if (row.size() > 8) intern.put('Session_Token__c', (String) row[8]);
        
        return intern;
    }
    
    private static String generateUUID() {
        Blob b = Crypto.generateAesKey(128);
        String h = EncodingUtil.convertToHex(b);
        return h.substring(0,8)+'-'+h.substring(8,12)+'-'+h.substring(12,16)+'-'+h.substring(16,20)+'-'+h.substring(20);
    }
}
