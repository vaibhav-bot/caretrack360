public with sharing class WarrantyClaimService {

    @TestVisible
    private static final Decimal AUTO_ESCALATE_THRESHOLD = 500;

    public static void validateClaims(List<Warranty_Claim__c> claims) {
        for (Warranty_Claim__c claim : claims) {
            if (claim.Claim_Amount__c != null && claim.Claim_Amount__c < 0) {
                claim.Claim_Amount__c.addError('Claim amount cannot be negative.');
            }
            if (String.isBlank(claim.Description__c)) {
                claim.Description__c.addError('Please describe the issue before submitting this claim.');
            }
            if (claim.Status__c == 'Closed' && String.isBlank(claim.Resolution_Notes__c)) {
                claim.addError('Resolution Notes are required before closing a claim.');
            }
        }
    }

    public static void escalateHighValueClaims(List<Warranty_Claim__c> newClaims, Map<Id, Warranty_Claim__c> oldClaimsMap) {
        List<Warranty_Claim__c> toEscalate = new List<Warranty_Claim__c>();

        for (Warranty_Claim__c claim : newClaims) {
            Boolean wasAlreadyEscalated = oldClaimsMap != null
                && oldClaimsMap.get(claim.Id).Status__c == 'Escalated';

            Boolean needsEscalation = claim.Status__c == 'Escalated'
                || (claim.Claim_Amount__c != null && claim.Claim_Amount__c > AUTO_ESCALATE_THRESHOLD);

            if (needsEscalation && !wasAlreadyEscalated && claim.Related_Case__c == null) {
                toEscalate.add(claim);
            }
        }

        if (!toEscalate.isEmpty()) {
            createCasesForClaims(toEscalate);
        }
    }

    private static void createCasesForClaims(List<Warranty_Claim__c> claims) {
        Set<Id> claimIds = new Map<Id, Warranty_Claim__c>(claims).keySet();

        Map<Id, Warranty_Claim__c> claimsWithDetails = new Map<Id, Warranty_Claim__c>(
            [SELECT Id, Contact__c, Asset__c, Claim_Reason__c, Claim_Amount__c, Description__c
             FROM Warranty_Claim__c
             WHERE Id IN :claimIds]
        );

        List<Case> casesToInsert = new List<Case>();
        Map<Integer, Id> caseIndexToClaimId = new Map<Integer, Id>();
        Integer idx = 0;

        for (Id claimId : claimsWithDetails.keySet()) {
            Warranty_Claim__c claim = claimsWithDetails.get(claimId);
            casesToInsert.add(new Case(
                ContactId   = claim.Contact__c,
                AssetId     = claim.Asset__c,
                Origin      = 'Warranty Claim',
                Priority    = claim.Claim_Amount__c != null && claim.Claim_Amount__c > 1000 ? 'High' : 'Medium',
                Subject     = 'Escalated Warranty Claim: ' + claim.Claim_Reason__c,
                Description = claim.Description__c
            ));
            caseIndexToClaimId.put(idx, claimId);
            idx++;
        }

        insert casesToInsert;

        List<Warranty_Claim__c> claimsToUpdate = new List<Warranty_Claim__c>();
        for (Integer i = 0; i < casesToInsert.size(); i++) {
            claimsToUpdate.add(new Warranty_Claim__c(
                Id = caseIndexToClaimId.get(i),
                Related_Case__c = casesToInsert[i].Id,
                Status__c = 'Escalated'
            ));
        }

        TriggerHandler.bypass('WarrantyClaimTriggerHandler');
        update claimsToUpdate;
        TriggerHandler.clearBypass('WarrantyClaimTriggerHandler');
    }
}