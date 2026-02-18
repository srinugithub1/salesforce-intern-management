try {
    List<Map<String, Object>> res = AdminController.getAllResources(null); // Pass null token as it's not used
    System.debug('Retrieved ' + res.size() + ' resources.');
    for (Map<String, Object> r : res) {
        System.debug('Resource: ' + r);
    }
} catch(Exception e) {
    System.debug('Error retrieving resources: ' + e.getMessage());
    System.debug(e.getStackTraceString());
}
