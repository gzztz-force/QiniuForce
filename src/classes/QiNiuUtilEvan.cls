public with sharing class QiNiuUtilEvan {

    
    FINAL STRING SECRETKEY = 'zUYHgWEqevP4uNwVKVDXux2NXW7PRI4Ijbs5rFXx';
    FINAL STRING ACCESSKEY = 'ivEa4_Lh31WM-9XeuwPA-i4EaRiBpNLipUL5TdAg';

    String scope;
    Long deadline;
 
    public QiNiuUtilEvan()
    {   scope = 'qiniuforce';
        deadline = DateTime.now().addHours(1).getTime()/1000;
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

    public String uploadFile(FeedItem feed)
    {
        String key = 'qiniu_' + feed.ContentFileName;
        String token = generateUploadToken(key);
        String boundary = '-----s1312314124';
        String frontier = '--' + boundary;
        String footer = '\n--' + boundary + '--';
        String fileName = feed.ContentFileName;
        Blob bodyBlob;
        System.debug('&&&&&&&&&&&&&&&&'+ fileName + '&&&&&&&&&&&&&&&&'+key+'&&&&&&&&&&&&&&&');

        String header = frontier + '\n' + 'Content-Disposition: form-data; name="token"' + '\n\n' + token + '\n' + frontier + '\n' +
        'Content-Disposition: form-data; name="key"' + '\n\n' + key + '\n' + frontier + '\n' +
        'Content-Disposition: form-data; name="x:username"' + '\n\n\n' +  frontier + '\n' +
        'Content-Disposition: form-data; name="file"; fileName=' + '"' + fileName + '"' +'\n' + 
        'Content-Type: application/octet-stream' + '\n' + 'Content-Transfer-Encoding: binary';
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
            bodyBlob = EncodingUtil.base64Decode(headerEncoded +
            bodyEncoded.substring(0, bodyEncoded.length()-4) +
            EncodingUtil.base64Encode(Blob.valueOf(last4BytesFooter)));
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
        //req.setBody(bodyText);
        req.setBodyAsBlob(bodyBlob);
        System.debug('request Content-Type:' + req.getHeader('Content-Type'));
        System.debug('request Content-Length:' + req.getHeader('Content-Length'));
        System.debug('request Body:' + '\n' + bodyBlob);

        HttpResponse res = new HttpResponse();
        Http http = new Http();
        res = http.send(req);
        System.debug(res.getBody());
        return res.getStatus();
    }

    public void uploadAllFile()
    {
        for(FeedItem feed : getAllFile())
        {
           uploadFile(feed);
        }
    }

    public List<FeedItem> getAllFile()
    {
        List<FeedItem> feedItems = new List<FeedItem>();
        for(FeedItem feed : [select Id, Body, ContentData, ContentSize, ContentFileName from FeedItem limit 1000])
        {
            if(feed.ContentSize > 20480)
            {
                feedItems.add(feed);
            }
        }
        return feedItems;
    }

    public void updateContentVersion(String Id, Blob imgData, String fileName)
    {
        ContentVersion contentVersion = [select Id, Title, VersionNumber,IsLatest, ContentSize, ContentDocumentId, ContentModifiedDate,PathOnClient, ContentUrl from ContentVersion where Id = :ID ];
        contentVersion.PathOnClient = fileName;
        contentVersion.VersionData = imgData;
        update contentVersion;
    }


    public void printOutBlob(FeedItem feed)
    {
        String bodyEncoded = EncodingUtil.base64Encode(feed.ContentData);
        System.debug(bodyEncoded);
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
    /*
    public Integer convertBlob(blob blobFile)
    {
        System.debug('***********BlobSize before:' + blobFile.size());
        String stringEncoded = EncodingUtil.base64Encode(blobFile);
        System.debug('***********StringLenth before:' + stringEncoded.length());
        String converString;
        while(stringEncoded.endsWith('='))
        {
            stringEncoded += ' ';
            converString = EncodingUtil.base64Encode(Blob.valueOf(stringEncoded));
        }
        System.debug('***********StringLenth after:' + converString.length());
        Blob blobEncoded = EncodingUtil.base64Decode(converString);
        System.debug('***********BlobSize after:' + blobFile.size());
        String lastString = blobEncoded.toString();
        System.debug('***********StringLenth last:' + lastString.length());
        if(lastString.length()>BLOCK_STR_SIZE)
            {
                lastString = lastString.subString(0,BLOCK_STR_SIZE);
            }
        Blob lastBlob = EncodingUtil.base64Decode(lastString);
        System.debug('***********lastBlob:'+ lastBlob.size());
        return lastBlob.size();
    }
    */
}