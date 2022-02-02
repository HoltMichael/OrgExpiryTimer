@isTest
public with sharing class CountdownTimerController_Test {

    @isTest
    static void getExpirationDateTest(){
        Organization org = [SELECT TrialExpirationDate FROM Organization];
        String timeAsString = String.valueOf(org.TrialExpirationDate);
        Test.startTest();
            System.assertEquals(timeAsString, CountdownTimerController.getExpirationDate());
        Test.stopTest();
    }


    @isTest
    static void getScheduledNotificationsTest(){

        List<CronTrigger> crons = [SELECT Id, CronJobDetail.Id, CronJobDetail.Name, CronJobDetail.JobType, CronExpression
        FROM CronTrigger 
        WHERE CronJobDetail.Name Like 'OrgExpiryNotification%' 
        Order By  CronJobDetail.Name Asc];

        Test.startTest();
            List<String> strs = CountdownTimerController.getScheduledNotifications();
            System.assertEquals(strs.size(), crons.size());
            
            CountdownTimerController.setNotificationDates(null);
            strs = CountdownTimerController.getScheduledNotifications();
            System.assertEquals(strs.size(), 0);
        Test.stopTest();
    }

    @isTest
    static void getCronsForOrgExpiryTest(){
        List<CronTrigger> crons = [SELECT Id, CronJobDetail.Id, CronJobDetail.Name, CronJobDetail.JobType, CronExpression
        FROM CronTrigger 
        WHERE CronJobDetail.Name Like 'OrgExpiryNotification%' 
        Order By  CronJobDetail.Name Asc];

        Test.startTest();
            List<CronTrigger> theseCrons = CountdownTimerController.getCronsForOrgExpiry();
            System.assertEquals(theseCrons.size(), crons.size());
            
            CountdownTimerController.setNotificationDates(null);
            theseCrons = CountdownTimerController.getCronsForOrgExpiry();
            System.assertEquals(theseCrons.size(), 0);
            CountdownTimerController.setNotificationDates(new List<Date>{System.today().addDays(1)});
        Test.stopTest();
    }

    @isTest
    static void scheduleNewJobTest(){
        PostInstallHandler.onInstall(null);
        Test.startTest();
            System.assertEquals(15, CountdownTimerController.scheduleNewJob(System.today().addDays(1), 10).length());
        Test.stopTest();
    }

    @isTest
    static void abortCurrentJobsTest(){

        List<CronTrigger> crons = [SELECT Id, CronJobDetail.Id, CronJobDetail.Name, CronJobDetail.JobType, CronExpression
        FROM CronTrigger 
        WHERE CronJobDetail.Name Like 'OrgExpiryNotification%' 
        Order By  CronJobDetail.Name Asc];

        Test.startTest();
            CountdownTimerController.abortCurrentJobs(crons);
            List<CronTrigger> theseCrons = CountdownTimerController.getCronsForOrgExpiry();
            System.assertEquals(theseCrons.size(), 0);
        Test.stopTest();
    }

    @isTest
    static void scheduledJobUserActiveTest(){
        User u1 = new User(
                            ProfileId = [SELECT Id FROM Profile WHERE Name = 'System Administrator'].Id,
                            FirstName = 'MichaelXTest001',
                            LastName = 'one',
                            Email = 'user0001@orgexpiry.com',
                            Username = 'michael.holt.test.001@org.expiry' + System.currentTimeMillis(),
                            CompanyName = 'TEST',
                            Title = 'title',
                            Alias = 'alias',
                            TimeZoneSidKey = 'Europe/London',
                            EmailEncodingKey = 'UTF-8',
                            LanguageLocaleKey = 'en_US',
                            LocaleSidKey = 'en_US');
        insert u1;
        System.runAs(u1){
            CountdownTimerController.scheduleNewJob(System.today().addDays(1), 10);
        }

        System.assertEquals(CountdownTimerController.scheduledJobUserActive(), true); 
        u1.isActive = false;
        update u1;

        Test.startTest();
            System.assertEquals(CountdownTimerController.scheduledJobUserActive(), false); 
        Test.stopTest();
    
    }

    @isTest
    static void changeScheduledJobOwnerTest(){
        User u1 = new User(
            ProfileId = [SELECT Id FROM Profile WHERE Name = 'System Administrator'].Id,
            FirstName = 'MichaelXTest001',
            LastName = 'one',
            Email = 'user0001@orgexpiry.com',
            Username = 'michael.holt.test.001@org.expiry' + System.currentTimeMillis(),
            CompanyName = 'TEST',
            Title = 'title',
            Alias = 'alias',
            TimeZoneSidKey = 'Europe/London',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US');
        insert u1;

        User u2 = new User(
            ProfileId = [SELECT Id FROM Profile WHERE Name = 'System Administrator'].Id,
            FirstName = 'MichaelXTest002',
            LastName = 'one',
            Email = 'user000@orgexpiry.com',
            Username = 'michael.holt.test.002@org.expiry' + System.currentTimeMillis(),
            CompanyName = 'TEST',
            Title = 'title',
            Alias = 'alias',
            TimeZoneSidKey = 'Europe/London',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US');
        insert u2;

        System.runAs(u1){
            CountdownTimerController.scheduleNewJob(System.today().addDays(1), 10);
        }

        List<CronTrigger> crons = CountdownTimerController.getCronsForOrgExpiry();
        System.assertEquals(crons[0].ownerId, u1.Id);

        System.runAs(u2){
            CountdownTimerController.changeScheduledJobOwner();
        }

        crons = CountdownTimerController.getCronsForOrgExpiry();
        Test.startTest();
            System.assertEquals(crons[0].ownerId, u2.Id);
        Test.stopTest();

    }

    @isTest
    static void abortThenScheduleTest(){
        Date myDate = System.today() + 1;
        List<Date> dateList = new List<Date>();
        dateList.add(myDate);
        CountdownTimerController.abortThenSchedule(dateList);
        
        List<CronTrigger> crons = CountdownTimerController.getCronsForOrgExpiry();

        Test.startTest();
            System.assertEquals(crons[0].NextFireTime.date(), System.today()+1);
        Test.stopTest();
    }


}
