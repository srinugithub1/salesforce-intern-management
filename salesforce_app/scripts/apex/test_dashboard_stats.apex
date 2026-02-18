String token = 'test-token';
System.debug('--- Task Stats ---');
System.debug(AdminController.getTaskStats(token));

System.debug('--- Task Priority Stats ---');
System.debug(AdminController.getTaskPriorityStats(token));

System.debug('--- Leave Stats ---');
System.debug(AdminController.getLeaveStats(token));

System.debug('--- Upcoming Deadlines ---');
List<Map<String, Object>> deadlines = AdminController.getUpcomingDeadlines(token);
System.debug('Count: ' + deadlines.size());
if(deadlines.size() > 0) System.debug('First: ' + deadlines[0]);

System.debug('--- Top Interns ---');
List<Map<String, Object>> topInterns = AdminController.getTopInterns(token);
System.debug('Count: ' + topInterns.size());
if(topInterns.size() > 0) System.debug('First: ' + topInterns[0]);

System.debug('--- Recent Activities ---');
List<AdminController.ActivityWrapper> activities = AdminController.getRecentActivities(token);
System.debug('Count: ' + activities.size());
if(activities.size() > 0) System.debug('First: ' + activities[0]);
