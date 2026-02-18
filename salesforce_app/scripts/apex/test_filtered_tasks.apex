try {
    Map<String, Object> result = AdminController.getFilteredTasks(null, null, null, 'All', 10, 1, null);
    System.debug('Total Records: ' + result.get('totalRecords'));
    List<Map<String, Object>> tasks = (List<Map<String, Object>>) result.get('tasks');
    System.debug('Tasks Count: ' + tasks.size());
    for(Map<String, Object> t : tasks) {
        System.debug('Task: ' + t);
    }
} catch(Exception e) {
    System.debug('Error: ' + e.getMessage());
    System.debug(e.getStackTraceString());
}
