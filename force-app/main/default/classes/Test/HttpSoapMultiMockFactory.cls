/**
 **********************************************************
 * Apex Class Name    : HttpSoapMultiMockFactory
 * Created Date       : 04-01-2025
 * @description       : Custom HttpCalloutMock implementation to handle multiple
 *                     SOAP mock HTTP responses dynamically based on method names
 *                     present in the request body XML.
 * @author            : Dev4Clouds
 * Modification Log:
 * Ver   Date         Author               Modification
 * 1.0   04-01-2025   Dev4Clouds      Initial Version
 **********************************************************
 **/
@isTest
global class HttpSoapMultiMockFactory implements HttpCalloutMock {
    global static Map<String, MockResponseData> mockResponses = new Map<String, MockResponseData>();

    /**
     *********************************************************
     * @Inner Class     : MockResponseData
     * @description     : Represents a mock HTTP response structure,
     *                    including status code, body, and optional exception handling.
     *********************************************************
     **/
    global class MockResponseData {
        Integer statusCode;
        String responseBody;
        Boolean throwException;

        public MockResponseData(Integer statusCode, String responseBody, Boolean throwException) {
            this.statusCode = statusCode;
            this.responseBody = responseBody;
            this.throwException = throwException;
        }
    }

    /**
     *********************************************************
     * @Method Name    : addMock
     * @description    : Adds a mock HTTP response for a specific SOAP method name.
     * @param          : soapMethod - SOAP method name fragment to identify in request body.
     * @param          : statusCode - HTTP status code to return.
     * @param          : responseBody - SOAP XML response body.
     * @param          : throwException - Flag indicating whether to throw an exception.
     * @return         : HttpSoapMultiMockFactory - Returns the instance for method chaining.
     *********************************************************
     */
    global HttpSoapMultiMockFactory addMock(String soapMethod, Integer statusCode, String responseBody, Boolean throwException) {
        mockResponses.put(soapMethod, new MockResponseData(statusCode, responseBody, throwException));
        return this;
    }

    global static void clearMocks() {
        mockResponses =  new Map<String, MockResponseData>();
    }

    /**
     **********************************************************
     *@Method Name    : respond
     *@description    : Handles the mocked HTTP response when a SOAP callout is made.
     *                  Matches method names in the request body XML to provide the correct mock response.
     *@param          : request - The incoming HttpRequest object.
     *@return         : HttpResponse - The mocked HTTP response.
     *@throws         : BaseApiInvoker.CalloutException if no mock response is found or an exception is forced.
     *********************************************************
    **/
    global HttpResponse respond(HttpRequest request) {
        String requestBody = request.getBody();

        for (String soapMethod : mockResponses.keySet()) {
            if (requestBody.contains(soapMethod)) {
                MockResponseData responseData = mockResponses.get(soapMethod);

                if (responseData.throwException) {
                    throw new BaseApiInvoker.CalloutException('Mocked Exception for SOAP method: ' + soapMethod + ', Status code: ' + responseData.statusCode);
                }

                HttpResponse response = new HttpResponse();
                response.setStatusCode(responseData.statusCode);
                response.setBody(responseData.responseBody);
                response.setHeader('Content-Type', 'text/xml;charset=UTF-8');

                return response;
            }
        }

        throw new BaseApiInvoker.CalloutException('No mock response found matching the SOAP request method.');
    }
}