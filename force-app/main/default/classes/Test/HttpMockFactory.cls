/**
 ********************************************************************
 * Apex Class Name    : HttpMockFactory
 * Created Date       : 11-05-2024
 * @description       : Factory class for HTTP callout mocking, provides consistent responses for testing API callouts.
 *                      Supports only singled HTTP mock per transaction
 ********************************************************************
 **/
@isTest
global class HttpMockFactory implements HttpCalloutMock {
    private Integer statusCode;
    private String jsonBody;
    private Boolean throwException;

    global HttpMockFactory(Integer code, String body, Boolean forceException) {
        statusCode = code;
        jsonBody = body;
        throwException = forceException;
    }

    global HttpResponse respond(HttpRequest request) {
        if (throwException) {
            throw new BaseApiInvoker.CalloutException('Invoked from test class - Status code: ' + statusCode);
        }

        HttpResponse response = new HttpResponse();
        
        response.setStatusCode(statusCode);
        response.setBody(jsonBody);
        
        return response;
    }
}