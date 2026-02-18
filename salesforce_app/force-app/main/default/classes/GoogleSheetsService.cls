public class GoogleSheetsService {
    // START CONFIGURATION
    private static final String CLIENT_EMAIL = 'internship-application-data@chromatic-line-461105-u3.iam.gserviceaccount.com';
    private static final String PRIVATE_KEY_PEM = '-----BEGIN PRIVATE KEY-----\n' +
'MIIEvgIBADANBgkqhkiG9w0BAQEFAASCBKgwggSkAgEAAoIBAQCmC1GCUJMOo4lA\n' +
'uOfftAnMzFSa1SXn4lQ42VZkxDgRdXZW8rFgM8KCn6tDJ9AptnRiEqzcMFBWDzKn\n' +
'wk9+xz3VfMx8g0fgyk76C19AggEy8KjTnIq00EG2CBfPiBXcLUqUj/7Drw+Digi+\n' +
'5ip6+CLGD0La4UZJKAMO8d1nQzyea3yaQ2Egp2X1tY2RMlflScU3KULHOaGHnWXn\n' +
'/XeSQhAyfa1lLVz/2HdGY7viwrv9o9MMNEG+rQQlnkWYWxiEQ9URyE62BzQrnXMe\n' +
'8bHEX/oi8J9r4MgbX3k+7RbDOnXzDrGZAu+QoZYwK4RyfmxeknKTk4RVk6pPv7Kb\n' +
'xCpz0hn9AgMBAAECggEABBFT6lrZ92pXMvA0sfzBnrREwFRHbPJU+N2OKcLK0tar\n' +
'Uv74DHDIK5YIxojjpxnyqPJnLK+8UBdoOMbgVq0/3QqFIem/aYjbPXHo3/YvXFWb\n' +
'9S8pELvnWDPDjZB6ZJ3xbUlHxvhza1gG1dJiqQeKJor6Ks2JAMLLrGKNd3mkswbJ\n' +
'+JJgDX3PH+AtqwQir9oCS+WxbqximhVwl8/3IRFPrUoND1oyYN4LDPWVlLHWqsjE\n' +
'RI6i1MuqYtwhNluuRxouhvCXkn08A7GCDNHN2TlZb1e7ZugRzxXwAbdVi6SXQy1e\n' +
'T48DST2qNLyURj7V3aaTKm6XbGJGKWrm4w1HQEfYWwKBgQDSgsspZO1MA087eSUx\n' +
'mlgvVcMHRCEgkEFgdho4W1zWyfg4ALZCKJfy/6ZAN85onGOhYZi38nRJK7Svesr1\n' +
'T7uhKmWb8F6vvYuagt4pjiW/BDItiLv9iar5yrU9Frd8heqgMv2YqaBpikANB3ux\n' +
'ALX8KJTrMgryfkLxzV6+dzHZpwKBgQDJ7K5pWBdxIzkwVr9N/5JKE3gJ3TcTG94G\n' +
'ria0U5szGAqf+0QLH+UViV6aUVr0fIcP5AaMXCCfyR4dQL09oQumc12DpB/d0HKs\n' +
'oOITP9e+elKJYmQPMD2cm/JybrPIHOptksZ14BOFFHRGQUvnDwWM+rMKg1VJm0N2\n' +
'HEMXY2CbuwKBgQCzzngNsWFm7eS9XerBBZ6RP+XHzQ+mqtDMvdQDkzYnWHgmDaWf\n' +
'uOCg9HBipcguXnZTH/O8GuHspeI9iNrW0fXn4TjNC3E1FuepYGK2h+4BzGm3rvUz\n' +
'yGU720MXHNI5EIGpuCQYQ7r6qtWuy1eBhqPq8BbTFfl3yxUPSGXGtjTkPQKBgQCx\n' +
'hCikpfQd23h4XZrbKFZkVw9NpLO5UeNz/gA6wdGMLpOQp6XfHdAYieaoReNvUlau\n' +
'iqmTFZ78uiOGVhbIKl+CmqNYip4VNB7MUrfNcm/pncIX027hx2gy2QpgvZ/BymHx\n' +
'qHpewHqIoT3DUb43yIX5taBXGrSM/DlniVsWIaCZ5wKBgAVbbYCC2X/rCw5UfmKD\n' +
'MPMM467gDTnB4sG2HnF90K+pl9dWpsaO1au/xpWARdF5zbb4334wcEOvKlW+Y9cr\n' +
'KgwwTMegGnW0pe++D0aV1aduve6ThtWr73KnksmnBcNsBJiGExX3I/jsOei5uHEp\n' +
'OFXOXyTSXtMtc3bkh30CIv3M\n' +
'-----END PRIVATE KEY-----';

    public static String SPREADSHEET_ID = '1kcq_2GUNARS0hYFBtabt7PJX5PeRqfNLeDk08w-uju8'; 
    // END CONFIGURATION

    private static final String GOOGLE_TOKEN_URL = 'https://oauth2.googleapis.com/token';
    private static final String SHEETS_API_URL = 'https://sheets.googleapis.com/v4/spreadsheets/';
    private static final String SCOPE = 'https://www.googleapis.com/auth/spreadsheets';
    
    private static String cachedAccessToken = null;

    public static String getAccessToken() {
        if (cachedAccessToken != null) return cachedAccessToken;
        
        if (String.isEmpty(CLIENT_EMAIL) || String.isEmpty(PRIVATE_KEY_PEM)) {
            throw new CalloutException('Google Service Account Credentials are configured.');
        }

        String header = '{"alg":"RS256","typ":"JWT"}';
        String headerBase64 = base64UrlEncode(Blob.valueOf(header));

        Long now = DateTime.now().getTime() / 1000;
        Long exp = now + 3600;
        String claimSet = '{"iss":"' + CLIENT_EMAIL + '",';
        claimSet += '"scope":"' + SCOPE + '",';
        claimSet += '"aud":"' + GOOGLE_TOKEN_URL + '",';
        claimSet += '"exp":' + exp + ',';
        claimSet += '"iat":' + now + '}';
        String claimSetBase64 = base64UrlEncode(Blob.valueOf(claimSet));

        String cleanKey = PRIVATE_KEY_PEM
            .replace('-----BEGIN PRIVATE KEY-----', '')
            .replace('-----END PRIVATE KEY-----', '')
            .replace('\n', '');
        
        Blob privateKeyBlob = EncodingUtil.base64Decode(cleanKey);
        
        String input = headerBase64 + '.' + claimSetBase64;
        Blob signatureBlob = Crypto.sign('RSA-SHA256', Blob.valueOf(input), privateKeyBlob);
        String signatureBase64 = base64UrlEncode(signatureBlob);
        String jwt = input + '.' + signatureBase64;

        HttpRequest req = new HttpRequest();
        req.setEndpoint(GOOGLE_TOKEN_URL);
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/x-www-form-urlencoded');
        req.setBody('grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer&assertion=' + jwt);

        Http http = new Http();
        HttpResponse res = http.send(req);

        if (res.getStatusCode() == 200) {
            Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
            cachedAccessToken = (String) responseMap.get('access_token');
            return cachedAccessToken;
        } else {
            System.debug('Error Response: ' + res.getBody());
            throw new CalloutException('Failed to get access token: ' + res.getBody());
        }
    }
    
    private static String base64UrlEncode(Blob input) {
        String output = EncodingUtil.base64Encode(input);
        output = output.replace('+', '-');
        output = output.replace('/', '_');
        while (output.endsWith('=')) {
            output = output.substring(0, output.length() - 1);
        }
        return output;
    }

    public static void appendRow(String sheetName, List<Object> rowData) {
        if (String.isEmpty(SPREADSHEET_ID)) throw new CalloutException('Spreadsheet ID is not set.');
        
        String accessToken = getAccessToken();
        
        Map<String, Object> valueRange = new Map<String, Object>();
        valueRange.put('range', sheetName);
        valueRange.put('majorDimension', 'ROWS');
        valueRange.put('values', new List<List<Object>>{ rowData });

        String jsonBody = JSON.serialize(valueRange);

        String endpoint = SHEETS_API_URL + SPREADSHEET_ID + '/values/' + EncodingUtil.urlEncode(sheetName, 'UTF-8') + ':append';
        endpoint += '?valueInputOption=USER_ENTERED';

        HttpRequest req = new HttpRequest();
        req.setEndpoint(endpoint);
        req.setMethod('POST');
        req.setHeader('Authorization', 'Bearer ' + accessToken);
        req.setHeader('Content-Type', 'application/json');
        req.setBody(jsonBody);

        HttpResponse res = executeCalloutWithRetry(req);

        if (res.getStatusCode() != 200) {
             System.debug('Error Appending Row: ' + res.getBody());
            throw new CalloutException('Failed to append row to Google Sheet: ' + res.getBody());
        } else {
            System.debug('SUCCESS Appending Row. Response: ' + res.getBody());
            deleteOldCache(sheetName);
        }
    }

    public static void updateRow(String sheetName, Integer rowNumber, List<Object> rowData) {
        if (String.isEmpty(SPREADSHEET_ID)) throw new CalloutException('Spreadsheet ID is not set.');
        
        String accessToken = getAccessToken();
        
        Map<String, Object> valueRange = new Map<String, Object>();
        valueRange.put('range', sheetName + '!A' + rowNumber);
        valueRange.put('majorDimension', 'ROWS');
        valueRange.put('values', new List<List<Object>>{ rowData });

        String jsonBody = JSON.serialize(valueRange);

        String endpoint = SHEETS_API_URL + SPREADSHEET_ID + '/values/' + EncodingUtil.urlEncode(sheetName + '!A' + rowNumber, 'UTF-8');
        endpoint += '?valueInputOption=USER_ENTERED';

        HttpRequest req = new HttpRequest();
        req.setEndpoint(endpoint);
        req.setMethod('PUT');
        req.setHeader('Authorization', 'Bearer ' + accessToken);
        req.setHeader('Content-Type', 'application/json');
        req.setBody(jsonBody);

        HttpResponse res = executeCalloutWithRetry(req);

        if (res.getStatusCode() != 200) {
             System.debug('Error Updating Row: ' + res.getBody());
            throw new CalloutException('Failed to update row in Google Sheet: ' + res.getBody());
        }
        deleteOldCache(sheetName);
    }

    public static List<List<Object>> getSheetData(String sheetName) {
        return getSheetData(sheetName, false);
    }

    public static List<List<Object>> getSheetData(String sheetName, Boolean avoidDml) {
         // 1. Check Cache
         String cachedJson = getCacheContent(sheetName, avoidDml);
         if (cachedJson != null) {
              return parseJsonRows(cachedJson);
         }

         if (String.isEmpty(SPREADSHEET_ID)) throw new CalloutException('Spreadsheet ID is not set.');

         String accessToken = getAccessToken();

         String endpoint = SHEETS_API_URL + SPREADSHEET_ID + '/values/' + EncodingUtil.urlEncode(sheetName, 'UTF-8');
         
         HttpRequest req = new HttpRequest();
         req.setEndpoint(endpoint);
         req.setMethod('GET');
         req.setHeader('Authorization', 'Bearer ' + accessToken);
         
         HttpResponse res = executeCalloutWithRetry(req);
         
         if (res.getStatusCode() == 200) {
             String responseBody = res.getBody();
             // 2. Save to Cache ONLY if allowed
             if (!avoidDml) {
                saveCacheContent(sheetName, responseBody);
             }
             
             return parseJsonRows(responseBody);
         } else {
             System.debug('Error Reading Sheet: ' + res.getBody());
             throw new CalloutException('Failed to read data from Google Sheet: ' + res.getBody());
         }
    }
    
    private static List<List<Object>> parseJsonRows(String jsonString) {
         Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(jsonString);
         if (responseMap.containsKey('values')) {
             List<Object> rowsObj = (List<Object>) responseMap.get('values');
             List<List<Object>> data = new List<List<Object>>();
             for (Object rowObj : rowsObj) {
                 List<Object> row = (List<Object>) rowObj;
                 data.add(row);
             }
             return data;
         }
         return new List<List<Object>>();
    }
    
    public static void deleteRow(String sheetName, Integer rowNumber) {
        if (String.isEmpty(SPREADSHEET_ID)) throw new CalloutException('Spreadsheet ID is not set.');
        
        Integer sheetId = getSheetId(sheetName);
        if (sheetId == null) throw new CalloutException('Sheet not found: ' + sheetName);
        
        Integer startIndex = rowNumber - 1;
        Integer endIndex = startIndex + 1;
        
        String jsonBody = '{ "requests": [ { "deleteDimension": { "range": { "sheetId": ' + sheetId + ', "dimension": "ROWS", "startIndex": ' + startIndex + ', "endIndex": ' + endIndex + ' } } } ] }';
        
        HttpRequest req = new HttpRequest();
        req.setEndpoint(SHEETS_API_URL + SPREADSHEET_ID + ':batchUpdate');
        req.setMethod('POST');
        req.setHeader('Authorization', 'Bearer ' + getAccessToken());
        req.setHeader('Content-Type', 'application/json');
        req.setBody(jsonBody);
        
        Http http = new Http();
        HttpResponse res = http.send(req);
        
        if (res.getStatusCode() != 200) {
             System.debug('Error Deleting Row: ' + res.getBody());
             throw new CalloutException('Failed to delete row: ' + res.getBody());
        }
    }
    
    public static void createSheet(String sheetName) {
        if (String.isEmpty(SPREADSHEET_ID)) throw new CalloutException('Spreadsheet ID is not set.');
        if (getSheetId(sheetName) != null) return; // Already exists

        String jsonBody = '{ "requests": [ { "addSheet": { "properties": { "title": "' + sheetName + '" } } } ] }';
        
        HttpRequest req = new HttpRequest();
        req.setEndpoint(SHEETS_API_URL + SPREADSHEET_ID + ':batchUpdate');
        req.setMethod('POST');
        req.setHeader('Authorization', 'Bearer ' + getAccessToken());
        req.setHeader('Content-Type', 'application/json');
        req.setBody(jsonBody);
        
        Http http = new Http();
        HttpResponse res = http.send(req);
        
        if (res.getStatusCode() != 200) {
             System.debug('Error Creating Sheet: ' + res.getBody());
             throw new CalloutException('Failed to create sheet ' + sheetName + ': ' + res.getBody());
        }
    }
    
    private static Integer getSheetId(String sheetName) {
        HttpRequest req = new HttpRequest();
        req.setEndpoint(SHEETS_API_URL + SPREADSHEET_ID + '?fields=sheets.properties');
        req.setMethod('GET');
        req.setHeader('Authorization', 'Bearer ' + getAccessToken());
        
        Http http = new Http();
        HttpResponse res = http.send(req);
        
        if (res.getStatusCode() == 200) {
            Map<String, Object> root = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
             if (root.containsKey('sheets')) {
                List<Object> sheets = (List<Object>) root.get('sheets');
                for(Object s : sheets) {
                    Map<String, Object> sheet = (Map<String, Object>) s;
                    Map<String, Object> props = (Map<String, Object>) sheet.get('properties');
                    if ((String)props.get('title') == sheetName) {
                        return (Integer) props.get('sheetId');
                    }
                }
            }
        }
        return null;
    }

    // --- CACHING IMPLEMENTATION (CUSTOM OBJECT) ---
    
    public static Boolean isCacheValid(String sheetName) {
        List<GoogleSheetCache__c> caches = [SELECT Expiration__c FROM GoogleSheetCache__c WHERE Name = :sheetName ORDER BY CreatedDate DESC LIMIT 1];
        if (!caches.isEmpty() && caches[0].Expiration__c > System.now()) return true;
        return false;
    }

    private static String getCacheContent(String sheetName, Boolean avoidDml) {
        // Define TTL (Time To Live) in minutes
        Integer ttlMinutes = 0;
        if (sheetName == 'Interns' || sheetName == 'Attendance' || sheetName == 'Tasks' || 
            sheetName == 'Announcements' || sheetName == 'Leaves' || sheetName == 'DailyLogs') {
            ttlMinutes = 15;
        } else if (sheetName == 'Resources' || sheetName == 'Syllabus') {
            ttlMinutes = 360; 
        } else {
            return null;
        }

        // Query Custom Object (without sharing allows seeing records created by others)
        List<GoogleSheetCache__c> caches = [SELECT Id, JsonData__c, Expiration__c FROM GoogleSheetCache__c WHERE Name = :sheetName ORDER BY CreatedDate DESC LIMIT 1];
        
        if (!caches.isEmpty()) {
            GoogleSheetCache__c cache = caches[0];
            // Stale-While-Revalidate: If reading (avoidDml), return cache even if expired
            if (cache.Expiration__c > System.now() || avoidDml) {
                 if (cache.Expiration__c <= System.now()) System.debug('Serving Stale Cache for: ' + sheetName);
                 return cache.JsonData__c;
            } else {
                 return null;
            }
        }
        return null;
    }

    private static void saveCacheContent(String sheetName, String jsonData) {
        try {
            Set<String> cacheableSheets = new Set<String>{'Interns', 'Resources', 'Syllabus', 'Attendance', 'Tasks', 'Announcements', 'Leaves', 'DailyLogs'};
            if (!cacheableSheets.contains(sheetName)) return;

            // Delete OLD cache
            deleteOldCache(sheetName);

            // Insert NEW cache
            GoogleSheetCache__c cache = new GoogleSheetCache__c();
            cache.Name = sheetName;
            cache.JsonData__c = jsonData;
            
            // Calculate Expiration
            Integer ttlMinutes = 15; // Default for Interns, Attendance, Tasks, etc.
            if (sheetName == 'Resources' || sheetName == 'Syllabus') ttlMinutes = 360;
            cache.Expiration__c = System.now().addMinutes(ttlMinutes);
            
            insert cache;
        } catch (Exception e) {
            System.debug('Critical: Caching failed (Custom Object). ' + e.getMessage());
        }
    }

    private static void deleteOldCache(String sheetName) {
        List<GoogleSheetCache__c> oldCaches = [SELECT Id FROM GoogleSheetCache__c WHERE Name = :sheetName];
        if (!oldCaches.isEmpty()) {
            try { delete oldCaches; } catch(Exception e) {}
        }
    }

    // --- RETRY LOGIC (EXPONENTIAL BACKOFF) ---
    // Fix for 429 Quota Exceeded on Write Operations
    
    private static HttpResponse executeCalloutWithRetry(HttpRequest req) {
        Http http = new Http();
        HttpResponse res = null;
        Integer maxRetries = 3;
        Integer attempt = 0;
        Integer delayMs = 1000; // Start with 1 second

        while (attempt < maxRetries) {
            try {
                res = http.send(req);
                // If success or non-retryable error, return
                if (res.getStatusCode() != 429 && res.getStatusCode() != 503) {
                     return res; 
                }
            } catch (Exception e) {
                System.debug('Callout Failed (Attempt ' + attempt + '): ' + e.getMessage());
                if (attempt == maxRetries - 1) throw e;
            }
            
            // If 429 or 503, wait and retry
            attempt++;
            if (attempt < maxRetries) {
                 System.debug('429/503 Error. Retrying in ' + delayMs + 'ms...');
                 sleep(delayMs);
                 delayMs *= 2; // Exponential backoff: 1s, 2s
            }
        }
        return res;
    }

    private static void sleep(Integer ms) {
        Long start = System.currentTimeMillis();
        while (System.currentTimeMillis() < start + ms) {
            // Busy wait (Safe for short durations < 10s CPU limit)
        }
    }
}
