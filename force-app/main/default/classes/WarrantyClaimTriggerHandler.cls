public class WarrantyClaimTriggerHandler extends TriggerHandler {
    private List<Warranty_Claim__c> newClaims;
    private Map<Id, Warranty_Claim__c> oldClaimsMap;
    public WarrantyClaimTriggerHandler() {
        this.newClaims = (List<Warranty_Claim__c>) Trigger.new;
        this.oldClaimsMap = (Map<Id, Warranty_Claim__c>) Trigger.oldMap;
    }
    protected override void beforeInsert() {
    WarrantyClaimService.validateClaims(this.newClaims);    
    }

    protected override void beforeUpdate() {
        WarrantyClaimService.validateClaims(this.newClaims);
    }
    protected override void afterInsert() {
        WarrantyClaimService.escalateHighValueClaims(this.newClaims, null);
    }   

    protected override void afterUpdate() {
        WarrantyClaimService.escalateHighValueClaims(this.newClaims, this.oldClaimsMap);
    }
}