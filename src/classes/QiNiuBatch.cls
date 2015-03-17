public with sharing class QiNiuBatch implements Database.Batchable<sObject>
{
    public final String query = 'select Id, Title, VersionNumber, IsLatest, ContentSize, ContentDocumentId, ContentModifiedDate, PathOnClient' 
                                + ' from ContentVersion where IsLatest = true and ContentSize > 20480';

    public QiNiuBatch()
    {
        //Id batchInstanceId = Database.executeBatch(new QiNiuBatch(), 10);q

    }

    public Database.QueryLocator start(Database.BatchableContext info)
    {
        return Database.getQueryLocator(query);
    }

    public void execute(Database.BatchableContext info, List<ContentVersion> batch)
    {
        List<ContentVersion> conver = new List<ContentVersion>();
        for(ContentVersion cv : batch)
        {
            conver.add(cv);
        }
    }

    public void finish(Database.BatchableContext info)
    {
        
    }
}