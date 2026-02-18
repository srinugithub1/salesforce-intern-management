try {
    Map<String, Object> result = InternAuthController.login('srinivasusfdc@gmail.com', 'hello123');
    System.debug('LOGIN SUCCESS: ' + result);
} catch (Exception e) {
    System.debug('LOGIN FAILED: ' + e.getMessage());
}
