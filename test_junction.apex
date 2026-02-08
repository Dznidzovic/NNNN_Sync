// First delete any existing License-Product junctions for these licenses and this product
List<Id> licenseIds = new List<Id>{
    'a02am00001n50qkAAA', 'a02am00001n5fCsAAI', 'a02am00001n602lAAA', 
    'a02am00001n65zgAAA', 'a02am00001n5iY8AAI', 'a02am00001n5nSZAAY', 
    'a02am00001n6Ev6AAE', 'a02am00001n4kH8AAI'
};
Id productId = 'a0Cam00008rh4mTEAQ';

List<ht_License_Insurance_Product__c> existingJunctions = [
    SELECT Id FROM ht_License_Insurance_Product__c 
    WHERE ht_License__c IN :licenseIds AND ht_InsuranceProduct__c = :productId
];
if (!existingJunctions.isEmpty()) {
    delete existingJunctions;
    System.debug('Deleted ' + existingJunctions.size() + ' existing License-Product junctions');
}

// Now create the junction
ht_Insurance_Product_LOA_Mapping__c junction = new ht_Insurance_Product_LOA_Mapping__c(
    ht_LOAMapping__c = 'a09am00000d0sUiAAI',
    ht_InsuranceProduct__c = productId
);
insert junction;
System.debug('Created junction: ' + junction.Id);
