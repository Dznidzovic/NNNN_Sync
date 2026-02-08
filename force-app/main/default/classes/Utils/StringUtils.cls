/**
 *********************************************************
 * Apex Class Name    : StringUtils
 * Created Date       : 04-08-2025
 * @description       : Utility class for simple string transformations
 * @author            : Stefan Nidzovic
 * Modification Log:
 * Ver   Date         Author                   Modification
 * 1.0   04-08-2025   Stefan Nidzovic          Initial Version
 *********************************************************
 **/
public with sharing class StringUtils {

    /**
     *********************************************************
     * @methodName      : swapCharacters
     * @description     : Replaces all occurrences of a target character with a replacement character
     *                    in the input string.
     * @param input     : The original string where replacements will occur.
     * @param target    : The character to be replaced.
     * @param replacement : The character to insert in place of the target.
     * @return          : A new string with all target characters replaced, or null if input is null.
     *********************************************************
     **/
    public static String swapCharacters(String input, String target, String replacement) {
        if (input == null || target == null || replacement == null) {
            return null;
        }

        return input.replace(target, replacement);
    }

    /**
     *********************************************************
     * @methodName      : convertToISODateFormat
     * @description     : Converts a legacy date string from 'MM-dd-yyyy' format to 'yyyy-MM-dd' ISO format.
     *                    This format is used in XML responses such as <AsOfDate>2024-04-11</AsOfDate>.
     * @param inputDate : The date string in 'MM-dd-yyyy' format.
     * @return          : A date string in 'yyyy-MM-dd' format or null if the input is invalid.
     *********************************************************
     **/
    public static String convertToISODateFormat(String inputDate) {
        if (String.isBlank(inputDate)) {
            return null;
        }

        List<String> parts = inputDate.split('-');
        if (parts.size() != 3) {
            return null;
        }

        String month = parts[0];
        String day = parts[1];
        String year = parts[2];

        return year + '-' + month + '-' + day;
    }

    /**
     *********************************************************
    * @methodName      : isValidEmail
    * @description     : Validates an email address string against a regex pattern.
    *                    Ensures a single well-formed email (no commas/semicolons).
    * @param email     : Email address string to validate.
    * @return          : TRUE if the email is syntactically valid; FALSE otherwise.
    *********************************************************
    **/
    public static Boolean isValidEmail(String email) {
        if (String.isBlank(email)) return false;

        // Reject multiple emails in one string (commas/semicolons)
        if (email.contains(',') || email.contains(';')) return false;

        // Commonly accepted email regex (local@domain.tld)
        String emailRegex = '^[A-Za-z0-9._%+\\-]+@[A-Za-z0-9\\-]+(\\.[A-Za-z0-9\\-]+)*\\.[A-Za-z]{2,}$';

        Pattern pattern = Pattern.compile(emailRegex);
        Matcher matcher = pattern.matcher(email.trim());

        return matcher.matches();
    }

    /**
     *********************************************************
     * @methodName      : cleanString
     * @description     : Removes specified patterns from a string.
     * @param input     : The string to be cleaned.
     * @param patterns  : List of regex patterns or literal strings to be removed.
     * @return          : A clean string with all specified patterns removed.
     *********************************************************
     **/
    public static String cleanString(String input, List<String> patterns) {
        if (input == null) {
            return '';
        }
        
        if (patterns == null || patterns.isEmpty()) {
            return input;
        }
        
        String result = input;
        
        for (String pattern : patterns) {
            if (pattern != null) {
                result = result.replaceAll(pattern, '');
            }
        }
        
        return result;
    }

    /**
     *********************************************************
     * @methodName      : safeParseNullString
     * @description     : Safely handles null String values by returning an empty string
     *                    when the input is null, preventing NullPointerExceptions.
     * @param input     : The string value to be safely parsed.
     * @return          : Empty string if input is null, otherwise returns the input string.
     *********************************************************
     **/
    public static String safeParseNullString(String input) {
        return input != null ? input : '';
    }

    /**
     *********************************************************
     * @methodName      : safeParseFromDate
     * @description     : Safely converts a date string to String representation, returning
     *                    an empty string when input is null.
     * @param input     : The date string to be safely parsed and converted.
     * @return          : Empty string if input is null, otherwise returns the String representation.
     *********************************************************
     **/
    public static String safeParseFromDate(Date input) {
        return input != null ? String.valueOf(input) : '';
    }

    /**
     *********************************************************
     * @methodName      : formatNIPREntityInfoNumber
     * @description     : Converts a U.S. phone number from "NNN-NNN-NNNN"
     *                    into "+1-NNN-NNN-NNNN" format, preserving dashes.
     * @param phoneNum  : The raw phone number string in format "NNN-NNN-NNNN".
     * @return          : Formatted phone string with +1- prefix, or null if input is invalid.
     *********************************************************
     **/
    public static String formatNIPREntityInfoNumber(String phoneNum) {
        return !String.isBlank(phoneNum) ? '+1-' + phoneNum : null;
    }

    /**
     *********************************************************
     * @methodName      : formatNIPRPDBAlertNumber
     * @description     : Adds a dash before the last 4 digits of a U.S. phone number string.
     *                    For example: "+1-973-8391224" → "+1-973-839-1224"
     * @param phoneNum  : Raw phone number in format "+1-XXX-XXXXXXX"
     * @return          : Phone string with a dash before the last 4 digits, or null if input is invalid.
     *********************************************************
     **/
    public static String formatNIPRPDBAlertNumber(String phoneNum) {
        if (String.isBlank(phoneNum)) return null;

        if (phoneNum.length() <= 4) return phoneNum;

        String prefix = phoneNum.substring(0, phoneNum.length() - 4);
        String lastFour = phoneNum.substring(phoneNum.length() - 4);

        return prefix + '-' + lastFour;
    }

    /**
     *********************************************************
     * @methodName      : truncateField
     * @description     : Utility method to truncate string fields to fit SF limits
     * @param value     : The string to truncate
     * @param maxLength : Maximum length allowed
     * @return          : String - Truncated string
     *********************************************************
     **/
    public static String truncateField(String value, Integer maxLength) {
        if (value == null) {
            return null;
        }
        return value.length() > maxLength ? value.substring(0, maxLength) : value;
    }
}