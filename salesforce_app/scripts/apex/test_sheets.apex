try {
    String token = GoogleSheetsService.getAccessToken();
    System.debug('SUCCESS: Generated Access Token');
    
    // We can't easily test read/write without knowing a valid sheet name, 
    // but getting a token proves the Service Account cert is valid.
    // Let's try to read a dummy range to check API access
    // List<List<Object>> data = GoogleSheetsService.getSheetData('Sheet1!A1:A1');
    // System.debug('SUCCESS: Read Data: ' + data);
} catch (Exception e) {
    System.debug('FAILURE: ' + e.getMessage());
    System.debug(e.getStackTraceString());
}
