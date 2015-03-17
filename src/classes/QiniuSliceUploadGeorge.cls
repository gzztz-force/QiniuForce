public with sharing class QiniuSliceUploadGeorge 
{
    public QiniuSliceUploadGeorge()
    {
        scope = 'testgeorge';
        deadline = DateTime.now().addHours(1).getTime()/1000;
        limitImagSize = 20480;
        operation = 'imageView/2/h/' + '100' + '/w/' + '100';
        domain = '7u2r2z.com1.z0.glb.clouddn.com';
    }

    FINAL STRING SECRETKEY = 'm2FkS57nIlsCH-oPTs5fx-hxrBJXinCc86xsnzPK';
    FINAL STRING ACCESSKEY = 'LcLorpL24SH1XF0_wAbrwZG5IDiLDlojn2FX0Bn-';

    String scope;
    String operation;
    Long deadline;
    Integer limitImagSize;
    String domain;
    String uploadToken;

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

    
    /*******************************************************************************
                                        Slice upload
    ********************************************************************************/
    FINAL INTEGER BLOCK_SIZE = 4194304;//4194304  //4MB
    FINAL INTEGER BLOCK_STR_SIZE = 5592406;//5592406
    FINAL INTEGER CHUNK_SIZE = 1080576;//262144;  //256KB      
    FINAL INTEGER TIME_OUT = 120000;    //120s
    public String Ctx { get; set; }
    public Integer BlockAmount { get; set; }
    public Integer FileSize { get; set; }
    public Integer BlockSize { get; set; }

    public String sliceUpload(Blob file, String key, String contentType)
    {   
        FileSize = 0;
        uploadToken = generateUploadToken(key);
        //implement make blocks and chunks
        List<List<Blob>> blockList = convertStringsToBlobs(testSlice(file));
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
            
            Blob first = listBlob.remove(0);
            Integer offSet = 0;

            Ctx = mkFirstBlockAndUploadFirestChunk(first);
            offSet += first.size();
            
            //get Last ctx of response and set it to Ctx           
            Respon re = (Respon)JSON.deserialize(Ctx, Respon.class);
            
            Ctx = re.ctx;
            System.debug('*'+Ctx);
            for(Blob blo : listBlob)
            {
                Ctx = putChunk(blo, offSet);
                offSet += blo.size();
                re = (Respon)JSON.deserialize(Ctx, Respon.class);
                Ctx = re.ctx;
                System.debug('#'+Ctx);
            }
            ctxList += Ctx + ',';
            
        }
        blockList.clear();

        ctxList = ctxList.removeEnd(',');
        
        return mkFile(ctxList, key, contentType);
    }

    /*********   upload blob of each first chunk of block  **********/
    public String mkFirstBlockAndUploadFirestChunk(Blob body)
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
        
        System.debug('$make'+res.getBody());
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
        req.setHeader('Content-Length', String.valueOf(body.size()));
        req.setBodyAsBlob(body);     
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
            if(str.length() > CHUNK_SIZE)
            {
                chunks.add(str.subString(0, CHUNK_SIZE));   
                str = str.subString(CHUNK_SIZE);
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
    public List<List<String>> testSlice(Blob source)
    {
        String file = blobToString(source);

        List<List<String>> str = new List<List<String>>();

        List<String> stocks = mkBlock(file);

        for(String s : stocks)
        {
            str.add(mkChunk(s));
        }

        return str;
    }
    /*************   convert String of chunks to Blob    ***************/
    public List<List<Blob>> convertStringsToBlobs(List<List<String>> strings)
    {
        List<List<Blob>> blos = new List<List<Blob>>();
        Boolean isLastBlock = false;
        Integer blockCount = 0;

        for(List<String> li : strings)
        { 
            List<Blob> blo = new List<Blob>();

            for(String str : li)
            {               
                blo.add(EncodingUtil.base64Decode(str));
            } 

            blos.add(blo);
        }

        return blos;
    }

    public String blobToString(Blob blobData)
    {   
        
        String stringEncoded = EncodingUtil.base64Encode(blobData);
        String convertString;
        Boolean converted = true;
        while(stringEncoded.endsWith('='))
        {
            converted = false;
            stringEncoded += ' ';
            convertString = EncodingUtil.base64Encode(Blob.valueOf(stringEncoded));
        }
        if(converted)
        {
            convertString = stringEncoded;
        }
        
        String lastString = Blob.valueOf(convertString).toString();
        return lastString;
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