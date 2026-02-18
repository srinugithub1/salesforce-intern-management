try {
    List<List<Object>> rows = GoogleSheetsService.getSheetData('Interns');
    System.debug('Intern Sheet Rows (Direct): ' + rows.size());
} catch(Exception e) {
    System.debug('Error: ' + e.getMessage());
}
