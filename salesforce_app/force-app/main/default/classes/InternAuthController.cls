public without sharing class InternAuthController {
    @AuraEnabled
    public static Intern__c login(String email, String password) {
        try {
            // Query utilizing the new fields could be useful later, but sticking to core login needs
            List<Intern__c> interns = [SELECT Id, Name, Session_Token__c FROM Intern__c WHERE Email__c = :email AND Password__c = :password LIMIT 1];
            if (interns.isEmpty()) {
                throw new AuraHandledException('Invalid email or password.');
            }
            
            Intern__c intern = interns[0];
            // Generate new session/token if needed, or just return existing
            String token = EncodingUtil.base64Encode(Crypto.generateAesKey(128));
            intern.Session_Token__c = token;
            update intern;
            
            return intern;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled
    public static void logout(String token) {
        try {
            if (String.isBlank(token)) return;
            List<Intern__c> interns = [SELECT Id FROM Intern__c WHERE Session_Token__c = :token LIMIT 1];
            if (!interns.isEmpty()) {
                interns[0].Session_Token__c = null;
                update interns[0];
            }
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
    
    @AuraEnabled(cacheable=true)
    public static Intern__c validateSession(String token) {
         if (String.isBlank(token)) return null;
         List<Intern__c> interns = [SELECT Id, Name, Email__c, Phone__c FROM Intern__c WHERE Session_Token__c = :token LIMIT 1];
         if (interns.isEmpty()) {
             return null;
         }
         return interns[0];
    }
    @AuraEnabled
    public static void registerIntern(String firstName, String lastName, String email, String phone, String password, String college, String rollNo, String address) {
        try {
            // 1. DUPLICATE CHECK: Ensure email is not already registered as an Intern
            List<Intern__c> existing = [SELECT Id FROM Intern__c WHERE Email__c = :email LIMIT 1];
            if (!existing.isEmpty()) {
                throw new AuraHandledException('User with this email already exists.');
            }

            // 2. VALIDATION CHECK: Ensure email is pre-approved in Registered_Intern__c
            List<Registered_Intern__c> allowedEmails = [SELECT Id FROM Registered_Intern__c WHERE Email__c = :email LIMIT 1];
            if (allowedEmails.isEmpty()) {
                throw new AuraHandledException('Give me your Registered Email address.');
            }

            Intern__c newIntern = new Intern__c();
            newIntern.Name = firstName + ' ' + lastName; // Concatenate Name
            newIntern.Email__c = email;
            newIntern.Phone__c = phone;
            newIntern.Password__c = password;
            newIntern.College_Name__c = college;
            newIntern.Roll_Number__c = rollNo;
            newIntern.Address__c = address;
            
            insert newIntern;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
}
