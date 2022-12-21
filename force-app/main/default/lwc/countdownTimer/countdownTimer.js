/*
 * Copyright (c) 2018, salesforce.com, inc.
 * All rights reserved.
 * SPDX-License-Identifier: BSD-3-Clause
 * For full license text, see LICENSE.txt file in the repo root or https://opensource.org/licenses/BSD-3-Clause
 */

import { LightningElement, track, wire } from 'lwc';
import getExpirationDate from '@salesforce/apex/CountdownTimerController.getExpirationDate';
import scheduledJobUserActive from '@salesforce/apex/CountdownTimerController.scheduledJobUserActive';
import changeScheduledJobOwner from '@salesforce/apex/CountdownTimerController.changeScheduledJobOwner';
import {ShowToastEvent} from 'lightning/platformShowToastEvent';
import getScheduledNotifications from '@salesforce/apex/CountdownTimerController.getScheduledNotifications';
import setDefaults from '@salesforce/apex/CountdownTimerController.setDefaults';



export default class CountdownTimer extends LightningElement {
    title = "Org Expiration"
    deadline;
    timeRemainingAsString;
    expanded = false;
    orgActive = false;
    cronsScheduledByInactiveUser = false;
    cmpVisible=true;
    noNotifications = false;
    
    
    @track daysBeforeExpiry;
    @track configureButton = "Configure Expiry Notifications";

    
    
    connectedCallback(){
        this.getOrgExpiration();
        setInterval(() => this.getTimeRemaining(), 100);
    }

    get expiresToday(){
        return this.daysBeforeExpiry < 1;
    }

    /*
        scheduledJobsOwnedByActiveUser
        If any of the cron jobs related to this app are owned by
        an inactive user, then flag this to the user and allow them
        to click a button to take ownership of the jobs
    */
    @wire(scheduledJobUserActive)
    scheduledJobsOwnedByActiveUser({error, data}){
        if(data === false){
            this.cronsScheduledByInactiveUser = true;
            this.fireToast('Org Expiry Notifier', 'Notifications currently owned by inactive user. Click \'Activate Notifications\' to fix.', 'error')
        }
        if(error){
            console.log(error);
        }
    }

    @wire(getScheduledNotifications)
    getScheduledNotifications({error, data}){
        console.log(data);
        console.log(error);
        if(data == ''){
            this.noNotifications = true;
            this.fireToast('Org Expiry Notifier','No org expiration notifications have been configured. Use \'Configure Expiry Notifications\' to fix this', 'warning');
        }
    }

    /* 
        setDefaults
        Sets notifications to the app defaults; 1 week and 1 day before org expiry
    */
    setDefaults(){
        setDefaults()
        .then((result) => {
            if(result.toLowerCase().includes("success")){
                this.fireToast('Success', result, 'success');
                noNotifications = true;
            }else{
                this.fireToast('Error', result, 'error');
            }
        })
        .catch((error) => {
            console.log(error);
        })
    }


    changeOwner(){
        changeScheduledJobOwner()
        .then((result) => {
            this.fireToast(result, '', 'success')
            this.cronsScheduledByInactiveUser = false;
        })
        .catch((error) => {
            this.fireToast('Error',error,'error')
        });
    }

    fireToast(t, m, v) {
        const evt = new ShowToastEvent({
            title: t,
            message: m,
            variant: v,
        });
        this.dispatchEvent(evt);
    }
    

    /*
        getOrgExpiration
        Retrieves the expiry date of the trial org.
        Can't use @Wire due to the need for record ID 
        Org ID will depend on customer.
    */
    getOrgExpiration(){
        getExpirationDate()
            .then((result) => {
                this.deadline = result;
                this.cmpVisible = true;
            })
            .catch((error) => {
                this.cmpVisible = false;
                console.log(error);
            })
    }

    getTimeRemaining(){
        const total = Date.parse(this.deadline) - Date.parse(new Date());
        if(total){
            this.orgActive = false;
            const seconds = Math.floor( (total/1000) % 60 );
            const minutes = Math.floor( (total/1000/60) % 60 );
            const hours = Math.floor( (total/(1000*60*60)) % 24 );
            const days = Math.floor( total/(1000*60*60*24) );     

            this.timeRemainingAsString =  days + ' days ' + hours + ' hours ' +  minutes + ' minutes'; //Removed seconds:// + seconds + ' seconds';
            
            var deadlineDate = new Date(this.deadline); 
            this.deadline = deadlineDate.toDateString();
            this.daysBeforeExpiry = days;
        }else{
            this.orgActive = true;
        }
    }

      invertExpanded(){
          this.expanded = !this.expanded;
          if(this.expanded){
            this.configureButton = "Collapse";
          }else{
            this.configureButton = "Configure Expiry Notifications";
          }
      }
}