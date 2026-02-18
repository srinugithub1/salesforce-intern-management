try {
    System.debug('--- TESTING getSheetData(..., avoidDml=true) ---');
    List<List<Object>> rows = GoogleSheetsService.getSheetData('Interns', true);
    System.debug('SUCCESS: Fetched ' + rows.size() + ' rows.');
    
    if (rows.size() > 1) {
        System.debug('Sample Row 1: ' + rows[1]);
    }
} catch (Exception e) {
    System.debug('FAILURE: ' + e.getMessage());
}
