/**
 *********************************************************
 * Apex Class Name    : CarrierAppointmentSelector
 * Created Date       : 03-30-2025
 * @description       : Selector class holding all the queries used for d4c_CarrierAppointment__c object
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
     * @description    : Returns list of d4c_Carrier by d4c_NPN__c of d4c_Entity__c object field
     * @param          : npns - Set of unique NPN values
     * @return         : List<d4c_CarrierAppointment__c> - list of Producer records
     *******************************************************
     **/
    public List<d4c_CarrierAppointment__c> getCarrierAppointmentsByProducerNpn(Set<String> npns) {
        return [
            SELECT
                Id,
                d4c_UniqueIdentifier__c,
                d4c_Entity__r.d4c_NPN__c
            FROM
                d4c_CarrierAppointment__c
            WHERE
                d4c_Entity__r.d4c_NPN__c IN :npns
        ];
    }

    /**
     * *******************************************************
     * @Method Name    : getCarrierAppointmentsByProducerNpnAndStates
     * @description    : Returns list of d4c_CarrierAppointment__c by d4c_NPN__c and d4c_StateOrProvinceCode__c
     *                   Used for deletion logic to only query appointments for producer+state combinations
     *                   that have data in the NIPR payload
     * @param          : npns - Set of unique NPN values
     * @param          : states - Set of state/province codes
     * @return         : List<d4c_CarrierAppointment__c> - list of Carrier Appointment records
     *******************************************************
     **/
    public List<d4c_CarrierAppointment__c> getCarrierAppointmentsByProducerNpnAndStates(Set<String> npns, Set<String> states) {
        return [
            SELECT
                Id,
                d4c_UniqueIdentifier__c,
                d4c_Entity__r.d4c_NPN__c,
                d4c_StateOrProvinceCode__c
            FROM
                d4c_CarrierAppointment__c
            WHERE
                d4c_Entity__r.d4c_NPN__c IN :npns
                AND d4c_StateOrProvinceCode__c IN :states
        ];
    }
}