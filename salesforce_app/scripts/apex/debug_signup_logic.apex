String testEmailInvalid = 'invalid@test.com'; // Not in whitelist
String testEmailValid = 'valid@test.com'; // Should be in whitelist (need to ensure this exists or mock it)
String testEmailDuplicate = 'existing@test.com'; // Already signed up

System.debug('--- TEST 1: Invalid Email (Not in Whitelist) ---');
Map<String, String> res1 = InternAuthController.registerInternV2('Test', 'User', testEmailInvalid, '1234567890', 'password', 'College', '123', 'Address');
System.debug('Result 1: ' + res1);

// We need to know what IS in the sheet to test the positive case.
// Let's print the first few rows of Registered_Interns to see what's there.
System.debug('--- DATA: Registered_Interns Dump ---');
List<List<Object>> rows = GoogleSheetsService.getSheetData('Registered_Interns');
if (rows != null) {
    for (Integer i = 0; i < Math.min(rows.size(), 5); i++) {
        System.debug('Row ' + i + ': ' + rows[i]);
    }
} else {
    System.debug('Registered_Interns returned NULL');
}
