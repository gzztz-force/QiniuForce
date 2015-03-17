public with sharing class QiNiuUtil {
    FINAL STRING SECRETKEY = 'm2FkS57nIlsCH-oPTs5fx-hxrBJXinCc86xsnzPK';
    FINAL STRING ACCESSKEY = 'LcLorpL24SH1XF0_wAbrwZG5IDiLDlojn2FX0Bn-';

    String scope;
    Long deadline;
    Integer limitImagSize;
    String operation;
    String domain;
    
    public QiNiuUtil()
    {
        scope = 'testgeorge';
        deadline = DateTime.now().addHours(1).getTime()/1000;
        limitImagSize = 20480;
        operation = 'imageView/2/h/' + '800' + '/w/' + '800';
        domain = '7u2r2z.com1.z0.glb.clouddn.com';
    }

    public Blob compressImg(FeedItem feed)
    {
        Blob compressImgBody;
        String keyInQiniu = 'qiniu_' + feed.ContentFileName;
        Integer status = uploadFile(feed);
        if(status == 200)
        {
            compressImgBody = getCompressImg(keyInQiniu);
        }
        return compressImgBody;
    }

/**--------------------------------upload-------------------------------------------------**/

    public Integer uploadFile(FeedItem feed)
    {
        if((feed.ContentSize==0)||(feed.ContentSize==null))
        {
            return -1;
        }

        Blob bodyBlob;
        String key = 'qiniu_' + feed.ContentFileName;
        String token = generateUploadToken(key);
        String boundary = '-----s1312314124';
        String frontier = '--' + boundary;
        String footer = '\n--' + boundary + '--';
        String fileName = feed.ContentFileName;
        String header = frontier + '\n' 
                    + 'Content-Disposition: form-data; name="token"' + '\n\n' + token + '\n' 
                    + frontier + '\n'
                    + 'Content-Disposition: form-data; name="key"' + '\n\n' + key + '\n' 
                    + frontier + '\n'
                    + 'Content-Disposition: form-data; name="x:username"' + '\n\n' + '\n' 
                    + frontier + '\n'
                    + 'Content-Disposition: form-data;' 
                        + 'name="file"; fileName=' + '"' + fileName + '"' +'\n'
                        + 'Content-Type: application/octet-stream' + '\n' 
                        + 'Content-Transfer-Encoding: binary';

        String headerEncoded = EncodingUtil.base64Encode(Blob.valueOf(header + '\n\n'));

        while(headerEncoded.endsWith('='))
        {
            header += ' ';
            headerEncoded = EncodingUtil.base64Encode(Blob.valueOf(header + '\n\n'));
        }

        String bodyEncoded = EncodingUtil.base64Encode(feed.ContentData);
        String footerEncoded = EncodingUtil.base64Encode(Blob.valueOf(footer));
        String last4Bytes = bodyEncoded.substring(bodyEncoded.length()-4, bodyEncoded.length());

        if(last4Bytes.endsWith('='))
        {
            Blob decoded4Bytes = EncodingUtil.base64Decode(last4Bytes);
            HttpRequest tmp = new HttpRequest();
            tmp.setBodyAsBlob(decoded4Bytes);
            String last4BytesFooter = tmp.getBody() + footer;
            bodyBlob = EncodingUtil.base64Decode(headerEncoded 
                        + bodyEncoded.substring(0, bodyEncoded.length()-4)
                        + EncodingUtil.base64Encode(Blob.valueOf(last4BytesFooter))
                    );
        }
        else
        {
            bodyBlob = EncodingUtil.base64Decode(headerEncoded + bodyEncoded + footerEncoded);
        }

        if(bodyBlob.size()>3000000)
        {
            System.debug('File size limit is 3 MBytes');
        }

        HttpRequest req = new HttpRequest();
        req.setEndpoint('http://upload.qiniu.com');
        req.setMethod('POST');
        req.setHeader('Host','upload.qiniu.com/putb64/' + bodyEncoded.length());
        req.setHeader('Content-Type','multipart/form-data; boundary=' + boundary);
        req.setHeader('Content-Length',String.valueof(bodyBlob.size()));
        req.setBodyAsBlob(bodyBlob);
        System.debug('request Content-Type:' + req.getHeader('Content-Type'));
        System.debug('request Content-Length:' + req.getHeader('Content-Length'));
        System.debug('request Body:' + '\n' + bodyBlob);

        HttpResponse res = new HttpResponse();
        Http http = new Http();
        res = http.send(req);
        System.debug(res.getBody());
        return res.getStatusCode(); 
    }

    public String generateUploadToken(String key)
    {
        scope = scope + ':' + key;
        PutPolicy putPolicy = new PutPolicy(scope, deadline);
        String policyToJson = JSON.serialize(putPolicy);
        System.debug('*************'+policyToJson+'*************');
        String encodedPolicy = EncodingUtil.base64Encode(Blob.valueOf(policyToJson));
        System.debug('*************'+encodedPolicy+'*************');
        Blob sign = crypto.generateMac('hmacSHA1', Blob.valueOf(encodedPolicy), Blob.valueOf(SECRETKEY));
        String encodedSign = EncodingUtil.base64Encode(sign);
        System.debug('*************'+encodedSign+'*************');
        String uploadToken = ACCESSKEY + ':' + encodedSign.replace('/', '_').replace('+','-') + ':' + encodedPolicy;
        return uploadToken;
    }

/**--------------------------------DownLoad-------------------------------------------------**/

    public String generateDownloadToken(String myFileName)
    {
        String downloadUrl = getDownloadUrl(myFileName);
        
        Blob sign = Crypto.generateMac('hmacSHA1', Blob.valueOf(downloadUrl), Blob.valueOf(SECRETKEY));
        String encodedSign = EncodingUtil.base64Encode(sign);
        
        encodedSign = encodedSign.replace('/', '_').replace('+', '-');
        
        String token = ACCESSKEY + ':' + encodedSign;
        return token;
    }

    public String generateRealUrl(String myFileName)
    {
        //String myFile = EncodingUtil.urlEncode(myFileName, 'UTF-8');
        String token = generateDownloadToken(myFileName);
        String downloadUrl = getDownloadUrl(myFileName);
        //get realDownloadUrl 
        String realDownloadUrl = downloadUrl + '&token=' + token;
        return realDownloadUrl;
    }

    public String getDownloadUrl(String myFileName)
    {
        String downloadUrl = 'http://' + domain + '/' + myFileName;
        downloadUrl += '?' + operation + '&e=' + deadline;
        return downloadUrl;
    }

    /**Send Get Request to download some file**/
    public Blob getCompressImg(String fileName)
    {
        Http http = new Http();
        HttpRequest req = new HttpRequest();
        req.setMethod('GET');
        req.setEndpoint(generateRealUrl(fileName));
        HttpResponse res = new HttpResponse();
        ContentVersion version;
        
        res = http.send(req);

        return res.getBodyAsBlob();
    }

    public ContentVersion createContentVersion(Blob bodyBlob, String fileName)
    {
        String title = fileName.subString(0, fileName.indexOf('.'));

        ContentVersion version = new ContentVersion(
            Title = 'compress_' + title,
            VersionData = bodyBlob,
            PathOnClient = fileName,
            Origin = 'H'
            );
        return version;
    }

    class PutPolicy
    {
        String scope;
        Long deadline;
        PutPolicy(String scope, Long deadline)
        {
            this.scope = scope;
            this.deadline = deadline;
        } 
    }
}