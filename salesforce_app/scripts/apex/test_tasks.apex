try {
    List<Map<String, Object>> tasks = AdminController.getAllTasks(null);
    System.debug('Retrieved ' + tasks.size() + ' tasks.');
    for (Map<String, Object> t : tasks) {
        System.debug('Task: ' + t);
    }
} catch(Exception e) {
    System.debug('Error retrieving tasks: ' + e.getMessage());
    System.debug(e.getStackTraceString());
}
