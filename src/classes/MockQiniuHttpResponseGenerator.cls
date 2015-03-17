@isTest
public with sharing class MockQiniuHttpResponseGenerator implements HttpCalloutMock
{
    String qiniuResponse;
    TestImgData testData;
    public MockQiniuHttpResponseGenerator()
    {
        testData = new TestImgData();
    }

    public HttpResponse respond(HttpRequest req)
    {
        HttpResponse res = new HttpResponse();
        res.setHeader('Content-Type', 'application/json');
        if(req.getEndpoint().contains('http://upload.qiniu.com'))
        {
            res.setBody('{"hash":"FkZngJXDhbzuJRWJzfsu47G2M_Zw","key":"qiniu_testImg1.1.png","x:username":""}');
            res.setStatus('Status=OK, StatusCode=200');
            res.setStatusCode(200);
            System.debug('-------Mock------>'+'upload:endPoint:' + req.getEndpoint());
        }
        else if(req.getEndpoint().contains('7u2r2z.com1.z0.glb.clouddn.com'))
        {
            res.setBodyAsBlob(testData.getBlobImgData());
            res.setStatus('Status=OK, StatusCode=200');
            res.setStatusCode(200);
            System.debug('-------Mock------>'+'download:endPoint:' + req.getEndpoint());
            System.debug('-------Mock------>'+'download:retunBodyBlobSize:' + testData.getBlobImgData().size());
        }
        else
        {
            res.setBody('');
            res.setStatusCode(400);
            System.debug('-------Mock------>'+'badRequest:endPoint:' + req.getEndpoint());
        }
        return res;
    }
}