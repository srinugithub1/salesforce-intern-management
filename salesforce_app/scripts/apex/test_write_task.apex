try {
    List<Object> newRow = new List<Object>{ 'test-id', 'intern-id', 'Test Write', 'Desc', 'Assigned', '2026-01-01', '', '', 'High', '', String.valueOf(System.now()) };
    GoogleSheetsService.appendRow('Tasks', newRow);
    System.debug('Write Success');
} catch(Exception e) {
    System.debug('Write Failed: ' + e.getMessage());
    System.debug(e.getStackTraceString());
}
