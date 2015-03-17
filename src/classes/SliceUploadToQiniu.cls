public with sharing class SliceUploadToQiniu {
	FINAL STRING SECRETKEY = 'm2FkS57nIlsCH-oPTs5fx-hxrBJXinCc86xsnzPK';
    FINAL STRING ACCESSKEY = 'LcLorpL24SH1XF0_wAbrwZG5IDiLDlojn2FX0Bn-';
    FINAL INTEGER BLOCK_SIZE = 4194300;
    FINAL INTEGER TIME_OUT = 120000;

    String uploadToken;
    String scope;
    String operation;
    Long deadline;
    Integer limitImagSize;
    String domain;

    public String Ctx { get; set; }
    public Integer BlockAmount { get; set; }
    public Integer FileSize { get; set; }
    public Integer BlockSize { get; set; }

	public SliceUploadToQiniu() 
	{
		scope = 'testgeorge';
        deadline = DateTime.now().addHours(1).getTime()/1000;
        limitImagSize = 20480;
        operation = 'imageView/2/h/' + '100' + '/w/' + '100';
        domain = '7u2r2z.com1.z0.glb.clouddn.com';
	}

	public String generateUploadToken(String key)
    {
        scope = scope + ':' + key;
        PutPolicy putPolicy = new PutPolicy(scope, deadline);
        String policyToJson = JSON.serialize(putPolicy);      
        String encodedPolicy = EncodingUtil.base64Encode(Blob.valueOf(policyToJson));       
        Blob sign = crypto.generateMac('hmacSHA1', Blob.valueOf(encodedPolicy), Blob.valueOf(SECRETKEY));
        String encodedSign = EncodingUtil.base64Encode(sign);       
        String uploadToken = ACCESSKEY + ':' + encodedSign.replace('/', '_').replace('+','-') + ':' + encodedPolicy;
        return uploadToken;
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

    public String mkFirstBlock(Blob body)
    {  
        HttpRequest req = new HttpRequest();

        req.setMethod('POST');
        req.setEndpoint('http://upload.qiniu.com' + '/mkblk/' + BlockSize);
        req.setHeader('Host', 'upload.qiniu.com');
        String blocklength = String.valueOf(body.size());
        req.setHeader('Content-Length', blocklength);
        req.setHeader('Content-Type', 'application/octet-stream');
        req.setHeader('Authorization', 'UpToken ' + uploadToken);
    	req.setTimeout(TIME_OUT);
        req.setBodyAsBlob(body);
        Http http = new Http();
        HttpResponse res = http.send(req);
        
        return res.getBody();
    }

    public String putChunk(Blob body, Integer offSet)
    {   
        HttpRequest req = new HttpRequest();

        req.setMethod('POST');
        req.setEndpoint('http://upload.qiniu.com' + '/bput/' + Ctx + '/' + offSet);
        req.setHeader('Host', 'upload.qiniu.com');
        String chunklength = String.valueOf(body.size());
        req.setHeader('Content-Length' , chunklength);
        req.setHeader('Content-Type', 'application/octet-stream');
        req.setHeader('Authorization', 'UpToken ' + uploadToken);

        req.setTimeout(TIME_OUT);
        
        req.setBodyAsBlob(body);

        Http http = new Http();
        HttpResponse res = http.send(req);
        
        return res.getBody();
    }

    /***************   take block together to make a file         **************/
    public String mkFile(String ctxList, String key, String contentType)
    {
        HttpRequest req = new HttpRequest();
        
        String encodedMimeType = EncodingUtil.base64Encode(Blob.valueOf(contentType));
        encodedMimeType = encodedMimeType.replace('/', '_').replace('+','-');
        String encodedUserVar = EncodingUtil.base64Encode(Blob.valueOf('402594071@qq.com'));
        encodedUserVar = encodedUserVar.replace('/', '_').replace('+','-');
        String encodedKey = EncodingUtil.base64Encode(Blob.valueOf(key));
        encodedKey = encodedKey.replace('/', '_').replace('+','-');

        req.setMethod('POST');
        req.setEndpoint('http://upload.qiniu.com' + '/mkfile/' + FileSize + '/key/' 
        				+ encodedKey + '/mimeType/' + encodedMimeType +
                        '/x:user-var/' + encodedUserVar);
        req.setHeader('Host', 'upload.qiniu.com');
        req.setHeader('Content-Type', 'text/plain');       
        req.setHeader('Authorization', 'UpToken ' + uploadToken);
        Blob body = Blob.valueOf(ctxList);
        req.setBodyAsBlob(body);
        req.setHeader('Content-Length', String.valueOf(body.size()));  
        req.setTimeout(TIME_OUT);
        req.getBody();

        Http http = new Http();
        HttpResponse res = http.send(req);
        return res.getBody();
    }

    //sliceUpload to Qiniu cloud Store
    public String sliceUpload(String key, FeedItem feed)
    {
    	uploadToken = generateUploadToken(key);
    	List<List<Blob>> result = getSliceResult(feed);
    	return null;
    }

    //cut file to n file
    public List<List<Blob>> getSliceResult(FeedItem feed)
    {
    	return null;
    }


}