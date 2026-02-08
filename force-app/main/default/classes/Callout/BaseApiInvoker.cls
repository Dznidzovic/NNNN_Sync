/**
 *********************************************************************
 * Apex Class Name    : BaseApiInvoker
 * Created Date       : 11-05-2024
 * @description       : Base class for handling API invocations with different authentication methods.
 * @author            : Stefan Nidzovic
 * Modification Log:
 * Ver   Date         Author                           Modification
 * 1.0   11-05-2024   Stefan Nidzovic                  Initial Version
 * 2.0   11-13-2024   Stefan Nidzovic                  Implementing other Rest Methods
 * 3.0   12-02-2024   Stefan Nidzovic                  Added validation, enhanced comments, and exceptions.
 *********************************************************************
 **/
public virtual class BaseApiInvoker {

    public enum AuthType {
        BEARER,
        BASIC,
        API_KEY,
        JWT
    }

    public enum RestMethod {
        GET,
        POST,
        PATCH,
        PUT,
        DEL
    }

    public enum InvokeType {
        CUSTOM,
        NAMEDCREDENTIAL
    }
    
    private Boolean isInvokedWithNamedCredential = false;
    private Boolean isInvokedWithCustomAuth = false;
    private String namedCredential;
    private String resource;
    private String restMethod;
    private String jsonBody;
    private Integer timeout = 10000;
    private Map<String, String> headers;
    private Map<String, string> queryParams;
    private Map<String, String> uriParams;
    private Object apiResponse;

    public Object getApiResponse() {
        return this.apiResponse;
    }
    
    /**
     ********************************************************
     * @Method Name    : setInvokeType
     * @description    : Sets the invocation type (either NamedCredential or Custom).
     * @param          : invokeType - Either InvokeType.CUSTOM or InvokeType.NAMEDCREDENTIAL.
     * @return         : BaseApiInvoker - The current instance for method chaining.
     ********************************************************
     **/
    public BaseApiInvoker setInvokeType(InvokeType invokeType) {
        this.isInvokedWithCustomAuth = invokeType.name() == 'CUSTOM';

        this.isInvokedWithNamedCredential = !isInvokedWithCustomAuth;

        return this;
    }

    /**
     ********************************************************
     * @Method Name    : setNamedCredential
     * @description    : Sets the NamedCredential for the request.
     * @param          : namedCredential - The API Name of the NamedCredential.
     * @return         : BaseApiInvoker - The current instance for method chaining.
     ********************************************************
     **/
    public BaseApiInvoker setNamedCredential(String namedCredential) {
        if (String.isEmpty(namedCredential)) {
            throw new InvalidRequestException('NamedCredential cannot be null or empty.');
        }
        
        this.namedCredential = namedCredential;
        
        return this;
    }

    /**
     ********************************************************
     * @Method Name    : setResource
     * @description    : Sets the resource path for the request.
     * @param          : resource - The relative resource path.
     * @return         : BaseApiInvoker - The current instance for method chaining.
     ********************************************************
     **/
    public BaseApiInvoker setResource(String resource) {
        if (String.isEmpty(resource)) {
            throw new InvalidRequestException('Resource cannot be null or empty.');
        }
        
        this.resource = resource;
        
        return this;
    }

    /**
     ********************************************************
     * @Method Name    : setRestMethod
     * @description    : Sets the REST method for the request.
     * @param          : restMethod - The HTTP method (GET, POST, PUT, etc.).
     * @return         : BaseApiInvoker - The current instance for method chaining.
     ********************************************************
     **/
    public BaseApiInvoker setRestMethod(RestMethod restMethod) {
        if (restMethod == null) {
            throw new InvalidRequestException('RestMethod cannot be null.');
        }
        
        String enumName = restMethod.name();
        this.restMethod = enumName == 'DEL' ? 'DELETE' : enumName;
        
        return this;
    }

    /**
     ********************************************************
     * @Method Name    : setJsonBody
     * @description    : Sets the JSON body for the request.
     * @param          : jsonBody - The JSON payload.
     * @return         : BaseApiInvoker - The current instance for method chaining.
     * ********************************************************
     **/
    public BaseApiInvoker setJsonBody(String jsonBody) {
        if (String.isEmpty(this.restMethod)) {
            throw new InvalidRequestException('Rest method must be set before Json body');
        }

        if (this.restMethod == 'GET' || this.restMethod == 'DELETE') {
            throw new InvalidRequestException('JSON body is not allowed for GET or DELETE requests.');
        }
        
        this.jsonBody = jsonBody;
        
        return this;
    }

    /**
     * *******************************************************
     * @Method Name    : setHeaders
     * @description    : Sets custom headers for the request.
     * @param          : headers - A map of header key-value pairs.
     * @return         : BaseApiInvoker - The current instance for method chaining.
     *******************************************************
     **/
    public BaseApiInvoker setHeaders(Map<String, String> headers) {
        this.headers = headers;
        
        return this;
    }

    /**
     * *******************************************************
     * @Method Name    : setUriParams
     * @description    : Sets URI parameters for the request.
     * @param          : uriParams - A map of URI parameter key-value pairs.
     * @return         : BaseApiInvoker - The current instance for method chaining.
     *******************************************************
     **/
    public BaseApiInvoker setUriParams(Map<String, String> uriParams) {
        this.uriParams = uriParams;
        
        return this;
    }

    /**
     * ********************************************************
     * @Method Name    : setQueryParams
     * @description    : Sets query parameters for the request.
     * @param          : queryParams - A map of query parameter key-value pairs.
     * @return         : BaseApiInvoker - The current instance for method chaining.
     ********************************************************
     **/
    public BaseApiInvoker setQueryParams(Map<String, String> queryParams) {
        this.queryParams = queryParams;
        
        return this;
    }

    /**
     * *******************************************************
     * @Method Name    : setTimeout
     * @description    : Sets the timeout for the request.
     * @param          : timeout - The timeout in milliseconds.
     * @return         : BaseApiInvoker - The current instance for method chaining.
     ********************************************************
     **/
    public BaseApiInvoker setTimeout(Integer timeout) {
        this.timeout = timeout;
        
        return this;
    }

    /**
     ********************************************************
     * @Method Name    : sendRequest
     * @description    : Executes the API request using the specified invocation type.
     ********************************************************
     **/
    public void sendRequest() {
        if (this.isInvokedWithNamedCredential) {
            this.sendRequestWithNamedCredential();
        } else {
            //this.sendRequestWithCustomAuth();
        }
    }

    /**
     ********************************************************
     * @Method Name    : sendRequestWithNamedCredential
     * @description    : Sends an API request using a NamedCredential.
     ********************************************************
     **/
    private void sendRequestWithNamedCredential() {
        Http http = new Http();
        HttpResponse httpResponse;

        // build http request
        HttpRequest httpRequest = buildRequest(
            this.restMethod, this.headers, this.uriParams, this.queryParams, this.namedCredential, this.resource, this.jsonBody, this.timeout
        );

        try {
            // send http request
            httpResponse = http.send(httpRequest);
            this.apiResponse = httpResponse.getBody();
        } catch (Exception e) {
            if (e != null && e.getMessage() != null) {
                throw new CalloutException('Exception during API callout: ' + e.getMessage());
            }
            
            throw new CalloutException('Exception during API callout: ' + JSON.serialize(e));
        }

        // process response
        if (httpResponse.getStatusCode() < 200 || httpResponse.getStatusCode() >= 300) {
            throw new CalloutException('HTTP callout failed with status code: ' + httpResponse.getStatusCode() + ' - ' + httpResponse.getStatus() + ' - ' + JSON.serialize(this.apiResponse));
        }
    }


    /**
     ********************************************************
     * @Method Name    : buildRequest
     * @description    : Builds the HTTP request based on provided parameters.
     * ********************************************************
     **/
    private static HttpRequest buildRequest(
        String restMethod,
        Map<String, String> headers,
        Map<String, String> uriParams,
        Map<String, String> queryParams,
        String namedCredential,
        String resource,
        String jsonBody,
        Integer timeout
    ) {
        // validate if necessary properties were set
        if (String.isEmpty(restMethod)) {
            throw new InvalidRequestException('REST method (GET, POST, etc.) is required and cannot be null or empty.');
        }
    
        if (String.isEmpty(namedCredential)) {
            throw new InvalidRequestException('Named Credential is required and cannot be null or empty.');
        }
    
        if (String.isEmpty(resource)) {
            throw new InvalidRequestException('Resource path is required and cannot be null or empty.');
        }
    
        // build http request with provided parameters
        HttpRequest httpRequest = new HttpRequest();
        httpRequest.setMethod(restMethod);

        // set optinal headers
        if (headers != null && !headers.isEmpty()) {
            for (String key : headers.keySet()) {
                httpRequest.setHeader(key, headers.get(key));
            }
        }

        // set optional uri params
        if (uriParams != null && !uriParams.isEmpty()) {
            List<String> uriStringParts = new List<String>();

            for (String key : uriParams.keySet()) {
                uriStringParts.add(EncodingUtil.urlEncode(uriParams.get(key), 'UTF-8'));
            }

            resource += '/' + String.join(uriStringParts, '/');
        }

        // set optional query params
        if (queryParams != null && !queryParams.isEmpty()) {
            List<String> queryStringParts = new List<String>();

            for (String key : queryParams.keySet()) {
                queryStringParts.add(key + '=' + EncodingUtil.urlEncode(queryParams.get(key), 'UTF-8'));
            }

            resource += '?' + String.join(queryStringParts, '&');
        }

        // build whole endpoint using named credentials
        // Add namespace prefix for package installation compatibility in subscriber orgs
        httpRequest.setEndpoint('callout:niprsync__' + namedCredential + resource);
        httpRequest.setTimeout(timeout);

        // set body
        if (!String.isEmpty(jsonBody)) {
            httpRequest.setBody(jsonBody);
        }

        return httpRequest;
    }

    // Custom exception for invalid request errors
    public class InvalidRequestException extends Exception {}

    // Custom exception for callout-related errors
    public class CalloutException extends Exception {}
}