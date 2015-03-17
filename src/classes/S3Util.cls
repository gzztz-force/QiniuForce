public with sharing class S3Util
{
    private static FINAL String S3SECRETKEY = 'GWe9fTW20CHpj+j9047s7V0ajThKFm4CmeTaIHFw';
    private static FINAL String S3ACCESSKEY = 'AKIAJS3AMHSABFUYCJDQ';
    private static FINAL Integer PARTSIZE = 5 * 1024 * 1024; // 5MB
    private static FINAL Integer CHUNKSIZE = 256 * 1024; // 256KB ---Can upload at most 25MB file\100 times callout\

    private static String bucket;
    private static String dateGmt;
    private static String formatdate;
    private static String xamzdate;
    private static String host;
    private static String region;
    private static String service;
    private static String preChunkSignString;
    private static Integer contentLength;

    public S3Util()
    {
        bucket = 'meginfo2s3';
        dateGmt = DateTime.now().formatGmt('EEE, dd MMM yyyy HH:mm:ss ') + 'GMT';
        xamzdate = DateTime.now().formatGmt('yyyyMMdd\'T\'HHmmss\'Z\'');
        formatdate = DateTime.now().formatGmt('yyyyMMdd');
        host = 's3.amazonaws.com';
        region = 'ap-northeast-1';
        service = 's3';
    }

    public Integer uploadFile(FeedItem feed)
    {
        Blob bodyBlob = feed.ContentData;
        String s3key = feed.ContentFileName;
        Blob hashedbodyBlob = Crypto.generateDigest('SHA-256', bodyBlob);
        String hexedhashedbodyBlob = EncodingUtil.convertToHex(hashedbodyBlob).toLowerCase();
        String authorization = 'AWS4-HMAC-SHA256 Credential=' + S3ACCESSKEY + '/' + formatdate + '/' + region + '/' + service + '/aws4_request,'
                                + 'SignedHeaders=date;host;x-amz-content-sha256;x-amz-date,'
                                + 'Signature=' + getSignString(bodyBlob, s3key);
        HttpRequest request = new HttpRequest();
        request.setMethod('PUT');
        request.setEndpoint('http://' + bucket + '.' + host + '/' + s3key);
        request.setHeader('Date', dateGmt);
        request.setHeader('Authorization', authorization);
        request.setHeader('x-amz-date', xamzdate);
        request.setHeader('x-amz-content-sha256', hexedhashedbodyBlob);
        request.setBodyAsBlob(bodyBlob);
        request.setTimeout(60 * 1000);
        Http http = new Http();
        HTTPResponse response = null;
        try
        {
            response = http.send(request);
        }
        catch(Exception ex)
        {
            System.debug(ex.getMessage());
        }
        return response.getStatusCode();
    }

    private static String getSignString(Blob bodyBlob, String s3key)
    {
        // Calculate the signingKey
        String str = 'AWS4' + S3SECRETKEY;
        Blob dateKey = Crypto.generateMac('hmacSHA256', Blob.valueOf(formatdate), Blob.valueOf(str));
        Blob dateRegionKey = Crypto.generateMac('hmacSHA256', Blob.valueOf(region), dateKey);
        Blob dateRegionServiceKey = Crypto.generateMac('hmacSHA256', Blob.valueOf(service), dateRegionKey);
        Blob signingKey = Crypto.generateMac('hmacSHA256', Blob.valueOf('aws4_request'), dateRegionServiceKey);
        // Hash the body
        Blob hashedbodyBlob = Crypto.generateDigest('SHA-256', bodyBlob);
        String hexedhashedbodyBlob = EncodingUtil.convertToHex(hashedbodyBlob);
        // Append canonicalHeaders
        String canonicalHeaders = 'date:' + dateGmt + '\n'
                                + 'host:' + bucket + '.' + host + '\n'
                                + 'x-amz-content-sha256:' + hexedhashedbodyBlob.toLowerCase() + '\n'
                                + 'x-amz-date:' + xamzdate + '\n';
        // Get the hexedhashedCanonicalRequest
        String canonicalRequest = 'PUT' + '\n'
                                + '/' + s3key + '\n'
                                + '\n'
                                + canonicalHeaders + '\n'
                                + 'date;host;x-amz-content-sha256;x-amz-date' + '\n'
                                + hexedhashedbodyBlob.toLowerCase();
        Blob hashedCanonicalRequest = Crypto.generateDigest('SHA-256', Blob.valueOf(canonicalRequest));
        String hexedhashedCanonicalRequest = EncodingUtil.convertToHex(hashedCanonicalRequest);
        // Calculate the stringToSign
        String stringToSign = 'AWS4-HMAC-SHA256' + '\n'
                            + xamzdate + '\n'
                            + formatdate + '/' + region + '/' + service + '/aws4_request' + '\n'
                            + hexedhashedCanonicalRequest.toLowerCase();
        return getSignString(stringToSign, signingKey);
    }

    private static String getSignString(String stringToSign, Blob signingKey)
    {
        Blob hashedSignString = Crypto.generateMac('hmacSHA256', Blob.valueOf(stringToSign), signingKey);
        String hex = EncodingUtil.convertToHex(hashedSignString);
        return hex.toLowerCase();
    }

    //----------------------------------------------------upload <3MB file-----------------------------------------------------------
    //public Integer uploadFile(FeedItem feed)
    //{
    //    Blob bodyBlob = feed.ContentData;
    //    String s3key = feed.ContentFileName;
    //    String subResource = '';
    //    String contentType = '';
    //    String contentMD5 = '';
    //    String authorization = 'AWS ' + S3ACCESSKEY + ':' + sign('PUT', contentMD5, contentType, s3key, subResource);
    //    HttpRequest request = new HttpRequest();
    //    request.setEndpoint('http://' + bucket + '.' + host + '/' + s3key);
    //    request.setMethod('PUT');
    //    request.setHeader('Date', dateGmt);
    //    request.setHeader('Authorization', authorization);
    //    request.setBodyAsBlob(bodyBlob);
    //    request.setTimeout(60 * 1000);
    //    Http http = new Http();
    //    HTTPResponse response = null;
    //    try
    //    {
    //        response = http.send(request);
    //    }
    //    catch(Exception ex)
    //    {
    //        System.debug(ex.getMessage());
    //    }
    //    return response.getStatusCode();
    //}

    //private static String sign(String httpMethod, String contentMD5, String contentType, String s3key, String subresource)
    //{
    //    contentMD5 = (contentMD5 == null) ? '' : contentMD5;
    //    contentType = (contentType == null) ? '' : contentType;
    //    subresource = (subresource == null) ? '' : subresource;
    //    String resource = '/' + bucket + '/' + s3key + subresource;
    //    String stringToSign = httpMethod + '\n' + contentMD5 + '\n' + contentType + '\n' + dateGmt + '\n' + resource;
    //    return sign(stringToSign);
    //}
    
    //private static String sign(String stringToSign)
    //{
    //    return EncodingUtil.base64Encode(Crypto.generateMac('hmacSHA1', Blob.valueOf(stringToSign), Blob.valueOf(S3SECRETKEY)));
    //}

    //---------------------------------------------------upload >3MB file using AWS2---------------------------------------------------------------
    //public void upload(FeedItem feed)
    //{
    //    //String uploadId = initateMultipartUpload(feed);
    //    //Map<Integer, String> eTggMap = startS3Tasks(5, uploadId);
    //    //completeMultipartUpload(eTggMap, uploadId);
    //}

    //public String initateMultipartUpload(FeedItem feed)
    //{
    //    String contentMD5 = '';
    //    String contentType = '';
    //    String subResource = '';
    //    String s3key = feed.ContentFileName;
    //    String authorization = 'AWS ' + S3ACCESSKEY + ':' + getInitiateMultiPartSignString('POST', contentMD5, contentType, s3key, subResource);
    //    HttpRequest request = new HttpRequest();
    //    request.setEndpoint('http://' + bucket + '.' + host + '/' + s3key + '?uploads');
    //    request.setMethod('POST');
    //    request.setHeader('Date', dateGmt);
    //    request.setHeader('Authorization', authorization);
    //    request.setTimeout(60 * 1000);
    //    Http http = new Http();
    //    HTTPResponse response = null;
    //    try
    //    {
    //        response = http.send(request);
    //    }
    //    catch(Exception ex)
    //    {
    //        System.debug(ex.getMessage());
    //    }
    //    Integer status = response.getStatusCode();
    //    System.debug(response.getBody());
    //    //how to get the uploadId
    //    String uploadId = '';
    //    return uploadId;
    //}

    //public Map<Integer, String> startS3Tasks(Integer workerCnt, String uploadId)
    //{
    //    return null;
    //}

    //public String uploadPartToS3(String uploadId, Integer partNumber)
    //{
    //    return null;
    //}

    //public void completeMultipartUpload(Map<Integer, String> eTggMap, String uploadId)
    //{

    //}

    //public String buildXMLData(Map<Integer, String> eTggMap)
    //{
    //    return null;
    //}

    //private static String getInitiateMultiPartSignString(String httpMethod, String contentMD5, String contentType, String s3key, String subResource)
    //{
    //    contentMD5 = (contentMD5 == null) ? '' : contentMD5;
    //    contentType = (contentType == null) ? '' : contentType;
    //    subResource = (subResource == null) ? '' : subResource;
    //    String resource = '/' + bucket + '/' + s3key + '?uploads' + subResource;
    //    String stringToSign = httpMethod + '\n' + contentMD5 + '\n' + contentType + '\n' + dateGmt + '\n' + resource;
    //    return getInitiateMultiPartSignString(stringToSign);
    //}
    
    //private static String getInitiateMultiPartSignString(String stringToSign)
    //{
    //    return EncodingUtil.base64Encode(Crypto.generateMac('hmacSHA1', Blob.valueOf(stringToSign), Blob.valueOf(S3SECRETKEY)));
    //}

    //private static String getMultipartUploadSignString(Integer partNumber, String uploadId, String httpMethod, String contentMD5, String contentType, String s3key, String subResource)
    //{
    //    contentMD5 = (contentMD5 == null) ? '' : contentMD5;
    //    contentType = (contentType == null) ? '' : contentType;
    //    subResource = (subResource == null) ? '' : subResource;
    //    String resource = '/' + bucket + '/' + s3key + '?partNumber=' + String.valueOf(partNumber) + '&uploadId=' + uploadId + subResource;
    //    String stringToSign = httpMethod + '\n' + contentMD5 + '\n' + contentType + '\n' + dateGmt + '\n' + resource;
    //    return getMultipartUploadSignString(stringToSign);
    //}
    
    //private static String getMultipartUploadSignString(String stringToSign)
    //{
    //    return EncodingUtil.base64Encode(Crypto.generateMac('hmacSHA1', Blob.valueOf(stringToSign), Blob.valueOf(S3SECRETKEY)));
    //}

    //private static String getMultipartCompleteSignString(String uploadId, String httpMethod, String contentMD5, String contentType, String s3key, String subResource)
    //{
    //    contentMD5 = (contentMD5 == null) ? '' : contentMD5;
    //    contentType = (contentType == null) ? '' : contentType;
    //    subResource = (subResource == null) ? '' : subResource;
    //    String resource = '/' + bucket + '/' + s3key + '?uploadId=' + uploadId + subResource;
    //    String stringToSign = httpMethod + '\n' + contentMD5 + '\n' + contentType + '\n' + dateGmt + '\n' + resource;
    //    return getMultipartCompleteSignString(stringToSign);
    //}
    
    //private static String getMultipartCompleteSignString(String stringToSign)
    //{
    //    return EncodingUtil.base64Encode(Crypto.generateMac('hmacSHA1', Blob.valueOf(stringToSign), Blob.valueOf(S3SECRETKEY)));
    //}

    //-------------------------------------------------upload >3MB file using AWS4----------------------------------------------------------------
    //public void upload(FeedItem feed)
    //{
    //    String uploadId = initateMultipartUpload(feed);
    //    Map<Integer, String> eTggMap = startS3Tasks(uploadId,feed);
    //    completeMultipartUpload(eTggMap, uploadId);
    //}

    //public String initateMultipartUpload(FeedItem feed)
    //{
    //    Blob bodyBlob = feed.ContentData;
    //    String s3key = feed.ContentFileName;
    //    Blob hashedbodyBlob = Crypto.generateDigest('SHA-256', bodyBlob);
    //    String hexedhashedbodyBlob = EncodingUtil.convertToHex(hashedbodyBlob).toLowerCase();
    //    String authorization = 'AWS4-HMAC-SHA256 Credential=' + S3ACCESSKEY + '/' + formatdate + '/' + region + '/' + service + '/aws4_request,'
    //                            + 'SignedHeaders=date;host;x-amz-content-sha256;x-amz-date,'
    //                            + 'Signature=' + getInitiateMultiPartSignString(bodyBlob, s3key);
    //    HttpRequest request = new HttpRequest();
    //    request.setMethod('POST');
    //    request.setEndpoint('http://' + bucket + '.' + host + '/' + s3key + '?uploads');
    //    request.setHeader('Date', dateGmt);
    //    request.setHeader('Authorization', authorization);
    //    request.setHeader('x-amz-date', xamzdate);
    //    request.setHeader('x-amz-content-sha256', hexedhashedbodyBlob);
    //    request.setBodyAsBlob(bodyBlob);
    //    request.setTimeout(60 * 1000);
    //    Http http = new Http();
    //    HTTPResponse response = null;
    //    try
    //    {
    //        response = http.send(request);
    //    }
    //    catch(Exception ex)
    //    {
    //        System.debug(ex.getMessage());
    //    }
    //    return response.getBody();
    //}

    //private Map<Integer, String> startS3Tasks(String uploadId, FeedItem feed)
    //{
    //    Map<Integer, String> uptags = new Map<Integer, String>();
    //    Long totalUploads = (feed.ContentSize / PARTSIZE) + 1;
    //    for (Integer i = 1; i <= totalUploads; i++)
    //    {
    //        String etag = uploadPartToS3(uploadId, i);
    //        if (etag != null)
    //        {
    //            uptags.put(i, etag);
    //        }
    //        else
    //        {
    //            i--;
    //        }
    //    }
    //    return uptags;
    //}

    //private String uploadPartToS3(String uploadId, Integer partNumber)
    //{
        
    //    return null;
    //}

    //private void completeMultipartUpload(Map<Integer, String> eTggMap, String uploadId)
    //{

    //}

    //private String buildXMLData(Map<Integer, String> eTggMap)
    //{
    //    return null;
    //}

    //private static String getUploadId()
    //{
    //    String uploadId = '';
    //    // Retrieve xml to get the uploadId
    //    return uploadId;
    //}

    //private static String getInitiateMultiPartSignString(Blob bodyBlob, String s3key)
    //{
    //    // Calculate the signingKey
    //    String str = 'AWS4' + S3SECRETKEY;
    //    Blob dateKey = Crypto.generateMac('hmacSHA256', Blob.valueOf(formatdate), Blob.valueOf(str));
    //    Blob dateRegionKey = Crypto.generateMac('hmacSHA256', Blob.valueOf(region), dateKey);
    //    Blob dateRegionServiceKey = Crypto.generateMac('hmacSHA256', Blob.valueOf(service), dateRegionKey);
    //    Blob signingKey = Crypto.generateMac('hmacSHA256', Blob.valueOf('aws4_request'), dateRegionServiceKey);
    //    // Hash the body
    //    Blob hashedbodyBlob = Crypto.generateDigest('SHA-256', bodyBlob);
    //    String hexedhashedbodyBlob = EncodingUtil.convertToHex(hashedbodyBlob);
    //    // Append canonicalHeaders
    //    String canonicalHeaders = 'date:' + dateGmt + '\n'
    //                            + 'host:' + bucket + '.' + host + '\n'
    //                            + 'x-amz-content-sha256:' + hexedhashedbodyBlob.toLowerCase() + '\n'
    //                            + 'x-amz-date:' + xamzdate + '\n';
    //    // Get the hexedhashedCanonicalRequest
    //    String canonicalRequest = 'POST' + '\n'
    //                            + '/' + s3key + '\n'
    //                            + 'uploads=' + '\n'
    //                            + canonicalHeaders + '\n'
    //                            + 'date;host;x-amz-content-sha256;x-amz-date' + '\n'
    //                            + hexedhashedbodyBlob.toLowerCase();
    //    Blob hashedCanonicalRequest = Crypto.generateDigest('SHA-256', Blob.valueOf(canonicalRequest));
    //    String hexedhashedCanonicalRequest = EncodingUtil.convertToHex(hashedCanonicalRequest);
    //    // Calculate the stringToSign
    //    String stringToSign = 'AWS4-HMAC-SHA256' + '\n'
    //                        + xamzdate + '\n'
    //                        + formatdate + '/' + region + '/' + service + '/aws4_request' + '\n'
    //                        + hexedhashedCanonicalRequest.toLowerCase();
    //    return getInitiateMultiPartSignString(stringToSign, signingKey);
    //}

    //private static String getInitiateMultiPartSignString(String stringToSign, Blob signingKey)
    //{
    //    Blob hashedSignString = Crypto.generateMac('hmacSHA256', Blob.valueOf(stringToSign), signingKey);
    //    String hex = EncodingUtil.convertToHex(hashedSignString);
    //    return hex.toLowerCase();
    //}

    //private static String getMultipartUploadSignString(String s3key)
    //{
    //    String stringToSign = '';
    //    Blob signingKey;
    //    return getMultipartUploadSignString(stringToSign, signingKey);
    //}

    //private static String getMultipartUploadSignString(String stringToSign, Blob signingKey)
    //{
    //    String hex = EncodingUtil.convertToHex(Crypto.generateMac('hmacSHA256', Blob.valueOf(stringToSign), signingKey));
    //    return hex.toLowerCase();
    //}

    //private static String getMultipartCompleteSignString(String s3key)
    //{
    //    String stringToSign = '';
    //    Blob signingKey;
    //    return getMultipartCompleteSignString(stringToSign, signingKey);
    //}

    //private static String getMultipartCompleteSignString(String stringToSign, Blob signingKey)
    //{
    //    String hex = EncodingUtil.convertToHex(Crypto.generateMac('hmacSHA256', Blob.valueOf(stringToSign), signingKey));
    //    return hex.toLowerCase();
    //}
    
    //----------------------------------------------Cut the contentdata-----------------something to test-------------------------------------------
    //private static Blob getCurrentChunkData(FeedItem feed, Integer counter)
    //{
    //    Blob currentChunkData = null;
    //    String bodyString = EncodingUtil.base64Encode(feed.ContentData);
    //    Integer dataLength = bodyString.length();
    //    Integer totalChunk = getTotalChunk(feed.ContentSize);
    //    Integer i = dataLength / (totalChunk - 1);
    //    Integer mod = Math.mod(dataLength, totalChunk - 1);
    //    if(mod == 0)
    //    {
    //        if(counter == totalChunk)
    //        {
    //            String data = '';
    //            currentChunkData = Blob.valueOf(data);
    //            return currentChunkData;
    //        }
    //        bodyString.substring((counter-1)*i, counter*i);
    //        currentChunkData = Blob.valueOf(bodyString); 
    //        return currentChunkData;
    //    }
    //    else
    //    {
    //        if(counter == totalChunk)
    //        {
    //            String data = '';
    //            currentChunkData = Blob.valueOf(data);
    //            return currentChunkData;
    //        }
    //        if(counter == totalChunk - 1)
    //        {
    //            bodyString.substring((counter-1)*i, counter*i+mod);
    //            currentChunkData = Blob.valueOf(bodyString);
    //            return currentChunkData;
    //        }
    //        bodyString.substring((counter-1)*i, counter*i);
    //        currentChunkData = Blob.valueOf(bodyString);
    //        return currentChunkData;
    //    }
    //    return currentChunkData;
    //}

    //test <256kb file,just have two chunks,first is itself,second is zero.
    //private static Blob getCurrentChunkData(FeedItem feed, Integer counter)
    //{
    //    Blob currentChunkData = feed.ContentData;
    //    Integer totalChunk = getTotalChunk(feed.ContentSize);
    //    if(counter == totalChunk)
    //    {
    //        String data = '';
    //        currentChunkData = Blob.valueOf(data);
    //        return currentChunkData;
    //    }
    //    return currentChunkData;
    //}

    //public void startS3Tasks(FeedItem feed)
    //{
    //    Integer length = feed.ContentSize;
    //    Integer totalChunk = getTotalChunk(length);
    //    setContentLength(length);
    //    for (Integer counter = 1; counter <= totalChunk; counter++)
    //    {
    //        String bodyinfo = uploadFile(feed, counter);
    //        System.debug(bodyinfo);
    //        //Integer statusCode = uploadFile(feed, counter);
    //        //if(statusCode != 200)
    //        //{
    //        //    System.debug('upload chunks failed');
    //        //    break;
    //        //}
    //    }
    //}

    //public static String uploadFile(FeedItem feed, Integer counter)
    //{
    //    Blob currentChunkBody = getCurrentChunkBody(feed, counter);
    //    String s3key = feed.ContentFileName;
    //    Integer length = feed.ContentSize;
    //    String authorization = 'AWS4-HMAC-SHA256 Credential=' + S3ACCESSKEY + '/' + formatdate + '/' + region + '/' + service + '/aws4_request,'
    //                            + 'SignedHeaders=content-encoding;content-length;host;x-amz-content-sha256;x-amz-date;x-amz-decoded-content-length;x-amz-storage-class,'
    //                            + 'Signature=' + getSeedSignString(String.valueOf(length), s3key);
    //    HttpRequest request = new HttpRequest();
    //    request.setMethod('PUT');
    //    request.setEndpoint('http://' + bucket + '.' + host + '/' + s3key);
    //    request.setHeader('Host', host);
    //    request.setHeader('x-amz-date', xamzdate);
    //    request.setHeader('x-amz-storage-class', 'REDUCED_REDUNDANCY');
    //    request.setHeader('Authorization', authorization);
    //    request.setHeader('x-amz-content-sha256', 'STREAMING-AWS4-HMAC-SHA256-PAYLOAD');
    //    request.setHeader('Content-Encoding', 'aws-chunked');
    //    request.setHeader('x-amz-decoded-content-length', String.valueOf(length));
    //    request.setHeader('Content-Length', '');
    //    request.setBodyAsBlob(currentChunkBody);
    //    request.setTimeout(60 * 1000);
    //    Http http = new Http();
    //    HTTPResponse response = null;
    //    try
    //    {
    //        response = http.send(request);
    //    }
    //    catch(Exception ex)
    //    {
    //        System.debug(ex.getMessage());
    //    }
    //    Integer statusCode = response.getStatusCode();
    //    //return statusCode;
    //    return response.getBody();
    //}

    //private static String getSeedSignString(String length, String s3key)
    //{
    //    // Get the signingKey
    //    Blob signingKey = getSigningKey();
    //    // Calculate the canonicalHeaders
    //    String canonicalHeaders = 'content-encoding:aws-chunked' + '\n'
    //                            + 'content-length:' + '' + '\n'
    //                            + 'host:' + host + '\n'
    //                            + 'x-amz-content-sha256:' + 'STREAMING-AWS4-HMAC-SHA256-PAYLOAD' + '\n'
    //                            + 'x-amz-date:' + xamzdate + '\n'
    //                            + 'x-amz-decoded-content-length:' + length + '\n'
    //                            + 'x-amz-storage-class:REDUCED_REDUNDANCY' + '\n';
    //    // Append the canonicalHeaders & Calculate the hexedhashedCanonicalRequest
    //    String canonicalRequest = 'PUT' + '\n'
    //                            + '/' + s3key + '\n'
    //                            + '\n'
    //                            + canonicalHeaders + '\n'
    //                            + 'content-encoding;content-length;host;x-amz-content-sha256;x-amz-date;x-amz-decoded-content-length;x-amz-storage-class' + '\n'
    //                            + 'STREAMING-AWS4-HMAC-SHA256-PAYLOAD';
    //    Blob hashedCanonicalRequest = Crypto.generateDigest('SHA-256', Blob.valueOf(canonicalRequest));
    //    String hexedhashedCanonicalRequest = EncodingUtil.convertToHex(hashedCanonicalRequest);
    //    // Calculate the stringToSign
    //    String stringToSign = 'AWS4-HMAC-SHA256' + '\n'
    //                        + xamzdate + '\n'
    //                        + formatdate + '/' + region + '/' + service + '/aws4_request' + '\n'
    //                        + hexedhashedCanonicalRequest.toLowerCase();
    //    // Calculate the signString
    //    Blob hashedSignString = Crypto.generateMac('hmacSHA256', Blob.valueOf(stringToSign), signingKey);
    //    String hexedhashedSignString = EncodingUtil.convertToHex(hashedSignString);
    //    return hexedhashedSignString.toLowerCase();
    //}

    //private static Blob getCurrentChunkBody(FeedItem feed, Integer counter)
    //{
    //    Blob currentChunkData = getCurrentChunkData(feed, counter);
    //    String stringChunkData = EncodingUtil.base64Encode(currentChunkData);
    //    if(counter == 1)
    //    {
    //        preChunkSignString = getSeedSignString(String.valueOf(feed.ContentSize), feed.ContentFileName);
    //    }
    //    Integer currentChunkSize = getCurrentChunkSize(feed, counter);
    //    String hexedCurrentChunkSize = getHexadecimalChunkSize(currentChunkSize);
    //    String currentChunkSignString = getChunkSignString(preChunkSignString, currentChunkData);
    //    // Construct the current chunk body
    //    String chunkBody = hexedCurrentChunkSize + ';chunk-signature=' + currentChunkSignString + '\r\n'
    //                    + stringChunkData + '\r\n';
    //    Blob currentChunkBody = Blob.valueOf(chunkBody);
    //    return currentChunkBody;
    //}

    //private static String getChunkSignString(String preSignature, Blob currentChunkData)
    //{
    //    // Get the signingKey
    //    Blob signingKey = getSigningKey();
    //    // Hash the empty string
    //    Blob hashedEmptyString = Crypto.generateDigest('SHA-256', Blob.valueOf(''));
    //    String hexedhashedEmptyString = EncodingUtil.convertToHex(hashedEmptyString);
    //    // Hash the current-chunk-data
    //    Blob hashedCurrentChunkData = Crypto.generateDigest('SHA-256', currentChunkData);
    //    String hexedhashedCurrentChunkData = EncodingUtil.convertToHex(hashedCurrentChunkData);
    //    // Calculate the stringToSign
    //    String stringToSign = 'AWS4-HMAC-SHA256-PAYLOAD' + '\n'
    //                        + xamzdate + '\n'
    //                        + formatdate + '/' + region + '/' + service + '/aws4_request' + '\n'
    //                        + preSignature + '\n'
    //                        + hexedhashedEmptyString.toLowerCase() + '\n'
    //                        + hexedhashedCurrentChunkData.toLowerCase();
    //    // Calculate the signString
    //    Blob hashedSignString = Crypto.generateMac('hmacSHA256', Blob.valueOf(stringToSign), signingKey);
    //    String hexedhashedSignString = EncodingUtil.convertToHex(hashedSignString);
    //    // Before return,give the current signstring to pre-signature
    //    preChunkSignString = hexedhashedSignString.toLowerCase();
    //    return hexedhashedSignString.toLowerCase();
    //}

    //private static void setContentLength(Integer length)
    //{
    //    Integer hexedTotalCurrentChunkSize = 0;
    //    Integer totalChunk = getTotalChunk(length);
    //    Integer localizedSize = 85 * totalChunk + 1;
    //    Integer mod = Math.mod(length, CHUNKSIZE);
    //    Integer i = length / CHUNKSIZE;
    //    for(Integer m = 0; m < i; m++)
    //    {
    //        hexedTotalCurrentChunkSize += getHexadecimalChunkSize(CHUNKSIZE).length();
    //    }
    //    hexedTotalCurrentChunkSize += getHexadecimalChunkSize(mod).length();
    //    contentLength = localizedSize + length + hexedTotalCurrentChunkSize;
    //}

    //private static String getHexadecimalChunkSize(Integer currentChunkSize)
    //{
    //    String hexedCurrentChunkSize = '';
    //    List<Integer> modList = new List<Integer>();
    //    while(currentChunkSize / 16 != 0)
    //    {
    //        Integer mod = Math.mod(currentChunkSize, 16);
    //        modList.add(mod);
    //        currentChunkSize = currentChunkSize / 16;
    //    }
    //    if(currentChunkSize / 16 == 0)
    //    {
    //        Integer lastMod = Math.mod(currentChunkSize, 16);
    //        modList.add(lastMod);
    //    }
    //    for(Integer i = modList.size() - 1; i >= 0; i--)
    //    {
    //        if(modList.get(i) < 10)
    //        {
    //            hexedCurrentChunkSize += String.valueOf(modList.get(i));
    //        }
    //        else if(modList.get(i) == 10)
    //        {
    //            hexedCurrentChunkSize += 'A';
    //        }
    //        else if(modList.get(i) == 11)
    //        {
    //            hexedCurrentChunkSize += 'B';
    //        }
    //        else if(modList.get(i) == 12)
    //        {
    //            hexedCurrentChunkSize += 'C';
    //        }
    //        else if(modList.get(i) == 13)
    //        {
    //            hexedCurrentChunkSize += 'D';
    //        }
    //        else if(modList.get(i) == 14)
    //        {
    //            hexedCurrentChunkSize += 'E';
    //        }
    //        else if(modList.get(i) == 15)
    //        {
    //            hexedCurrentChunkSize += 'F';
    //        }
    //    }
    //    return hexedCurrentChunkSize;
    //}

    //private static Integer getCurrentChunkSize(FeedItem feed, Integer counter)
    //{
    //    Integer length = feed.ContentSize;
    //    Integer totalChunk = getTotalChunk(length);
    //    Integer mod = Math.mod(length, CHUNKSIZE);
    //    Integer i = length / CHUNKSIZE;
    //    if(i >= 0 && mod != 0)
    //    {
    //        if(counter == totalChunk - 1)
    //        {
    //            return mod;
    //        }
    //        if(counter == totalChunk)
    //        {
    //            return 0;
    //        }
    //        return CHUNKSIZE;
    //    }
    //    if(i > 0 && mod == 0)
    //    {
    //        if(counter == totalChunk)
    //        {
    //            return 0;
    //        }
    //        return CHUNKSIZE;
    //    }
    //    return -1;
    //}

    //private static Integer getTotalChunk(Integer length)
    //{
    //    Integer totalChunk = 2;
    //    Integer mod = Math.mod(length, CHUNKSIZE);
    //    if(length / CHUNKSIZE > 0 && mod == 0)
    //    {
    //        totalChunk = length / CHUNKSIZE + 1;
    //    }
    //    else if(length / CHUNKSIZE > 0 && mod != 0)
    //    {
    //        totalChunk = length / CHUNKSIZE + 2;
    //    }
    //    return totalChunk;
    //}

    //private static Blob getSigningKey()
    //{
    //    String str = 'AWS4' + S3SECRETKEY;
    //    Blob dateKey = Crypto.generateMac('hmacSHA256', Blob.valueOf(formatdate), Blob.valueOf(str));
    //    Blob dateRegionKey = Crypto.generateMac('hmacSHA256', Blob.valueOf(region), dateKey);
    //    Blob dateRegionServiceKey = Crypto.generateMac('hmacSHA256', Blob.valueOf(service), dateRegionKey);
    //    Blob signingKey = Crypto.generateMac('hmacSHA256', Blob.valueOf('aws4_request'), dateRegionServiceKey);
    //    return signingKey;
    //}
}