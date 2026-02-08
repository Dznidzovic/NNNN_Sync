/**
* @description	  : Component used for shared functionalities across lwc
* @author		  : Stefan Nidzovic
* @date		      : 01-11-2024
* @version		  : Initial Version
* @lastModified	  : 01-11-2024
* @lastModifiedBy : Stefan Nidzovic
* @modifications  : Implemented Show Toast message functionality
* @events		  : Show Toast Event
*/
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

/**
 * Utility function to show a toast message.
 * @param {Object} component - The component context (`this` from the caller component).
 * @param {String} title - The title of the toast message.
 * @param {String} message - The body message of the toast.
 * @param {String} variant - The type of toast (info, success, warning, error).
 * @param {String} mode - The display mode of the toast (dismissable, sticky, pester).
 */
export function showToast(component, title, message, variant = 'info', mode = 'dismissable') {
    const event = new ShowToastEvent({
        title: title,
        message: message,
        variant: variant,
        mode: mode
    });
    component.dispatchEvent(event);
}