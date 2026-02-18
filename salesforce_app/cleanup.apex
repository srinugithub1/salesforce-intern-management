List<ContentDocument> docs = [SELECT Id FROM ContentDocument WHERE Title LIKE 'Cache_%'];
delete docs;
System.debug('Deleted ' + docs.size() + ' cache files');
