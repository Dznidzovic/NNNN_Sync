/**
 *********************************************************
 * Apex Class Name    : BaseApiInvoker_Test
 * Created Date       : 03-19-2025
 * @description       : Test Class used for BaseApiInvoker
 * @author            : Dev4Clouds
 * Modification Log:
 * Ver   Date         Author                   Modification
 * 1.0   03-19-2025   Dev4Clouds          Initial Version
 *********************************************************
 **/
@isTest
public class BaseApiInvoker_Test {
    private static String jsonBody = '{"key1":"value1","key2":"value2"}';
    private static Integer statusCode = 200;

    @isTest
    static void sendRequestWithNamedCredential_GET() {
        // Prepare mock
        Test.setMock(HttpCalloutMock.class, new HttpMockFactory(statusCode, jsonBody, false));

        // Execute
        BaseApiInvoker invoker = new BaseApiInvoker()
            .setInvokeType(BaseApiInvoker.InvokeType.NAMEDCREDENTIAL)
            .setNamedCredential('NamedCredential')
            .setResource('/testendpoint')
            .setRestMethod(BaseApiInvoker.RestMethod.GET)
            .setQueryParams(new Map<String, String>{ 'queryKey1' => 'queryValue1' });

        invoker.sendRequest();

        Object response = JSON.deserializeUntyped((String) invoker.getApiResponse());

        Map<String, Object> responseMap = (Map<String, Object>) response;

        // Assert
        System.assertEquals('value1', responseMap.get('key1'), 'Expected key1 to have value1');
        System.assertEquals('value2', responseMap.get('key2'), 'Expected key2 to have value2');
    }

    @isTest
    static void sendRequestWithNamedCredential_POST() {
        // Prepare Mock
        Test.setMock(HttpCalloutMock.class, new HttpMockFactory(statusCode, jsonBody, false));


        // Execute
        BaseApiInvoker invoker = new BaseApiInvoker()
            .setInvokeType(BaseApiInvoker.InvokeType.NAMEDCREDENTIAL)
            .setNamedCredential('NamedCredential')
            .setResource('/testendpoint')
            .setRestMethod(BaseApiInvoker.RestMethod.POST)
            .setJsonBody(jsonBody)
            .setHeaders(new Map<String, String>{ 'Custom-Header' => 'HeaderValue' });

        invoker.sendRequest();

        Object response = JSON.deserializeUntyped((String) invoker.getApiResponse());
        Map<String, Object> responseMap = (Map<String, Object>) response;

        // Assert
        System.assertEquals('value1', responseMap.get('key1'), 'Expected key1 to have value1');
        System.assertEquals('value2', responseMap.get('key2'), 'Expected key2 to have value2');
    }

    @isTest
    static void sendRequestWithNamedCredential_queryParams() {
        // Prepare mocks
        Test.setMock(HttpCalloutMock.class, new HttpMockFactory(statusCode, jsonBody, false));

        // Execute
        BaseApiInvoker invoker = new BaseApiInvoker()
            .setInvokeType(BaseApiInvoker.InvokeType.NAMEDCREDENTIAL)
            .setNamedCredential('NamedCredential')
            .setResource('/testendpoint')
            .setRestMethod(BaseApiInvoker.RestMethod.GET)
            .setQueryParams(new Map<String, String>{
                'param1' => 'value1',
                'param2' => 'value2'
            });

        invoker.sendRequest();

        Object response = JSON.deserializeUntyped((String) invoker.getApiResponse());
        Map<String, Object> responseMap = (Map<String, Object>) response;

        // Assert
        System.assertEquals('value1', responseMap.get('key1'), 'Expected key1 to have value1');
        System.assertEquals('value2', responseMap.get('key2'), 'Expected key2 to have value2');
    }

    @isTest
    static void sendRequestWithNamedCredential_uriParams() {
        // Prepare Mocks
        Test.setMock(HttpCalloutMock.class, new HttpMockFactory(statusCode, jsonBody, false));

        // Execute
        BaseApiInvoker invoker = new BaseApiInvoker()
            .setInvokeType(BaseApiInvoker.InvokeType.NAMEDCREDENTIAL)
            .setNamedCredential('NamedCredential')
            .setResource('/testendpoint')
            .setRestMethod(BaseApiInvoker.RestMethod.GET)
            .setUriParams(new Map<String, String>{
                'param1' => 'value1',
                'param2' => 'value2'
            });

        invoker.sendRequest();

        Object response = JSON.deserializeUntyped((String) invoker.getApiResponse());
        Map<String, Object> responseMap = (Map<String, Object>) response;

        // Assert
        System.assertEquals('value1', responseMap.get('key1'), 'Expected key1 to have value1');
        System.assertEquals('value2', responseMap.get('key2'), 'Expected key2 to have value2');
    }

    @isTest
    static void sendRequestWithNamedCredential_invalidNamedCredentials() {
        // Prepare Mocks
        statusCode = 400;
        Test.setMock(HttpCalloutMock.class, new HttpMockFactory(statusCode, jsonBody, false));

        BaseApiInvoker invoker = new BaseApiInvoker()
            .setInvokeType(BaseApiInvoker.InvokeType.NAMEDCREDENTIAL)
            .setNamedCredential('InvalidNamedCredential')
            .setResource('/invalidEndpoint')
            .setRestMethod(BaseApiInvoker.RestMethod.GET);

        // Execute + Assert
        try {
            invoker.sendRequest();
            System.assert(false, 'Expected a CalloutException due to invalid request');
        } catch (BaseApiInvoker.CalloutException e) {
            System.assert(e.getMessage().contains('400'), 'Expected CalloutException with status code 400');
        }
    }

    @isTest
    static void sendRequestWithNamedCredential_serverError() {
        // Prepare Mocks
        statusCode = 500;
        Test.setMock(HttpCalloutMock.class, new HttpMockFactory(statusCode, jsonBody, true));

        BaseApiInvoker invoker = new BaseApiInvoker()
            .setInvokeType(BaseApiInvoker.InvokeType.NAMEDCREDENTIAL)
            .setNamedCredential('NamedCredential')
            .setResource('/serverErrorEndpoint')
            .setRestMethod(BaseApiInvoker.RestMethod.GET);

        // Execute + Assert
        try {
            invoker.sendRequest();
            System.assert(false, 'Expected a CalloutException due to server error');
        } catch (BaseApiInvoker.CalloutException e) {
            System.assert(e.getMessage().contains('500'), 'Expected CalloutException with status code 500');
        }
    }

    @isTest
    static void sendRequestWithNamedCredential_withHeaders() {
        // Prepare Mocks
        Test.setMock(HttpCalloutMock.class, new HttpMockFactory(statusCode, jsonBody, false));

        // Execute
        BaseApiInvoker invoker = new BaseApiInvoker()
            .setInvokeType(BaseApiInvoker.InvokeType.NAMEDCREDENTIAL)
            .setNamedCredential('NamedCredential')
            .setResource('/testendpoint')
            .setRestMethod(BaseApiInvoker.RestMethod.GET)
            .setHeaders(new Map<String, String>{
                'Header1' => 'HeaderValue1',
                'Header2' => 'HeaderValue2'
            })
            .setQueryParams(new Map<String, String>{
                'query1' => 'queryValue1',
                'query2' => 'queryValue2'
            });

        invoker.sendRequest();

        Object response = JSON.deserializeUntyped((String) invoker.getApiResponse());
        Map<String, Object> responseMap = (Map<String, Object>) response;

        // Assert
        System.assertEquals('value1', responseMap.get('key1'), 'Expected key1 to have value1');
        System.assertEquals('value2', responseMap.get('key2'), 'Expected key2 to have value2');
    }
}