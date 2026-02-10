/**
 *********************************************************
 * Apex Class Name    : AddNPNToSubscriptionDTO
 * Created Date       : 04-23-2025
 * @description       : Data Transfer Object (DTO) for representing the response from 
 *                      NIPR API for adding NPNs to a subscription.
 * @author            : Dev4Clouds
 * Modification Log:
 * Ver   Date         Author             Modification
 * 1.0   04-23-2025   Dev4Clouds    Initial Version
 * 1.1   04-23-2025   Dev4Clouds    Fixed structure to correctly represent actual API response
 *********************************************************
 **/
public class AddNPNToSubscriptionDTO {
    // Non XML related elements for response processing
    public Boolean isSuccess;
    public String errorMessage;
    
    // Root-level elements based on the SOAP response
    public TargetResultsData targetResultsData;
    
    /**
     * Container for the results of adding targets (NPNs) to a subscription
     */
    public class TargetResultsData {
        // List of valid NPNs successfully added to subscription
        public List<String> validNPNs;
        
        // List of invalid inputs with reasons for failure
        public List<InvalidInputItem> invalidInputs;
    }
    
    /**
     * Container for invalid input items with reasons for failure
     */
    public class InvalidInputItem {
        public String input;
        public String invalidReason;
    }
}