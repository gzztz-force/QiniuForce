@isTest
global class MockS3HttpResponseGenerator implements HttpCalloutMock
{
    global HTTPResponse respond(HTTPRequest req)
    {
        HttpResponse res = new HttpResponse();
        if(req.getEndpoint().contains('http://meginfo2s3.s3.amazonaws.com/'))
        {
            System.assertEquals('PUT', req.getMethod());
            res.setStatusCode(200);
            return res;
        }
        return null;
    }
}