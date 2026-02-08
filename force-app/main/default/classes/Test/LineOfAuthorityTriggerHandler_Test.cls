/**
 *********************************************************
 * Apex Class Name    : LineOfAuthorityTriggerHandler_Test
 * Created Date       : 2025-12-13
 * @description       : Test class for LineOfAuthorityTriggerHandler
 *                      Tests LOA to Insurance Product Mapping matching logic
 *                      and batch job enqueueing for junction management.
 * @author            : Stefan Nidzovic
 * Modification Log:
 * Ver   Date         Author         Modification
 * 1.0   2025-12-13   Stefan Nidzovic         Initial Version
 *********************************************************
 */
@isTest
private class LineOfAuthorityTriggerHandler_Test {

    private static final String TEST_STATE = 'CA';
    private static final String TEST_LOA_CODE = '935';
    private static final String TEST_LOA_DESCRIPTION = 'Accident & Health or Sickness';

    @TestSetup
    static void setupTestData() {
        // Disable trigger during setup to insert base data
        LineOfAuthorityTriggerHandler.triggerDisabled = true;

        // Create Producer
        ht_Producer__c producer = TestDataFactory.createProducer('TEST123456');
        insert producer;

        // Create License
        ht_License__c license = new ht_License__c(
            ht_LicenseNumber__c = 'LIC123456',
            ht_Producer__c = producer.Id,
            ht_StateOrProvinceCode__c = TEST_STATE,
            ht_LicenseClassCode__c = '3',
            ht_UniqueIdentifier__c = 'LIC123456CA3'
        );
        insert license;

        LineOfAuthorityTriggerHandler.triggerDisabled = false;
    }

    // ============================================================
    // BEFORE INSERT TESTS
    // ============================================================

    @isTest
    static void beforeInsert_matchesLoaToMappingWhenKeyExists() {
        // Arrange: Create mapping that LOA should match
        ht_LOA_Insurance_Product_Mapping__c mapping = TestDataFactory.createLOAInsuranceProductMapping(
            TEST_STATE, TEST_LOA_CODE, TEST_LOA_DESCRIPTION, true
        );

        ht_License__c license = [SELECT Id FROM ht_License__c LIMIT 1];

        // Reset test state

        // Act: Insert LOA with matching state/code/description
        Test.startTest();
        ht_LineOfAuthority__c loa = TestDataFactory.createLOAForMatching(
            license.Id, TEST_STATE, TEST_LOA_CODE, TEST_LOA_DESCRIPTION, true
        );
        Test.stopTest();

        // Assert: LOA should have mapping lookup populated
        ht_LineOfAuthority__c insertedLoa = [
            SELECT Id, ht_LOAMapping__c
            FROM ht_LineOfAuthority__c
            WHERE Id = :loa.Id
        ];
        System.assertEquals(mapping.Id, insertedLoa.ht_LOAMapping__c,
            'LOA should be matched to mapping with same state/code/description');
    }

    @isTest
    static void beforeInsert_setsNullWhenNoMappingExists() {
        // Arrange: No mapping exists for this combination
        ht_License__c license = [SELECT Id FROM ht_License__c LIMIT 1];

        // Reset test state

        // Act: Insert LOA with no matching mapping
        Test.startTest();
        ht_LineOfAuthority__c loa = TestDataFactory.createLOAForMatching(
            license.Id, 'XX', '999', 'Non-existent LOA Type', true
        );
        Test.stopTest();

        // Assert: LOA should have null mapping
        ht_LineOfAuthority__c insertedLoa = [
            SELECT Id, ht_LOAMapping__c
            FROM ht_LineOfAuthority__c
            WHERE Id = :loa.Id
        ];
        System.assertEquals(null, insertedLoa.ht_LOAMapping__c,
            'LOA should have null mapping when no match exists');
    }

    @isTest
    static void beforeInsert_handlesNullFieldsGracefully() {
        // Arrange
        ht_License__c license = [SELECT Id FROM ht_License__c LIMIT 1];

        // Reset test state

        // Act: Insert LOA with null state/code/description - should not throw exception
        Test.startTest();
        ht_LineOfAuthority__c loa = new ht_LineOfAuthority__c(
            ht_License__c = license.Id,
            ht_StateOrProvinceCode__c = null,
            ht_LineOfAuthorityCode__c = null,
            ht_LineOfAuthorityDescription__c = null,
            ht_UniqueIdentifier__c = 'NULLTEST' + System.currentTimeMillis()
        );
        insert loa;
        Test.stopTest();

        // Assert: LOA inserted successfully with null mapping
        ht_LineOfAuthority__c insertedLoa = [
            SELECT Id, ht_LOAMapping__c
            FROM ht_LineOfAuthority__c
            WHERE Id = :loa.Id
        ];
        System.assertEquals(null, insertedLoa.ht_LOAMapping__c,
            'LOA with null fields should have null mapping');
    }

    @isTest
    static void beforeInsert_handlesBulkInsert() {
        // Arrange: Create 200 mappings
        List<ht_LOA_Insurance_Product_Mapping__c> mappings = new List<ht_LOA_Insurance_Product_Mapping__c>();
        for (Integer i = 0; i < 200; i++) {
            mappings.add(new ht_LOA_Insurance_Product_Mapping__c(
                ht_StateOrProvinceCode__c = TEST_STATE,
                ht_LineOfAuthorityCode__c = String.valueOf(i),
                ht_LineOfAuthorityDescription__c = 'Test LOA ' + i,
                ht_UniqueIdentifier__c = TEST_STATE + '-' + i + '-Test LOA ' + i
            ));
        }
        insert mappings;

        ht_License__c license = [SELECT Id FROM ht_License__c LIMIT 1];

        // Reset test state

        // Act: Insert 200 LOAs with matching keys
        List<ht_LineOfAuthority__c> loas = new List<ht_LineOfAuthority__c>();
        for (Integer i = 0; i < 200; i++) {
            loas.add(new ht_LineOfAuthority__c(
                ht_License__c = license.Id,
                ht_StateOrProvinceCode__c = TEST_STATE,
                ht_LineOfAuthorityCode__c = String.valueOf(i),
                ht_LineOfAuthorityDescription__c = 'Test LOA ' + i,
                ht_UniqueIdentifier__c = 'BULK' + i + System.currentTimeMillis()
            ));
        }

        Test.startTest();
        insert loas;
        Test.stopTest();

        // Assert: All LOAs should have correct mapping
        List<ht_LineOfAuthority__c> insertedLoas = [
            SELECT Id, ht_LOAMapping__c, ht_LineOfAuthorityCode__c
            FROM ht_LineOfAuthority__c
            WHERE Id IN :loas
        ];

        Map<String, Id> codeToMappingId = new Map<String, Id>();
        for (ht_LOA_Insurance_Product_Mapping__c m : mappings) {
            codeToMappingId.put(m.ht_LineOfAuthorityCode__c, m.Id);
        }

        for (ht_LineOfAuthority__c insertedLoa : insertedLoas) {
            Id expectedMappingId = codeToMappingId.get(insertedLoa.ht_LineOfAuthorityCode__c);
            System.assertEquals(expectedMappingId, insertedLoa.ht_LOAMapping__c,
                'LOA with code ' + insertedLoa.ht_LineOfAuthorityCode__c + ' should have correct mapping');
        }
    }

    // ============================================================
    // BEFORE UPDATE TESTS
    // ============================================================

    @isTest
    static void beforeUpdate_rematchesWhenFieldsChange() {
        // Arrange: Create two mappings
        ht_LOA_Insurance_Product_Mapping__c mappingA = TestDataFactory.createLOAInsuranceProductMapping(
            TEST_STATE, TEST_LOA_CODE, TEST_LOA_DESCRIPTION, true
        );
        ht_LOA_Insurance_Product_Mapping__c mappingB = TestDataFactory.createLOAInsuranceProductMapping(
            TEST_STATE, '12', 'Property Insurance', true
        );

        ht_License__c license = [SELECT Id FROM ht_License__c LIMIT 1];

        // Insert LOA matching mapping A
        ht_LineOfAuthority__c loa = TestDataFactory.createLOAForMatching(
            license.Id, TEST_STATE, TEST_LOA_CODE, TEST_LOA_DESCRIPTION, true
        );

        // Verify initial match
        ht_LineOfAuthority__c loaBeforeUpdate = [
            SELECT Id, ht_LOAMapping__c
            FROM ht_LineOfAuthority__c
            WHERE Id = :loa.Id
        ];
        System.assertEquals(mappingA.Id, loaBeforeUpdate.ht_LOAMapping__c,
            'LOA should initially match mapping A');

        // Reset test state

        // Act: Update LOA to match mapping B
        Test.startTest();
        loaBeforeUpdate.ht_LineOfAuthorityCode__c = '12';
        loaBeforeUpdate.ht_LineOfAuthorityDescription__c = 'Property Insurance';
        update loaBeforeUpdate;
        Test.stopTest();

        // Assert: LOA should now match mapping B
        ht_LineOfAuthority__c loaAfterUpdate = [
            SELECT Id, ht_LOAMapping__c
            FROM ht_LineOfAuthority__c
            WHERE Id = :loa.Id
        ];
        System.assertEquals(mappingB.Id, loaAfterUpdate.ht_LOAMapping__c,
            'LOA should be rematched to mapping B after field change');
    }

    // ============================================================
    // AFTER INSERT TESTS
    // ============================================================

    @isTest
    static void afterInsert_enqueuesBatchForLoasWithMapping() {
        // Arrange: Create mapping
        ht_LOA_Insurance_Product_Mapping__c mapping = TestDataFactory.createLOAInsuranceProductMapping(
            TEST_STATE, TEST_LOA_CODE, TEST_LOA_DESCRIPTION, true
        );

        ht_License__c license = [SELECT Id FROM ht_License__c LIMIT 1];

        // Reset test state

        // Act: Insert LOA with matching mapping
        Test.startTest();
        ht_LineOfAuthority__c loa = TestDataFactory.createLOAForMatching(
            license.Id, TEST_STATE, TEST_LOA_CODE, TEST_LOA_DESCRIPTION, true
        );
        Test.stopTest();

        // Assert: loasEnqueuedForBatchCreate should contain the LOA
        System.assertNotEquals(null, LineOfAuthorityTriggerHandler.loasEnqueuedForBatchCreate,
            'loasEnqueuedForBatchCreate should not be null');
        System.assertEquals(1, LineOfAuthorityTriggerHandler.loasEnqueuedForBatchCreate.size(),
            'Should have enqueued 1 LOA for batch create');
        System.assertEquals(loa.Id, LineOfAuthorityTriggerHandler.loasEnqueuedForBatchCreate[0].Id,
            'Enqueued LOA should be the inserted one');
    }

    @isTest
    static void afterInsert_skipsLoasWithoutMapping() {
        // Arrange: No mapping exists
        ht_License__c license = [SELECT Id FROM ht_License__c LIMIT 1];

        // Reset test state

        // Act: Insert LOA without matching mapping
        Test.startTest();
        ht_LineOfAuthority__c loa = TestDataFactory.createLOAForMatching(
            license.Id, 'XX', '999', 'Non-existent LOA Type', true
        );
        Test.stopTest();

        // Assert: loasEnqueuedForBatchCreate should be null or empty
        Boolean isEmpty = LineOfAuthorityTriggerHandler.loasEnqueuedForBatchCreate == null ||
                          LineOfAuthorityTriggerHandler.loasEnqueuedForBatchCreate.isEmpty();
        System.assert(isEmpty, 'No LOAs should be enqueued for batch create when no mapping exists');
    }

    // ============================================================
    // AFTER UPDATE TESTS
    // ============================================================

    @isTest
    static void afterUpdate_enqueuesBatchWhenMappingChanges() {
        // Arrange: Create two mappings
        ht_LOA_Insurance_Product_Mapping__c mappingA = TestDataFactory.createLOAInsuranceProductMapping(
            TEST_STATE, TEST_LOA_CODE, TEST_LOA_DESCRIPTION, true
        );
        ht_LOA_Insurance_Product_Mapping__c mappingB = TestDataFactory.createLOAInsuranceProductMapping(
            TEST_STATE, '12', 'Property Insurance', true
        );

        ht_License__c license = [SELECT Id FROM ht_License__c LIMIT 1];

        // Insert LOA matching mapping A
        ht_LineOfAuthority__c loa = TestDataFactory.createLOAForMatching(
            license.Id, TEST_STATE, TEST_LOA_CODE, TEST_LOA_DESCRIPTION, true
        );

        // Reset test state before update

        // Act: Update LOA to match mapping B
        Test.startTest();
        loa.ht_LineOfAuthorityCode__c = '12';
        loa.ht_LineOfAuthorityDescription__c = 'Property Insurance';
        update loa;
        Test.stopTest();

        // Assert: loasEnqueuedForBatchUpdate should contain the LOA
        System.assertNotEquals(null, LineOfAuthorityTriggerHandler.loasEnqueuedForBatchUpdate,
            'loasEnqueuedForBatchUpdate should not be null');
        System.assertEquals(1, LineOfAuthorityTriggerHandler.loasEnqueuedForBatchUpdate.size(),
            'Should have enqueued 1 LOA for batch update');

        // Assert: oldLoasEnqueuedForBatchUpdate should contain old values
        System.assertNotEquals(null, LineOfAuthorityTriggerHandler.oldLoasEnqueuedForBatchUpdate,
            'oldLoasEnqueuedForBatchUpdate should not be null');
        System.assertEquals(1, LineOfAuthorityTriggerHandler.oldLoasEnqueuedForBatchUpdate.size(),
            'Should have 1 old LOA value for batch update');
    }

    @isTest
    static void afterUpdate_skipsWhenMappingUnchanged() {
        // Arrange: Create mapping
        ht_LOA_Insurance_Product_Mapping__c mapping = TestDataFactory.createLOAInsuranceProductMapping(
            TEST_STATE, TEST_LOA_CODE, TEST_LOA_DESCRIPTION, true
        );

        ht_License__c license = [SELECT Id FROM ht_License__c LIMIT 1];

        // Insert LOA matching mapping
        ht_LineOfAuthority__c loa = TestDataFactory.createLOAForMatching(
            license.Id, TEST_STATE, TEST_LOA_CODE, TEST_LOA_DESCRIPTION, true
        );

        // Reset test state before update

        // Act: Update LOA but don't change matching fields (mapping stays same)
        Test.startTest();
        loa.ht_UniqueIdentifier__c = 'UPDATED' + System.currentTimeMillis();
        update loa;
        Test.stopTest();

        // Assert: loasEnqueuedForBatchUpdate should be null or empty
        Boolean isEmpty = LineOfAuthorityTriggerHandler.loasEnqueuedForBatchUpdate == null ||
                          LineOfAuthorityTriggerHandler.loasEnqueuedForBatchUpdate.isEmpty();
        System.assert(isEmpty, 'No LOAs should be enqueued for batch update when mapping unchanged');
    }

    // ============================================================
    // AFTER DELETE TESTS
    // ============================================================

    @isTest
    static void afterDelete_enqueuesBatchForLoasWithMapping() {
        // Arrange: Create mapping
        ht_LOA_Insurance_Product_Mapping__c mapping = TestDataFactory.createLOAInsuranceProductMapping(
            TEST_STATE, TEST_LOA_CODE, TEST_LOA_DESCRIPTION, true
        );

        ht_License__c license = [SELECT Id FROM ht_License__c LIMIT 1];

        // Insert LOA matching mapping
        ht_LineOfAuthority__c loa = TestDataFactory.createLOAForMatching(
            license.Id, TEST_STATE, TEST_LOA_CODE, TEST_LOA_DESCRIPTION, true
        );

        // Query to get LOA with mapping populated
        ht_LineOfAuthority__c loaWithMapping = [
            SELECT Id, ht_LOAMapping__c
            FROM ht_LineOfAuthority__c
            WHERE Id = :loa.Id
        ];
        System.assertNotEquals(null, loaWithMapping.ht_LOAMapping__c,
            'LOA should have mapping before delete');

        // Reset test state before delete

        // Act: Delete LOA
        Test.startTest();
        delete loaWithMapping;
        Test.stopTest();

        // Assert: loasEnqueuedForBatchDelete should contain the LOA
        System.assertNotEquals(null, LineOfAuthorityTriggerHandler.loasEnqueuedForBatchDelete,
            'loasEnqueuedForBatchDelete should not be null');
        System.assertEquals(1, LineOfAuthorityTriggerHandler.loasEnqueuedForBatchDelete.size(),
            'Should have enqueued 1 LOA for batch delete');
    }

    @isTest
    static void afterDelete_skipsLoasWithoutMapping() {
        // Arrange: No mapping exists
        ht_License__c license = [SELECT Id FROM ht_License__c LIMIT 1];

        // Insert LOA without matching mapping
        ht_LineOfAuthority__c loa = TestDataFactory.createLOAForMatching(
            license.Id, 'XX', '999', 'Non-existent LOA Type', true
        );

        // Reset test state before delete

        // Act: Delete LOA
        Test.startTest();
        delete loa;
        Test.stopTest();

        // Assert: loasEnqueuedForBatchDelete should be null or empty
        Boolean isEmpty = LineOfAuthorityTriggerHandler.loasEnqueuedForBatchDelete == null ||
                          LineOfAuthorityTriggerHandler.loasEnqueuedForBatchDelete.isEmpty();
        System.assert(isEmpty, 'No LOAs should be enqueued for batch delete when no mapping existed');
    }

    // ============================================================
    // ERROR HANDLING TESTS
    // ============================================================

    @isTest
    static void afterInsert_handlesExceptionGracefully() {
        // Arrange: Create mapping
        ht_LOA_Insurance_Product_Mapping__c mapping = TestDataFactory.createLOAInsuranceProductMapping(
            TEST_STATE, TEST_LOA_CODE, TEST_LOA_DESCRIPTION, true
        );

        ht_License__c license = [SELECT Id FROM ht_License__c LIMIT 1];

        // Force exception
        LineOfAuthorityTriggerHandler.forceException = true;

        // Act: Insert LOA that matches mapping
        Test.startTest();
        ht_LineOfAuthority__c loa = TestDataFactory.createLOAForMatching(
            license.Id, TEST_STATE, TEST_LOA_CODE, TEST_LOA_DESCRIPTION, true
        );
        Test.stopTest();

        // Assert: Exception should be handled gracefully, LOA should still be inserted
        List<ht_LineOfAuthority__c> insertedLoas = [SELECT Id FROM ht_LineOfAuthority__c WHERE Id = :loa.Id];
        System.assertEquals(1, insertedLoas.size(), 'LOA should be inserted despite exception in batch enqueue');

        // Reset flag
        LineOfAuthorityTriggerHandler.forceException = false;
    }

    @isTest
    static void afterUpdate_handlesExceptionGracefully() {
        // Arrange: Create two mappings
        ht_LOA_Insurance_Product_Mapping__c mappingA = TestDataFactory.createLOAInsuranceProductMapping(
            TEST_STATE, TEST_LOA_CODE, TEST_LOA_DESCRIPTION, true
        );
        ht_LOA_Insurance_Product_Mapping__c mappingB = TestDataFactory.createLOAInsuranceProductMapping(
            TEST_STATE, '12', 'Property Insurance', true
        );

        ht_License__c license = [SELECT Id FROM ht_License__c LIMIT 1];

        // Insert LOA matching mapping A
        ht_LineOfAuthority__c loa = TestDataFactory.createLOAForMatching(
            license.Id, TEST_STATE, TEST_LOA_CODE, TEST_LOA_DESCRIPTION, true
        );

        // Force exception for update
        LineOfAuthorityTriggerHandler.forceException = true;

        // Act: Update LOA to match mapping B - should handle exception gracefully
        Test.startTest();
        loa.ht_LineOfAuthorityCode__c = '12';
        loa.ht_LineOfAuthorityDescription__c = 'Property Insurance';
        update loa;
        Test.stopTest();

        // Assert: Exception should be handled gracefully, LOA should still be updated
        List<ht_LineOfAuthority__c> updatedLoas = [SELECT Id, ht_LineOfAuthorityCode__c FROM ht_LineOfAuthority__c WHERE Id = :loa.Id];
        System.assertEquals(1, updatedLoas.size(), 'LOA should be updated despite exception in batch enqueue');
        System.assertEquals('12', updatedLoas[0].ht_LineOfAuthorityCode__c, 'LOA code should be updated');

        // Reset flag
        LineOfAuthorityTriggerHandler.forceException = false;
    }

    // ============================================================
    // IS PRODUCT MATCHED TESTS
    // ============================================================

    @isTest
    static void beforeInsert_setsIsProductMatchedTrueWhenMappingFound() {
        // Arrange: Create mapping
        ht_LOA_Insurance_Product_Mapping__c mapping = TestDataFactory.createLOAInsuranceProductMapping(
            TEST_STATE, TEST_LOA_CODE, TEST_LOA_DESCRIPTION, true
        );

        ht_License__c license = [SELECT Id FROM ht_License__c LIMIT 1];

        // Act: Insert LOA with matching mapping
        Test.startTest();
        ht_LineOfAuthority__c loa = TestDataFactory.createLOAForMatching(
            license.Id, TEST_STATE, TEST_LOA_CODE, TEST_LOA_DESCRIPTION, true
        );
        Test.stopTest();

        // Assert: IsProductMatched should be true
        ht_LineOfAuthority__c insertedLoa = [
            SELECT Id, ht_LOAMapping__c, ht_IsProductMatched__c
            FROM ht_LineOfAuthority__c
            WHERE Id = :loa.Id
        ];
        System.assertEquals(mapping.Id, insertedLoa.ht_LOAMapping__c, 'LOA should have mapping');
        System.assertEquals(true, insertedLoa.ht_IsProductMatched__c, 'IsProductMatched should be true');
    }

    @isTest
    static void beforeInsert_setsIsProductMatchedFalseWhenNoMapping() {
        // Arrange: No mapping exists
        ht_License__c license = [SELECT Id FROM ht_License__c LIMIT 1];

        // Act: Insert LOA without matching mapping
        Test.startTest();
        ht_LineOfAuthority__c loa = TestDataFactory.createLOAForMatching(
            license.Id, 'ZZ', '000', 'No Mapping Exists', true
        );
        Test.stopTest();

        // Assert: IsProductMatched should be false
        ht_LineOfAuthority__c insertedLoa = [
            SELECT Id, ht_LOAMapping__c, ht_IsProductMatched__c
            FROM ht_LineOfAuthority__c
            WHERE Id = :loa.Id
        ];
        System.assertEquals(null, insertedLoa.ht_LOAMapping__c, 'LOA should not have mapping');
        System.assertEquals(false, insertedLoa.ht_IsProductMatched__c, 'IsProductMatched should be false');
    }

    @isTest
    static void beforeUpdate_setsIsProductMatchedFalseWhenMappingCleared() {
        // Arrange: Create mapping and LOA
        ht_LOA_Insurance_Product_Mapping__c mapping = TestDataFactory.createLOAInsuranceProductMapping(
            TEST_STATE, TEST_LOA_CODE, TEST_LOA_DESCRIPTION, true
        );

        ht_License__c license = [SELECT Id FROM ht_License__c LIMIT 1];

        ht_LineOfAuthority__c loa = TestDataFactory.createLOAForMatching(
            license.Id, TEST_STATE, TEST_LOA_CODE, TEST_LOA_DESCRIPTION, true
        );

        // Verify initial state
        loa = [SELECT Id, ht_LOAMapping__c, ht_IsProductMatched__c FROM ht_LineOfAuthority__c WHERE Id = :loa.Id];
        System.assertEquals(true, loa.ht_IsProductMatched__c, 'IsProductMatched should be true initially');

        // Act: Update LOA to not match any mapping
        Test.startTest();
        loa.ht_StateOrProvinceCode__c = 'ZZ';
        loa.ht_LineOfAuthorityCode__c = '000';
        loa.ht_LineOfAuthorityDescription__c = 'No Mapping Exists';
        update loa;
        Test.stopTest();

        // Assert: IsProductMatched should be false
        loa = [SELECT Id, ht_LOAMapping__c, ht_IsProductMatched__c FROM ht_LineOfAuthority__c WHERE Id = :loa.Id];
        System.assertEquals(null, loa.ht_LOAMapping__c, 'LOA mapping should be null');
        System.assertEquals(false, loa.ht_IsProductMatched__c, 'IsProductMatched should be false after clearing');
    }
}