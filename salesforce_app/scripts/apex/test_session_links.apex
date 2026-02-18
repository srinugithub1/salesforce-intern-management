try {
    Map<String, Object> sessionLink = new Map<String, Object>();
    sessionLink.put('Agenda__c', 'Test Agenda');
    sessionLink.put('Date__c', '2026-10-10');
    sessionLink.put('Session_Start__c', '10:00:00.000');
    sessionLink.put('Session_End__c', '11:00:00.000');
    sessionLink.put('Session_URL__c', 'https://test.com');
    sessionLink.put('Speaker__c', 'Test Speaker');
    
    AdminController.saveSessionLink(sessionLink);
    System.debug('Session Link Saved');
    
    List<Map<String, Object>> all = AdminController.getAllSessionLinks();
    System.debug('Total Session Links: ' + all.size());
    Boolean found = false;
    for(Map<String, Object> s : all) {
        if (s.get('Agenda__c') == 'Test Agenda') {
            found = true;
            AdminController.deleteSessionLink((String)s.get('Id')); // Clean up
            System.debug('Found and Deleted Test Session Link');
            break;
        }
    }
    if (!found) System.debug('FAILURE: Test Session Link not found');
} catch(Exception e) {
    System.debug('Error: ' + e.getMessage());
    System.debug(e.getStackTraceString());
}
