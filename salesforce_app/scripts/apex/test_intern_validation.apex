System.debug('--- Test 1: Invalid Email ---');
try {
    InternAuthController.registerIntern('Test', 'User', 'invalid@example.com', '1234567890', 'password', 'Test College', '123', 'Test Address');
    System.debug('Result: UNEXPECTED SUCCESS (Should have failed)');
} catch(Exception e) {
    System.debug('Result: EXPECTED ERROR -> ' + e.getMessage());
}

System.debug('--- Test 2: Valid Email (vaagdevibodhana@gmail.com) ---');
try {
    // Note: This might fail if the user is already in the Google Sheet from previous attempts.
    // We are testing whether it PASSES the Salesforce check, not necessarily the whole flow.
    // If it throws "User with this email already exists", that means it passed the Salesforce check and hit the Sheet check.
    InternAuthController.registerIntern('Test', 'User', 'vaagdevibodhana@gmail.com', '1234567890', 'password', 'Test College', '123', 'Test Address');
    System.debug('Result: SUCCESS (Or duplicate in sheet)');
} catch(Exception e) {
    System.debug('Result: ' + e.getMessage());
}
