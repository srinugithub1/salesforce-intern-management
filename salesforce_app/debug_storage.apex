try {
    ContentVersion cv = new ContentVersion();
    cv.Title = 'Test_Cache_File';
    cv.PathOnClient = 'Test_Cache_File.json';
    cv.VersionData = Blob.valueOf('{"test": "data"}');
    cv.IsMajorVersion = true;
    insert cv;
    System.debug('SUCCESS: Created Test File. Id: ' + cv.Id);
    
    // Clean it up immediately
    Id docId = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id].ContentDocumentId;
    delete [SELECT Id FROM ContentDocument WHERE Id = :docId];
    System.debug('SUCCESS: Deleted Test File.');
} catch (Exception e) {
    System.debug('FAILURE: ' + e.getMessage());
    System.debug('Stack Trace: ' + e.getStackTraceString());
}
