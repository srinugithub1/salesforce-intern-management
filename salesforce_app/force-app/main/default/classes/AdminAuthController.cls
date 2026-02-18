public without sharing class AdminAuthController {
    // Admins Sheet: 0:Id, 1:Name, 2:Email, 3:Password, 4:Role, 5:Token, 6:CreatedDate
    
    @AuraEnabled
    public static Map<String, Object> login(String email, String password) {
        try {
            List<List<Object>> rows = GoogleSheetsService.getSheetData('Admins');
            
            for (Integer i = 1; i < rows.size(); i++) { // Skip header
                List<Object> row = rows[i];
                if (row.size() > 3) {
                    if ((String) row[2] == email && (String) row[3] == password) {
                        // Success
                        String token = EncodingUtil.base64Encode(Crypto.generateAesKey(128));
                        
                        List<Object> newRow = row.clone();
                        while (newRow.size() <= 5) newRow.add('');
                        newRow[5] = token;
                        
                        GoogleSheetsService.updateRow('Admins', i + 1, newRow);
                        
                        return rowToAdminMap(newRow);
                    }
                }
            }
            throw new AuraHandledException('Invalid Credentials');
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled
    public static void registerAdmin(String name, String email, String password, String role) {
        try {
            // Check Duplicates?
            List<List<Object>> rows = GoogleSheetsService.getSheetData('Admins');
             for (Integer i = 1; i < rows.size(); i++) { 
                if (rows[i].size() > 2 && (String) rows[i][2] == email) {
                    throw new AuraHandledException('Admin with this email already exists.');
                }
             }
            
            String newId = generateUUID();
            String finalRole = String.isBlank(role) ? 'Team Lead' : role;
            
            List<Object> newRow = new List<Object>{
                newId, name, email, password, finalRole, '', String.valueOf(System.now())
            };
            GoogleSheetsService.appendRow('Admins', newRow);
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
    
    @AuraEnabled
    public static void logout(String token) {
        try {
            if (String.isBlank(token)) return;
            List<List<Object>> rows = GoogleSheetsService.getSheetData('Admins');
            for (Integer i = 1; i < rows.size(); i++) {
                if (rows[i].size() > 5 && (String) rows[i][5] == token) {
                    List<Object> newRow = rows[i].clone();
                    newRow[5] = '';
                    GoogleSheetsService.updateRow('Admins', i + 1, newRow);
                    return;
                }
            }
        } catch (Exception e) {
            // Ignore
        }
    }
    
    @AuraEnabled
    public static Map<String, Object> checkAuth(String token) {
        try {
            return getAdminByToken(token);
         } catch (Exception e) {
             throw new AuraHandledException('Admin Auth Check Failed: ' + e.getMessage());
         }
    }
    
    private static Map<String, Object> getAdminByToken(String token) {
        if (String.isEmpty(token)) {
             throw new AuraHandledException('Invalid Token');
        }
        List<List<Object>> rows = GoogleSheetsService.getSheetData('Admins');
        for (Integer i = 1; i < rows.size(); i++) {
            if (rows[i].size() > 5 && (String) rows[i][5] == token) {
                return rowToAdminMap(rows[i]);
            }
        }
        throw new AuraHandledException('Session Expired');
    }
    
    private static Map<String, Object> rowToAdminMap(List<Object> row) {
        Map<String, Object> admin = new Map<String, Object>();
        if (row.size() > 0) admin.put('Id', row[0]);
        if (row.size() > 1) admin.put('Name', row[1]);
        if (row.size() > 2) admin.put('Email__c', row[2]);
        if (row.size() > 4) admin.put('Role__c', row[4]);
        if (row.size() > 5) admin.put('Session_Token__c', row[5]);
        return admin;
    }
    
    private static String generateUUID() {
        Blob b = Crypto.generateAesKey(128);
        String h = EncodingUtil.convertToHex(b);
        return h.substring(0,8)+'-'+h.substring(8,12)+'-'+h.substring(12,16)+'-'+h.substring(16,20)+'-'+h.substring(20);
    }
}
