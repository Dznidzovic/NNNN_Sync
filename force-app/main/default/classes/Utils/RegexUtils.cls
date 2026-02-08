/**
 *********************************************************
 * Apex Class Name    : RegexUtils
 * Created Date       : 03-31-2025
 * @description       : Utility class that contains methods for 
 *                     validation input using regular expressions
 * @author            : Uros Markovic
 * Modification Log:
 * Ver   Date         Author              Modification
 * 1.0   03-30-2025   Uros Markovic     Initial Version
 *********************************************************
**/
public class RegexUtils {
    
    /*
    *********************************************************
    @Method Name    : isValidNPN
    @description    : Validates that NPN contains only digits
    @author         : Uros Markovic
    @param          : npn - String value to validate
    @return         : Boolean - true if numeric, false otherwise
    ********************************************************
    */
    public static Boolean isValidNPN(String npn) {
        return Pattern.matches('^[0-9]+$', npn);
    }
}