public without sharing class AdminAuthController {
    @AuraEnabled
    public static Admin_User__c login(String email, String password) {
        try {
            List<Admin_User__c> admins = [SELECT Id, Name, Email__c, Password__c, Role__c FROM Admin_User__c WHERE Email__c = :email LIMIT 1];
            
            if (admins.isEmpty() || admins[0].Password__c != password) {
                throw new AuraHandledException('Invalid Credentials');
            }
            
            Admin_User__c admin = admins[0];
            admin.Session_Token__c = generateToken();
            update admin;
            
            return admin;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled
    public static void registerAdmin(String name, String email, String password, String role) {
        try {
            Admin_User__c admin = new Admin_User__c(
                Name = name,
                Email__c = email,
                Password__c = password,
                Role__c = String.isBlank(role) ? 'Team Lead' : role
            );
            insert admin;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
    
    @AuraEnabled
    public static void logout(String token) {
        try {
            Admin_User__c admin = getAdminByToken(token);
            admin.Session_Token__c = null;
            update admin;
        } catch (Exception e) {
            // Already logged out or invalid token, ignore
        }
    }
    
    @AuraEnabled
    public static Admin_User__c checkAuth(String token) {
        try {
            return getAdminByToken(token);
        } catch (Exception e) {
            return null;
        }
    }
    
    private static String generateToken() {
        return EncodingUtil.base64Encode(Crypto.generateAesKey(128));
    }
    
    private static Admin_User__c getAdminByToken(String token) {
        if (String.isEmpty(token)) {
             throw new AuraHandledException('Invalid Token');
        }
        List<Admin_User__c> admins = [SELECT Id, Name, Role__c, Session_Token__c FROM Admin_User__c WHERE Session_Token__c = :token LIMIT 1];
        if (admins.isEmpty()) {
            throw new AuraHandledException('Session Expired');
        }
        return admins[0];
    }
}
