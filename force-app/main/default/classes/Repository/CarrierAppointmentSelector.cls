/**
 *********************************************************
 * Apex Class Name    : CarrierAppointmentSelector
 * Created Date       : 03-30-2025
 * @description       : Selector class holding all the queries used for ht_CarrierAppointment__c object
 * @author            : Stefan Nidzovic
 * Modification Log:
 * Ver   Date         Author                   Modification
 * 1.0   03-30-2025   Stefan Nidzovic          Initial Version
 *********************************************************
 **/
public with sharing class CarrierAppointmentSelector {

    /**
     * *******************************************************
     * @Method Name    : getCarrierAppointmentsByProducerNpn
     * @description    : Returns list of ht_Carrier by ht_NPN__c of ht_Producer__C object field
     * @param          : npns - Set of unique NPN values
     * @return         : List<ht_CarrierAppointment__c> - list of Producer records
     *******************************************************
     **/
    public List<ht_CarrierAppointment__c> getCarrierAppointmentsByProducerNpn(Set<String> npns) {
        return [
            SELECT
                Id,
                ht_UniqueIdentifier__c,
                ht_Producer__r.ht_NPN__c
            FROM
                ht_CarrierAppointment__c
            WHERE
                ht_Producer__r.ht_NPN__c IN :npns
        ];
    }

    /**
     * *******************************************************
     * @Method Name    : getCarrierAppointmentsByProducerNpnAndStates
     * @description    : Returns list of ht_CarrierAppointment__c by ht_NPN__c and ht_StateOrProvinceCode__c
     *                   Used for deletion logic to only query appointments for producer+state combinations
     *                   that have data in the NIPR payload
     * @param          : npns - Set of unique NPN values
     * @param          : states - Set of state/province codes
     * @return         : List<ht_CarrierAppointment__c> - list of Carrier Appointment records
     *******************************************************
     **/
    public List<ht_CarrierAppointment__c> getCarrierAppointmentsByProducerNpnAndStates(Set<String> npns, Set<String> states) {
        return [
            SELECT
                Id,
                ht_UniqueIdentifier__c,
                ht_Producer__r.ht_NPN__c,
                ht_StateOrProvinceCode__c
            FROM
                ht_CarrierAppointment__c
            WHERE
                ht_Producer__r.ht_NPN__c IN :npns
                AND ht_StateOrProvinceCode__c IN :states
        ];
    }
}