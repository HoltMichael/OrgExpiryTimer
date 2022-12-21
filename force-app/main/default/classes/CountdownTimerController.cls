
/*
 * Copyright (c) 2018, salesforce.com, inc.
 * All rights reserved.
 * SPDX-License-Identifier: BSD-3-Clause
 * For full license text, see LICENSE.txt file in the repo root or https://opensource.org/licenses/BSD-3-Clause
 * 
 * Author: Michael Holt
 * Created Date: 04-Oct-2020
 * 
 */

public without sharing class CountdownTimerController { 
    public static final String JOBS_CANCELLED = 'Scheduled jobs cancelled, you will not receive an org expiry notification';
    public static final String JOBS_SCHEDULED = 'Successfully scheduled! Job Ids: ';
    private static Map<Integer, String> monthNamesByInteger = new Map<Integer, String>
    {1 => 'Jan', 2 => 'Feb', 3 => 'Mar', 4 => 'Apr', 5 => 'May', 6 => 'June', 7 => 'July', 8 => 'Aug', 9 => 'Sep', 10 => 'Oct', 11 => 'Nov', 12 => 'Dec'};


    @AuraEnabled
    public Static String getExpirationDate(){        
        Organization org = [SELECT TrialExpirationDate FROM Organization];
        return string.valueOf(org.TrialExpirationDate);
    }

    /*
        Set default notifications, 1 week and 1 day before org expiry
    */
    @AuraEnabled
    public static string setDefaults(){
        String response = 'Successfully scheduled default expiry notifications';
        try {
            PostInstallHandler.onInstall(null);
        } catch (Exception e) {
            response = e.getMessage();
        }
        return response;
    }

    /*
        Returns whether the scheduled job to fire the notifications is active
        If they are inactive, LWC prompts user to click "Activate" button
        for user to take ownership of existing jobs
    */
    @AuraEnabled(cacheable=true)
    public static boolean scheduledJobUserActive(){
        try{
            boolean cronByActiveUser = true;
            List<CronTrigger> crons = getCronsForOrgExpiry();
            //Get cron owners
            Set<Id> ownerIds = new Set<Id>();
            for(CronTrigger c : crons){
                ownerIds.add(c.ownerId);
            }
            List<User> owners = [SELECT isActive FROM User Where ID IN: ownerIds];

            //On install, the jobs will be scheduled by the Package License Manager user. This user does not have
            //permission to access the platform event and the job therefore fails. Fix by flagging this as an inactive user            
            if(crons.size() > 0 && owners.size() == 0){
                cronByActiveUser = false;
            }
            //Find out if Active
            for(User u : owners){
                if(!u.isActive){
                    cronByActiveUser = false;
                }
            }
            return cronByActiveUser;
        }catch(Exception e){
            System.debug(e.getMessage());
            return null;
        }
    }

    /*
        Cancels existing jobs and re-schedules as the current user
        Used to swap inactive users out from owning the scheduled jobs
        Typically post-PBO creation from template
    */
    @AuraEnabled
    public static String changeScheduledJobOwner(){
        try {
            List<CronTrigger> crons = getCronsForOrgExpiry();
            abortCurrentJobs(crons);
            Integer i = 0;
            for(CronTrigger c : crons){
                System.debug(c.NextFireTime);
                Date d = c.NextFireTime.date(); 
                i++;
                scheduleNewJob(d, i);
            }
            
            return 'Success';
        } catch (Exception e) {
            return e.getMessage();
        }
    }

    @AuraEnabled(cacheable=true)
    public static List<String> getScheduledNotifications(){
        try {
            List<CronTrigger> crons = getCronsForOrgExpiry();
            List<String> dates = new List<String>();
            for(CronTrigger ct : crons){
                List<String> exprs = ct.CronExpression.split(' ');
                String dateStr = exprs[3] +  ' ' + monthNamesByInteger.get(Integer.valueOf(exprs[4])) + ' ' + exprs[6];
                dates.add(dateStr);
            }

            return dates;
        } catch (Exception e) {
            System.debug(e.getMessage());
            return null;
        }
    }

    public static List<CronTrigger> getCronsForOrgExpiry(){
        return [SELECT Id, CronJobDetail.Id, CronJobDetail.Name, CronJobDetail.JobType, CronExpression, OwnerId, NextFireTime
                FROM CronTrigger 
                WHERE CronJobDetail.Name Like 'OrgExpiryNotification%' 
                Order By  CronJobDetail.Name Asc];
    }

    @AuraEnabled
    public static string abortThenSchedule(List<Date> dates){
        try {
            //Get all jobs scheduled by us
            List<CronTrigger> crons = getCronsForOrgExpiry();
            //Cancel all jobs scheduled by us
            abortCurrentJobs(crons);
            //Schedule new jobs
            return setNotificationDates(dates);
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled
    public static string setNotificationDates(List<Date> dates){
        try {
            String jobId = '';
            Integer nameSuffix = 1;
            if(dates != null){
                //Don't schedule the same job on the same day. 
                if(dates.size() > 1 && dates[0] == dates[1]){
                    dates[1] = null;
                }
                for(Date d : dates){
                    if(d != null){
                        jobId += scheduleNewJob(d, nameSuffix) + ' ';
                        nameSuffix++;
                    }
                }
            }

            if(jobId == ''){
                return JOBS_CANCELLED;
            }else{
                return JOBS_SCHEDULED + jobId;
            }
        } catch (Exception e) {
            System.debug(e.getMessage());
            return null;
        }
    }

    public static String scheduleNewJob(Date dt, Integer nameSuffix){
        PublishExpiryEvent scheduleEmail = new PublishExpiryEvent();
        String cronDate = '0 0 0 ' + dt.day() + ' ' + dt.month() +  ' ? ' + dt.year();
        return System.schedule('OrgExpiryNotification' + nameSuffix, cronDate, scheduleEmail);
    }
    
    public static void abortCurrentJobs(List<CronTrigger> jobs){
        for(CronTrigger job : jobs){
            System.abortJob(job.id);
        }
    }
}
