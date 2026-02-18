try {
    // 1. Create a task (simulate assignTaskToInterns)
    Map<String, Object> taskTemplate = new Map<String, Object>();
    taskTemplate.put('Name', 'Test Task Lifecycle');
    taskTemplate.put('Description__c', 'Initial Desc');
    taskTemplate.put('Priority__c', 'High');
    taskTemplate.put('Due_Date__c', '2026-12-31');
    
    // We need a valid intern ID. Let's fetch one or use a dummy if empty.
    List<Map<String, Object>> interns = AdminController.getAllInterns(null); // Assuming this works/returns empty
    String internId = interns.size() > 0 ? (String) interns[0].get('Id') : 'dummy-intern-id';
    
    // Hack: directly call assignTaskToInterns with match boolean true to avoid intern lookup if list is empty
    // But assignTaskToInterns iterates interns sheet. If interns sheet is empty, it won't create anything.
    // Let's use saveTask for creation if we can't rely on interns?
    // Wait, the user said "Task not created". Creating checks interns.
    
    // Let's try to append a task manually first to simulate "creation" if assign fails, 
    // OR just rely on assignTaskToInterns if we assume there are interns. 
    // If 0 tasks returned earlier, maybe no tasks exist.
    
    System.debug('Interns count: ' + interns.size());
    
    if (interns.size() > 0) {
        AdminController.assignTaskToInterns(taskTemplate, new List<String>{internId}, false, null);
        System.debug('Assigned task to intern: ' + internId);
        
        // 2. Fetch to get ID
        List<Map<String, Object>> tasks = AdminController.getAllTasks(null);
        String taskId = '';
        for(Map<String, Object> t : tasks) {
            if (t.get('Name') == 'Test Task Lifecycle') {
                taskId = (String) t.get('Id');
                System.debug('Found Task ID: ' + taskId);
                break;
            }
        }
        
        if (String.isNotBlank(taskId)) {
            // 3. Update task
            Map<String, Object> updateTask = new Map<String, Object>();
            updateTask.put('Id', taskId);
            updateTask.put('Name', 'Test Task Lifecycle Updated');
            updateTask.put('Description__c', 'Updated Desc');
            updateTask.put('Priority__c', 'Medium');
             updateTask.put('Due_Date__c', '2026-12-31');
            updateTask.put('Status__c', 'In Progress');
            updateTask.put('Intern__c', internId); 
            
            AdminController.saveTask(updateTask);
            System.debug('Updated Task');
            
            // 4. Verify Update
            tasks = AdminController.getAllTasks(null);
            for(Map<String, Object> t : tasks) {
                if (t.get('Id') == taskId) {
                    System.debug('Verified Update: ' + t.get('Name') + ' - ' + t.get('Status__c'));
                    if (t.get('Name') != 'Test Task Lifecycle Updated') System.debug('FAILURE: Name not updated');
                }
            }
            
            // 5. Delete
            AdminController.deleteTask(taskId);
            System.debug('Deleted Task');
        } else {
            System.debug('FAILURE: Could not find created task');
        }
    } else {
        System.debug('Skipping lifecycle test as no interns found to assign to.');
    }

} catch(Exception e) {
    System.debug('Error: ' + e.getMessage());
    System.debug(e.getStackTraceString());
}
