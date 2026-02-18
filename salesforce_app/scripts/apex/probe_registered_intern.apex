try {
    String query = 'SELECT Id, Email__c FROM Registered_Intern__c LIMIT 1';
    List<SObject> results = Database.query(query);
    System.debug('Query Successful. Found ' + results.size() + ' records.');
    if(results.size() > 0) {
        System.debug('First Record: ' + results[0]);
    }
} catch(Exception e) {
    System.debug('Error querying Registered_Intern__c: ' + e.getMessage());
}
