/**
 * @description       : 
 * @author            : Dev4Clouds
 * @group             : 
 * @last modified on  : 02-10-2026
 * @last modified by  : Stefan Nidzovic
**/
public with sharing class DateUtils {
    /**
     *********************************************************
     * @methodName      : safeParseDate
     * @description     : Helper method to parse date strings into Date objects.
     * @param dateStr   : String date value in MM/dd/yyyy format.
     * @return          : Parsed Date or null.
     *********************************************************
     **/
    public static Date safeParseDateFromString(String dateStr) {
        if (String.isNotBlank(dateStr)) {
            try {
                return Date.valueOf(dateStr);
            } catch (Exception e) {
                System.debug('Failed to parse date: ' + dateStr);
            }
        }
        return null;
    }
}