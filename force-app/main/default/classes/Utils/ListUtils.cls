/**
 *********************************************************
 * Apex Class Name    : ListUtils
 * Created Date       : 03-30-2025
 * @description       : Utility class to provide sublist-style slicing functionality 
 *                      for Apex Lists. Apex does not natively support subList, so this 
 *                      provides a reusable alternative. Overloaded methods support 
 *                      List<Id> and List<SObject>.
 * @author            : Stefan Nidzovic
 * Modification Log:
 * Ver   Date         Author              Modification
 * 1.0   03-30-2025   Stefan Nidzovic     Initial Version
 *********************************************************
**/
public class ListUtils {

    /**
     * @methodName       : slice
     * @description      : Returns a slice of the given List<Id> from start (inclusive) to end (exclusive)
     * @param originalList : List<Id> to be sliced
     * @param fromIndex     : Starting index (inclusive)
     * @param toIndex       : Ending index (exclusive)
     * @return              : Sliced List<Id>
     */
    public static List<Id> slice(List<Id> originalList, Integer fromIndex, Integer toIndex) {
        List<Id> sliced = new List<Id>();

        for (Integer i = fromIndex; i < toIndex && i < originalList.size(); i++) {
            sliced.add(originalList[i]);
        }

        return sliced;
    }

    /**
     * @methodName       : slice
     * @description      : Returns a slice of the given List<SObject> from start (inclusive) to end (exclusive)
     * @param originalList : List<SObject> to be sliced
     * @param fromIndex     : Starting index (inclusive)
     * @param toIndex       : Ending index (exclusive)
     * @return              : Sliced List<SObject>
     */
    public static List<SObject> slice(List<SObject> originalList, Integer fromIndex, Integer toIndex) {
        List<SObject> sliced = new List<SObject>();

        for (Integer i = fromIndex; i < toIndex && i < originalList.size(); i++) {
            sliced.add(originalList[i]);
        }

        return sliced;
    }

    /**
     * @methodName       : deduplicateByField
     * @description      : Removes duplicate records in-place from a List<SObject> based on a unique external ID field.
     *                     Only the first occurrence of each unique key is retained.
     * @param records     : The original list of SObjects (will be modified in-place)
     * @param externalIdField : The API name of the field to use for deduplication (e.g. 'd4c_UniqueIdentifier__c')
    */
    public static void deduplicateByField(List<SObject> records, String externalIdField) {
        if (records == null || records.isEmpty()) return;
        
        Set<String> seen = new Set<String>();
        for (Integer i = records.size() - 1; i >= 0; i--) {
            SObject record = records[i];
            Object keyVal = record.get(externalIdField);

            // Treat null keys as duplicate-prone
            String key = keyVal == null ? '__NULL__' : String.valueOf(keyVal);

            if (seen.contains(key)) {
                records.remove(i);
            } else {
                seen.add(key);
            }
        }
    }
}