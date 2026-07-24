/**
 * @AuraEnabled entry point for all LWC components in Chapter 5.
 * `with sharing` — this class must always respect the running user's record access;
 * there is no reason a UI-facing controller should ever run in system context.
 */
public with sharing class WarrantyClaimController {
    @AuraEnabled(cacheable=true)
    public static List<Warranty_Claim__c> getClaimsForContact(Id contactId) {
        return [
            SELECT Id, Name, Status__c, Claim_Reason__c, Claim_Amount__c,
                   Date_Filed__c, Asset__c, Asset__r.Name, Description__c, Related_Case__c
                    FROM Warranty_Claim__c
            WHERE Contact__c = :contactId
            WITH USER_MODE
            ORDER BY Date_Filed__c DESC
        ];
    }

    @AuraEnabled(cacheable=true)
    public static List<Asset> getAssetsForContact(Id contactId) {
        return [
            SELECT Id, Name, Product2.Name, PurchaseDate
            FROM Asset
            WHERE ContactId = :contactId
            WITH USER_MODE
            ORDER BY PurchaseDate DESC
        ];
    }

     @AuraEnabled(cacheable=true)
    public static Map<String, Integer> getClaimCountsByStatus(Id contactId) {
        Map<String, Integer> counts = new Map<String, Integer>();
        for (AggregateResult ar : [
            SELECT Status__c st, COUNT(Id) cnt
            FROM Warranty_Claim__c
            WHERE Contact__c = :contactId
            WITH USER_MODE
            GROUP BY Status__c
        ]) {
            counts.put((String) ar.get('st'), (Integer) ar.get('cnt'));
        }
        return counts;
}
    @AuraEnabled
    public static Id submitClaim(Warranty_Claim__c claim) {
    try {
        SObjectAccessDecision decision = Security.stripInaccessible(
        AccessType.CREATABLE, new List<Warranty_Claim__c>{ claim }
    );
    List<Warranty_Claim__c> safeClaims = decision.getRecords();
    insert safeClaims;
    return safeClaims[0].Id;
    } catch (DmlException e) {
    throw new AuraHandledException('Could not submit claim: ' + e.getDmlMessage(0));
    }
    }
}