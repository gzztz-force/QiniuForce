public with sharing class QiniuSliceUploadEvan {
	

	FINAL STRING SECRETKEY = 'm2FkS57nIlsCH-oPTs5fx-hxrBJXinCc86xsnzPK';
    FINAL STRING ACCESSKEY = 'LcLorpL24SH1XF0_wAbrwZG5IDiLDlojn2FX0Bn-';

    String scope;
    String operation;
    Long deadline;
    Integer limitImagSize;
    String domain;
    String uploadToken;
    
    public QiniuSliceUploadEvan()
    {
        scope = 'testgeorge';
        deadline = DateTime.now().addHours(1).getTime()/1000;
        limitImagSize = 20480;
        operation = 'imageView/2/h/' + '100' + '/w/' + '100';
        domain = '7u2r2z.com1.z0.glb.clouddn.com';
    }

/**--------------------------------upload-------------------------------------------------**/
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

    public String generateDownloadToken(String myFileName)
    {
        String downloadUrl = 'http://' + domain + '/' + myFileName;
        downloadUrl += '?' + operation + '&e=' + deadline;
        
        Blob sign = Crypto.generateMac('hmacSHA1', Blob.valueOf(downloadUrl), Blob.valueOf(SECRETKEY));
        String encodedSign = EncodingUtil.base64Encode(sign);
        
        encodedSign = encodedSign.replace('/', '_').replace('+', '-');
        
        String token = ACCESSKEY + ':' + encodedSign;
        return token;
    }

    /*******************************************************************************
                                        Slice upload
    ********************************************************************************/
    FINAL INTEGER BLOCK_SIZE = 4194304;//4194304 //4MB
    FINAL INTEGER BLOCK_STR_SIZE = 5592406;
    FINAL INTEGER CHUNK_STR_SIZE = 1048576; //262144;  //256KB      
    FINAL INTEGER TIME_OUT = 120000;    //120s
    //ctx from last bput response , a new bput request need a param named ctx  
    public String ctx;
    public Integer blockAmount; 
    public Integer fileSize; 
    public Integer blockSize;

    public String sliceUpload(Blob file, String key, String contentType)
    {   
        FileSize = 0;
        uploadToken = generateUploadToken(key);
        //implement make blocks and chunks
        List<List<Blob>> blockList = convertStringsToBlobs(getTotalStringData(file));
        BlockAmount = blockList.size();
        
        String ctxList = '';
        BlockSize = BLOCK_SIZE;

        for(List<Blob> a : blockList)
        {
            for(Blob b : a)
            {
                FileSize += b.size();
            }
        }

        Integer blockCount = 0;
        for(List<Blob> listBlob : blockList)
        {   
            blockCount += 1;
            if(blockCount == BlockAmount)
            {   
                BlockSize = FileSize - (blockCount - 1)*BLOCK_SIZE;           
            }
            
            //upload the first chunk of current block
            Blob first = listBlob.remove(0);
            Integer offSet = 0;
            Ctx = mkFirstBlockAndUploadFirstChunk(first);
            offSet += first.size();
            
            //get Last ctx of response and set it to Ctx
            Respon re = (Respon)JSON.deserialize(Ctx, Respon.class);
            
            Ctx = re.ctx;
            
            //upload chunks except the first chunk of a block
            for(Blob blo : listBlob)
            {
                Ctx = putChunk(blo, offSet);
                offSet += blo.size();
                re = (Respon)JSON.deserialize(Ctx, Respon.class);
                Ctx = re.ctx;
            }
            ctxList += Ctx + ',';          
        }
        blockList.clear();

        ctxList = ctxList.removeEnd(',');

        return mkFile(ctxList, key, contentType);
    }

    /*********   upload blob of each first chunk of block  **********/
    public String mkFirstBlockAndUploadFirstChunk(Blob body)
    {  
        HttpRequest req = new HttpRequest();

        req.setMethod('POST');
        req.setEndpoint('http://upload.qiniu.com' + '/mkblk/' + BlockSize);
        req.setHeader('Host', 'upload.qiniu.com');
        Transient String blocklength = String.valueOf(body.size());
        req.setHeader('Content-Length', blocklength);
        req.setHeader('Content-Type', 'application/octet-stream');
        req.setHeader('Authorization', 'UpToken ' + uploadToken);

        req.setTimeout(TIME_OUT);

        req.setBodyAsBlob(body);
        Http http = new Http();
        HttpResponse res = http.send(req);

        return res.getBody();
    }
   
    /**************   upload blob of each chunk      **************/
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
        req.setEndpoint('http://upload.qiniu.com' + '/mkfile/' + FileSize + '/key/' + encodedKey + '/mimeType/' + encodedMimeType +
                        '/x:user-var/' + encodedUserVar);
        req.setHeader('Host', 'upload.qiniu.com');
        req.setHeader('Content-Type', 'text/plain');
        
        req.setHeader('Authorization', 'UpToken ' + uploadToken);
        Blob body = Blob.valueOf(ctxList);
        req.setBodyAsBlob(body);
        
        req.setHeader('Content-Length', String.valueOf(body.size()));  
        req.setTimeout(TIME_OUT);

        Http http = new Http();
        HttpResponse res = http.send(req);
        
        return res.getBody();
    }

    /**********     get Blocks for one file     *************/
    public List<String> mkBlock(String sourseString)
    {

        List<String> blocks = new List<String>();
        String str = sourseString;
        Boolean isLastBlockflag = true;
        
        while(isLastBlockflag)
        {
            if(str.length() > BLOCK_STR_SIZE)
            {
                blocks.add(str.subString(0, BLOCK_STR_SIZE));
                str = str.subString(BLOCK_STR_SIZE);
            }
            else
            {
                blocks.add(str);
                isLastBlockflag = false;
            }
        }

        return blocks;
    }

    /***********     get Chunks for one Block        ************/
    public List<String> mkChunk(String blockString)
    {
        List<String> chunks = new List<String>();
        String str = blockString;
        Boolean isLastChunkflag = true;

        while(isLastChunkflag)
        {
            if(str.length() > CHUNK_STR_SIZE)
            {
                chunks.add(str.subString(0, CHUNK_STR_SIZE));   
                str = str.subString(CHUNK_STR_SIZE);
            }
            else
            {
                chunks.add(str);
                isLastChunkflag = false;
            }
        }
        
        return chunks;
    }

    /************     get Blocks and Chunks of each Block     *************/
    public List<List<String>> getTotalStringData(Blob source)
    {
        String fileString = EncodingUtil.base64Encode(source);

        List<List<String>> strList = new List<List<String>>();

        List<String> stocks = mkBlock(fileString);

        for(String s : stocks)
        {
            strList.add(mkChunk(s));
        }

        return strList;
    }

    /*************   convert String of chunks to Blob    ***************/
    public List<List<Blob>> convertStringsToBlobs(List<List<String>> stringsList)
    {
        List<List<Blob>> bloList = new List<List<Blob>>();
        
        for(List<String> strList : stringsList)
        {
            List<Blob> blo = new List<Blob>();

            for(String str : strList)
            {   
                blo.add(EncodingUtil.base64Decode(str));
            }

            bloList.add(blo);
        }

        return bloList;
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

    //inner Class for JSON deserialize
    class Respon 
    {
        String ctx { get; set; }
        String checksum { get; set; }
        Long crc32 { get; set; }
        Integer offset { get; set; }
        String host { get; set; }
    }
}