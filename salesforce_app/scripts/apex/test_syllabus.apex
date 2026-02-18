try {
    Map<String, Object> syllabus = new Map<String, Object>();
    syllabus.put('Course_Name__c', 'Test Course');
    syllabus.put('Module_Name__c', 'Test Module');
    syllabus.put('Topic_Name__c', 'Test Topic');
    
    AdminController.saveSyllabus(syllabus);
    System.debug('Syllabus Saved');
    
    List<Map<String, Object>> all = AdminController.getAllSyllabus();
    System.debug('Total Syllabus: ' + all.size());
    Boolean found = false;
    for(Map<String, Object> s : all) {
        if (s.get('Course_Name__c') == 'Test Course') {
            found = true;
            AdminController.deleteSyllabus((String)s.get('Id')); // Clean up
            System.debug('Found and Deleted Test Syllabus');
            break;
        }
    }
    if (!found) System.debug('FAILURE: Test Syllabus not found');
} catch(Exception e) {
    System.debug('Error: ' + e.getMessage());
    System.debug(e.getStackTraceString());
}
