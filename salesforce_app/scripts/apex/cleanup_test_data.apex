// Cleanup Script
System.debug('--- CLEANUP: Searching for TestStorage User ---');
List<List<Object>> internRows = GoogleSheetsService.getSheetData('Interns');
if (internRows != null) {
    // Iterate backwards to avoid index shifting if we delete multiple (though we expect one)
    for (Integer i = internRows.size() - 1; i >= 0; i--) {
        List<Object> row = internRows[i];
        if (row.size() > 1 && String.valueOf(row[1]) == 'TestStorage User') {
            System.debug('Deleting TestStorage User at Row ' + (i + 1)); // 1-based index for deleteRow
            GoogleSheetsService.deleteRow('Interns', i + 1);
        }
    }
}
System.debug('--- CLEANUP COMPLETE ---');
