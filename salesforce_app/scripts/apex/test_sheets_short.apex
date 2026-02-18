try {
    String token = GoogleSheetsService.getAccessToken();
    System.debug('TOKEN_SUCCESS');
} catch (Exception e) {
    System.debug('TOKEN_FAILURE: ' + e.getMessage().substring(0, Math.min(e.getMessage().length(), 300)));
}
