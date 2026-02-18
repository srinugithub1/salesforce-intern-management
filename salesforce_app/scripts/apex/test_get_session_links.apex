try {
    List<Map<String, Object>> links = AdminController.getAllSessionLinks();
    System.debug('Retrieved ' + links.size() + ' session links.');
    for (Map<String, Object> link : links) {
        System.debug('Link: ' + link);
    }
} catch(Exception e) {
    System.debug('Error retrieving session links: ' + e.getMessage());
    System.debug(e.getStackTraceString());
}
