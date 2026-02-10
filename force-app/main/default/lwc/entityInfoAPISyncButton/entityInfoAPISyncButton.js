/**
* @description	  : Component that calls an apex controller to process NPN data asynchronously
* @author		  : Dev4Clouds
* @date		      : 04-21-2025
* @version		  : 2.3 - In-memory click protection
* @lastModified	  : 12-26-2025
* @lastModifiedBy : Dev4Clouds
* @modifications  : Added protection against spam clicking using in-memory tracking,
*                   shows confirmation if synced today based on database value.
* @usage		  : Component to be used as a quick action button on d4c_Entity__c records
* @params		  : recordId - Id of the d4c_Entity__c record
* @events		  :
* @limitations	  : Component does not display any UI elements
*/
import { LightningElement, api, wire } from 'lwc';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';
import LightningConfirm from 'lightning/confirm';
import { showToast } from 'c/utils';
import processEntityInfoAPI from '@salesforce/apex/EntityInfoApiController.processNPN';
import PRODUCER_NPN from "@salesforce/schema/d4c_Entity__c.d4c_NPN__c";
import PRODUCER_LAST_SYNC from "@salesforce/schema/d4c_Entity__c.d4c_LastNIPRSync__c";

const ONE_MINUTE_MS = 60 * 1000;

// Track last click time per recordId (persists across component instances in same session)
const lastClickTimeByRecord = new Map();

export default class EntityInfoAPISyncButton extends LightningElement {
    @api
    recordId;
    npn;
    lastSyncTime;

    /**
    * Fetches NPN and LastNIPRSync fields based on recordId
    */
    @wire(getRecord, { recordId: '$recordId', fields: [PRODUCER_NPN, PRODUCER_LAST_SYNC] })
    wiredRecord({ error, data }) {
        if (data) {
            this.npn = getFieldValue(data, PRODUCER_NPN);
            this.lastSyncTime = getFieldValue(data, PRODUCER_LAST_SYNC);
        } else if (error) {
            console.error('Error loading entity record:', error);
        }
    }

    @api
    async invoke() {
        try {
            if (!this.npn) {
                showToast(
                    this,
                    'Missing NPN',
                    'No NPN found for this entity. Please add an NPN before syncing.',
                    'warning'
                );
                return;
            }

            // Check sync protection before proceeding
            const canProceed = await this.checkSyncProtection();
            if (!canProceed) {
                return;
            }

            // Record this click time BEFORE starting the sync
            lastClickTimeByRecord.set(this.recordId, Date.now());

            await this.processNPN(this.npn);
        } catch (error) {
            console.error('Error in invoke:', error);
            showToast(
                this,
                'Error',
                'An unexpected error occurred. Please try again.',
                'error'
            );
        }
    }

    /**
    * Checks if sync should be allowed based on:
    * 1. In-memory click tracking (prevents spam clicks)
    * 2. Database last sync time (shows confirmation if synced today)
    * @returns {boolean} - true if sync can proceed, false otherwise
    */
    async checkSyncProtection() {
        const now = Date.now();

        // Check in-memory click tracking first (prevents spam)
        const lastClickTime = lastClickTimeByRecord.get(this.recordId);
        if (lastClickTime) {
            const timeSinceLastClick = now - lastClickTime;
            if (timeSinceLastClick < ONE_MINUTE_MS) {
                const secondsRemaining = Math.ceil((ONE_MINUTE_MS - timeSinceLastClick) / 1000);
                showToast(
                    this,
                    'Sync In Progress',
                    `A sync was just started. Please wait ${secondsRemaining} seconds before syncing again.`,
                    'warning'
                );
                return false;
            }
        }

        // Check database last sync time for "synced today" confirmation
        if (this.lastSyncTime) {
            const lastSync = new Date(this.lastSyncTime);
            const nowDate = new Date();

            if (this.isSameDay(lastSync, nowDate)) {
                const syncTimeFormatted = this.formatTime(lastSync);
                const result = await LightningConfirm.open({
                    message: `This entity was already synced today at ${syncTimeFormatted}. Are you sure you want to sync again?`,
                    label: 'Confirm Sync',
                    theme: 'warning'
                });
                return result;
            }
        }

        return true;
    }

    /**
    * Checks if two dates are on the same day
    */
    isSameDay(date1, date2) {
        return date1.getFullYear() === date2.getFullYear() &&
               date1.getMonth() === date2.getMonth() &&
               date1.getDate() === date2.getDate();
    }

    /**
    * Formats a date to display time in user's locale
    */
    formatTime(date) {
        return date.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
    }

    /**
    * Method calls the apex controller to enqueue the batch job
    * Shows info toast immediately - no waiting for results
    * @param {string} npn - NPN of the entity to process
    */
    async processNPN(npn) {
        try {
            await processEntityInfoAPI({ npn: npn });

            // Show info toast - processing happens in background
            showToast(
                this,
                'Sync Started',
                `NIPR sync initiated for NPN ${npn}. Refresh the page shortly to see results (typically a few seconds, up to a minute for large records).`,
                'info'
            );

        } catch (error) {
            const errorMessage = error.body?.message || 'An error occurred while starting the sync process.';
            console.error('Error starting NPN sync:', errorMessage);

            showToast(
                this,
                'Error',
                errorMessage,
                'error'
            );
        }
    }
}