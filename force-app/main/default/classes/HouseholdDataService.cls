/**
 * Aggregates household level context (accounts, goals, work, activities, communications)
 * so Agentforce Topic Actions can answer questions about the relationship.
 *
 * The service assumes that households are modeled as Account records and that
 * Financial Services Cloud (FSC) is installed. All FSC objects are queried via
 * dynamic SOQL to remain safe if specific objects are not enabled in a target org.
 */
public with sharing class HouseholdDataService {

    // Limits to keep Topic action payloads compact and governor friendly
    private static final Integer MAX_MEMBERS = 25;
    private static final Integer MAX_FINANCIAL_ACCOUNTS = 25;
    private static final Integer MAX_FINANCIAL_GOALS = 20;
    private static final Integer MAX_ACTIVITIES = 25;
    private static final Integer MAX_CASES = 10;
    private static final Integer MAX_OPPORTUNITIES = 10;
    private static final Integer MAX_SERVICE_REQUESTS = 15;
    private static final Integer MAX_ACTION_PLANS = 10;
    private static final Integer MAX_EMAILS = 15;
    private static final Integer MAX_INTERACTIONS = 20;

    @AuraEnabled(cacheable=true)
    public static HouseholdSnapshot fetchSnapshot(Id householdId) {
        HouseholdContext context = HouseholdContext.build(householdId);

        HouseholdSnapshot snapshot = new HouseholdSnapshot();
        snapshot.household = buildHouseholdSummary(context);
        snapshot.members = loadMembers(context);
        snapshot.financialAccounts = loadFinancialAccounts(context);
        snapshot.financialGoals = loadFinancialGoals(context);
        snapshot.recentActivities = loadRecentActivities(context);
        snapshot.recentCases = loadCases(context);
        snapshot.pipeline = loadOpportunities(context);
        snapshot.serviceRequests = loadServiceRequests(context);
        snapshot.actionPlans = loadActionPlans(context);
        snapshot.communications = loadEmails(context);
        snapshot.interactions = loadInteractionSummaries(context);

        return snapshot;
    }

    // ----- Snapshot data structures -----

    public class HouseholdSnapshot {
        @AuraEnabled public HouseholdSummary household;
        @AuraEnabled public List<MemberSummary> members = new List<MemberSummary>();
        @AuraEnabled public List<FinancialAccountSummary> financialAccounts = new List<FinancialAccountSummary>();
        @AuraEnabled public List<FinancialGoalSummary> financialGoals = new List<FinancialGoalSummary>();
        @AuraEnabled public List<ActivitySummary> recentActivities = new List<ActivitySummary>();
        @AuraEnabled public List<CaseSummary> recentCases = new List<CaseSummary>();
        @AuraEnabled public List<OpportunitySummary> pipeline = new List<OpportunitySummary>();
        @AuraEnabled public List<ServiceRequestSummary> serviceRequests = new List<ServiceRequestSummary>();
        @AuraEnabled public List<ActionPlanSummary> actionPlans = new List<ActionPlanSummary>();
        @AuraEnabled public List<CommunicationSummary> communications = new List<CommunicationSummary>();
        @AuraEnabled public List<InteractionSummary> interactions = new List<InteractionSummary>();
    }

    public class HouseholdSummary {
        @AuraEnabled public Id id;
        @AuraEnabled public String name;
        @AuraEnabled public String recordType;
        @AuraEnabled public String stage;
        @AuraEnabled public String phone;
        @AuraEnabled public String preferredChannel;
        @AuraEnabled public Decimal totalAssets;
        @AuraEnabled public String tier;
        @AuraEnabled public String ownerName;
        @AuraEnabled public String ownerId;
        @AuraEnabled public AddressSummary billingAddress;
        @AuraEnabled public Date lastActivityDate;
    }

    public class AddressSummary {
        @AuraEnabled public String street;
        @AuraEnabled public String city;
        @AuraEnabled public String state;
        @AuraEnabled public String postalCode;
        @AuraEnabled public String country;
    }

    public class MemberSummary {
        @AuraEnabled public Id contactId;
        @AuraEnabled public String name;
        @AuraEnabled public String email;
        @AuraEnabled public String phone;
        @AuraEnabled public String role;
        @AuraEnabled public Boolean isPrimary;
    }

    public class FinancialAccountSummary {
        @AuraEnabled public Id id;
        @AuraEnabled public String name;
        @AuraEnabled public String number;
        @AuraEnabled public String type;
        @AuraEnabled public Decimal balance;
        @AuraEnabled public Decimal aum;
        @AuraEnabled public String status;
        @AuraEnabled public String institution;
        @AuraEnabled public Date lastActivityDate;
    }

    public class FinancialGoalSummary {
        @AuraEnabled public Id id;
        @AuraEnabled public String name;
        @AuraEnabled public String type;
        @AuraEnabled public Decimal targetAmount;
        @AuraEnabled public Date targetDate;
        @AuraEnabled public String status;
        @AuraEnabled public Decimal progress;
        @AuraEnabled public String priority;
        @AuraEnabled public String ownerName;
    }

    public class ActivitySummary {
        @AuraEnabled public Id id;
        @AuraEnabled public String subject;
        @AuraEnabled public String type;
        @AuraEnabled public Datetime activityDate;
        @AuraEnabled public String status;
        @AuraEnabled public String ownerName;
        @AuraEnabled public String description;
        @AuraEnabled public Id relatedRecordId;
    }

    public class CaseSummary {
        @AuraEnabled public Id id;
        @AuraEnabled public String caseNumber;
        @AuraEnabled public String subject;
        @AuraEnabled public String status;
        @AuraEnabled public String priority;
        @AuraEnabled public Datetime lastModifiedDate;
        @AuraEnabled public String ownerName;
    }

    public class OpportunitySummary {
        @AuraEnabled public Id id;
        @AuraEnabled public String name;
        @AuraEnabled public String stage;
        @AuraEnabled public Decimal amount;
        @AuraEnabled public Date closeDate;
        @AuraEnabled public String type;
        @AuraEnabled public String ownerName;
    }

    public class ServiceRequestSummary {
        @AuraEnabled public Id id;
        @AuraEnabled public String name;
        @AuraEnabled public String status;
        @AuraEnabled public String type;
        @AuraEnabled public String subType;
        @AuraEnabled public Date dueDate;
        @AuraEnabled public String priority;
        @AuraEnabled public Datetime lastUpdated;
        @AuraEnabled public String ownerName;
    }

    public class ActionPlanSummary {
        @AuraEnabled public Id id;
        @AuraEnabled public String name;
        @AuraEnabled public String status;
        @AuraEnabled public String type;
        @AuraEnabled public Date targetCompletionDate;
        @AuraEnabled public Decimal completionPercent;
        @AuraEnabled public String templateName;
        @AuraEnabled public String ownerName;
    }

    public class CommunicationSummary {
        @AuraEnabled public Id id;
        @AuraEnabled public String subject;
        @AuraEnabled public String status;
        @AuraEnabled public String direction;
        @AuraEnabled public Datetime messageDate;
        @AuraEnabled public String fromAddress;
        @AuraEnabled public String toAddress;
        @AuraEnabled public Id parentId;
    }

    public class InteractionSummary {
        @AuraEnabled public Id id;
        @AuraEnabled public String subject;
        @AuraEnabled public String summary;
        @AuraEnabled public Datetime interactionDate;
        @AuraEnabled public String channel;
        @AuraEnabled public String interactionType;
        @AuraEnabled public String outcome;
        @AuraEnabled public String ownerName;
        @AuraEnabled public Id primaryContactId;
        @AuraEnabled public String primaryContactName;
    }

    public class HouseholdDataException extends Exception {}

    // ----- Builders -----

    private static HouseholdSummary buildHouseholdSummary(HouseholdContext context) {
        Account household = context.household;
        HouseholdSummary summary = new HouseholdSummary();
        summary.id = household.Id;
        summary.name = household.Name;
        summary.recordType = household.RecordTypeId != null && household.RecordType != null ? household.RecordType.DeveloperName : null;
        summary.ownerId = household.OwnerId;
        summary.ownerName = household.Owner != null ? household.Owner.Name : null;
        summary.phone = (String) household.get('Phone');
        summary.stage = (String) household.get('FinServ__LifecycleStage__c');
        summary.preferredChannel = (String) household.get('FinServ__PreferredChannel__c');
        summary.totalAssets = (Decimal) household.get('FinServ__TotalAssets__c');
        summary.tier = (String) household.get('FinServ__ClientTier__c');
        summary.billingAddress = new AddressSummary();
        summary.billingAddress.street = household.BillingStreet;
        summary.billingAddress.city = household.BillingCity;
        summary.billingAddress.state = household.BillingState;
        summary.billingAddress.postalCode = household.BillingPostalCode;
        summary.billingAddress.country = household.BillingCountry;
        summary.lastActivityDate = household.LastActivityDate;
        return summary;
    }

    private static List<MemberSummary> loadMembers(HouseholdContext context) {
        List<MemberSummary> members = context.hasHouseholdMemberObject
            ? loadFscHouseholdMembers(context)
            : loadStandardHouseholdMembers(context);

        if (members.size() > MAX_MEMBERS) {
            members = members.subList(0, MAX_MEMBERS);
        }
        return members;
    }

    private static List<MemberSummary> loadFscHouseholdMembers(HouseholdContext context) {
        String hhId = String.escapeSingleQuotes((String) context.household.Id);
        String soql = 'SELECT Id, FinServ__Contact__c, FinServ__Role__c, FinServ__Primary__c, ' +
            'FinServ__Contact__r.Name, FinServ__Contact__r.Email, FinServ__Contact__r.Phone ' +
            'FROM FinServ__HouseholdMember__c ' +
            'WHERE FinServ__Household__c = \'' + hhId + '\' ' +
            'ORDER BY FinServ__Primary__c DESC, CreatedDate ASC ' +
            'LIMIT ' + MAX_MEMBERS;
        List<SObject> rows = Database.query(soql);
        List<MemberSummary> members = new List<MemberSummary>();
        for (SObject row : rows) {
            MemberSummary dto = new MemberSummary();
            dto.contactId = (Id) row.get('FinServ__Contact__c');
            SObject contact = row.getSObject('FinServ__Contact__r');
            if (contact != null) {
                dto.name = (String) contact.get('Name');
                dto.email = (String) contact.get('Email');
                dto.phone = (String) contact.get('Phone');
                addEmailToContext(dto.email, context);
            } else {
                dto.name = (String) row.get('Name');
            }
            dto.role = (String) row.get('FinServ__Role__c');
            dto.isPrimary = (Boolean) row.get('FinServ__Primary__c');
            if (dto.contactId != null) {
                context.memberContactIds.add(dto.contactId);
            }
            members.add(dto);
        }
        return members;
    }

    private static List<MemberSummary> loadStandardHouseholdMembers(HouseholdContext context) {
        List<MemberSummary> members = new List<MemberSummary>();
        if (SchemaInspector.objectExists('AccountContactRelation')) {
            List<AccountContactRelation> relations = [
                SELECT Id, ContactId, Role, IsPrimary, Contact.Name, Contact.Email, Contact.Phone
                FROM AccountContactRelation
                WHERE AccountId = :context.household.Id
                ORDER BY IsPrimary DESC, CreatedDate ASC
                LIMIT :MAX_MEMBERS
            ];
            for (AccountContactRelation rel : relations) {
                MemberSummary dto = new MemberSummary();
                dto.contactId = rel.ContactId;
                if (rel.Contact != null) {
                    dto.name = rel.Contact.Name;
                    dto.email = rel.Contact.Email;
                    dto.phone = rel.Contact.Phone;
                    addEmailToContext(dto.email, context);
                }
                dto.role = rel.Role;
                dto.isPrimary = rel.IsPrimary;
                if (dto.contactId != null) {
                    context.memberContactIds.add(dto.contactId);
                }
                members.add(dto);
            }
        }

        if (members.isEmpty()) {
            List<Contact> contacts = [
                SELECT Id, Name, Email, Phone
                FROM Contact
                WHERE AccountId = :context.household.Id
                ORDER BY CreatedDate ASC
                LIMIT :MAX_MEMBERS
            ];
            Boolean markPrimary = true;
            for (Contact contact : contacts) {
                MemberSummary dto = new MemberSummary();
                dto.contactId = contact.Id;
                dto.name = contact.Name;
                dto.email = contact.Email;
                dto.phone = contact.Phone;
                dto.role = 'Household Member';
                dto.isPrimary = markPrimary;
                markPrimary = false;
                context.memberContactIds.add(dto.contactId);
                addEmailToContext(dto.email, context);
                members.add(dto);
            }
        }
        return members;
    }

    private static void addEmailToContext(String email, HouseholdContext context) {
        if (!String.isBlank(email)) {
            context.memberEmails.add(email.trim());
        }
    }

    private static List<FinancialAccountSummary> loadFinancialAccounts(HouseholdContext context) {
        if (!context.hasFinancialAccountObject || String.isBlank(context.financialAccountOwnerField)) {
            return new List<FinancialAccountSummary>();
        }
        String hhId = String.escapeSingleQuotes((String) context.household.Id);
        String ownerField = context.financialAccountOwnerField;
        List<String> selectFields = SchemaInspector.filterExistingFields('FinServ__FinancialAccount__c', new List<String>{
            'Id', 'Name', ownerField, 'FinServ__AccountNumber__c', 'FinServ__FinancialAccountType__c',
            'FinServ__AUM__c', 'FinServ__CurrentBalance__c', 'FinServ__Status__c',
            'FinServ__FinancialAccountInstitution__c', 'LastActivityDate', 'LastModifiedDate'
        });
        if (!selectFields.contains(ownerField)) {
            selectFields.add(ownerField);
        }
        if (!selectFields.contains('LastModifiedDate')) {
            selectFields.add('LastModifiedDate');
        }
        String soql = 'SELECT ' + String.join(selectFields, ', ') +
            ' FROM FinServ__FinancialAccount__c WHERE ' + ownerField + ' = \'' + hhId + '\' ' +
            'ORDER BY ' + (selectFields.contains('FinServ__AUM__c') ? 'FinServ__AUM__c' : 'LastModifiedDate') + ' DESC ' +
            'LIMIT ' + MAX_FINANCIAL_ACCOUNTS;
        List<SObject> rows = Database.query(soql);
        List<FinancialAccountSummary> financialAccounts = new List<FinancialAccountSummary>();
        for (SObject row : rows) {
            FinancialAccountSummary dto = new FinancialAccountSummary();
            dto.id = (Id) row.get('Id');
            dto.name = (String) row.get('Name');
            dto.number = (String) row.get('FinServ__AccountNumber__c');
            dto.type = (String) row.get('FinServ__FinancialAccountType__c');
            dto.aum = (Decimal) row.get('FinServ__AUM__c');
            dto.balance = (Decimal) row.get('FinServ__CurrentBalance__c');
            dto.status = (String) row.get('FinServ__Status__c');
            dto.institution = (String) row.get('FinServ__FinancialAccountInstitution__c');
            Object lastActivity = row.get('LastActivityDate');
            if (lastActivity instanceof Date) {
                dto.lastActivityDate = (Date) lastActivity;
            }
            financialAccounts.add(dto);
        }
        return financialAccounts;
    }

    private static List<FinancialGoalSummary> loadFinancialGoals(HouseholdContext context) {
        if (!context.hasFinancialGoalObject || String.isBlank(context.goalHouseholdField)) {
            return new List<FinancialGoalSummary>();
        }
        String hhId = String.escapeSingleQuotes((String) context.household.Id);
        List<String> selectFields = SchemaInspector.filterExistingFields('FinServ__FinancialGoal__c', new List<String>{
            'Id', 'Name', 'FinServ__GoalType__c', 'FinServ__TargetDate__c', 'FinServ__TargetAmount__c',
            'FinServ__FundingStatus__c', 'FinServ__Priority__c', 'FinServ__Progress__c', 'LastModifiedDate'
        });
        if (!selectFields.contains(context.goalHouseholdField)) {
            selectFields.add(context.goalHouseholdField);
        }
        if (!selectFields.contains('LastModifiedDate')) {
            selectFields.add('LastModifiedDate');
        }
        if (!selectFields.contains('Owner.Name')) {
            selectFields.add('Owner.Name');
        }
        String soql = 'SELECT ' + String.join(selectFields, ', ') +
            ' FROM FinServ__FinancialGoal__c WHERE ' + context.goalHouseholdField + ' = \'' + hhId + '\' ' +
            'ORDER BY ' + (selectFields.contains('FinServ__TargetDate__c') ? 'FinServ__TargetDate__c' : 'LastModifiedDate') + ' DESC ' +
            'LIMIT ' + MAX_FINANCIAL_GOALS;
        List<SObject> rows = Database.query(soql);
        List<FinancialGoalSummary> goals = new List<FinancialGoalSummary>();
        for (SObject row : rows) {
            FinancialGoalSummary summary = new FinancialGoalSummary();
            summary.id = (Id) row.get('Id');
            summary.name = (String) row.get('Name');
            summary.type = (String) row.get('FinServ__GoalType__c');
            summary.targetAmount = (Decimal) row.get('FinServ__TargetAmount__c');
            summary.targetDate = (Date) row.get('FinServ__TargetDate__c');
            summary.status = (String) row.get('FinServ__FundingStatus__c');
            summary.progress = (Decimal) row.get('FinServ__Progress__c');
            summary.priority = (String) row.get('FinServ__Priority__c');
            SObject owner = row.getSObject('Owner');
            summary.ownerName = owner != null ? (String) owner.get('Name') : null;
            goals.add(summary);
        }
        return goals;
    }

    private static List<ActivitySummary> loadRecentActivities(HouseholdContext context) {
        Set<Id> memberIds = new Set<Id>(context.memberContactIds);
        List<Task> tasks;
        if (!memberIds.isEmpty()) {
            tasks = [
                SELECT Id, Subject, Status, ActivityDate, Owner.Name, Description, WhatId, WhoId, Priority
                FROM Task
                WHERE (WhatId = :context.household.Id OR WhoId IN :memberIds)
                ORDER BY ActivityDate DESC
                LIMIT :MAX_ACTIVITIES
            ];
        } else {
            tasks = [
                SELECT Id, Subject, Status, ActivityDate, Owner.Name, Description, WhatId, WhoId, Priority
                FROM Task
                WHERE WhatId = :context.household.Id
                ORDER BY ActivityDate DESC
                LIMIT :MAX_ACTIVITIES
            ];
        }

        List<Event> events;
        if (!memberIds.isEmpty()) {
            events = [
                SELECT Id, Subject, StartDateTime, EndDateTime, Owner.Name, Description, WhatId, WhoId, Location
                FROM Event
                WHERE (WhatId = :context.household.Id OR WhoId IN :memberIds)
                ORDER BY StartDateTime DESC
                LIMIT :Math.max(5, MAX_ACTIVITIES / 2)
            ];
        } else {
            events = [
                SELECT Id, Subject, StartDateTime, EndDateTime, Owner.Name, Description, WhatId, WhoId, Location
                FROM Event
                WHERE WhatId = :context.household.Id
                ORDER BY StartDateTime DESC
                LIMIT :Math.max(5, MAX_ACTIVITIES / 2)
            ];
        }

        List<ActivitySummary> summaries = new List<ActivitySummary>();
        for (Task task : tasks) {
            ActivitySummary dto = new ActivitySummary();
            dto.id = task.Id;
            dto.subject = task.Subject;
            dto.type = 'Task';
            dto.activityDate = task.ActivityDate != null ? Datetime.newInstance(task.ActivityDate.year(), task.ActivityDate.month(), task.ActivityDate.day()) : null;
            dto.status = task.Status;
            dto.ownerName = task.Owner != null ? task.Owner.Name : null;
            dto.description = task.Description;
            dto.relatedRecordId = task.WhatId != null ? task.WhatId : task.WhoId;
            summaries.add(dto);
        }

        for (Event eventRecord : events) {
            ActivitySummary dto = new ActivitySummary();
            dto.id = eventRecord.Id;
            dto.subject = eventRecord.Subject;
            dto.type = 'Event';
            dto.activityDate = eventRecord.StartDateTime;
            dto.status = 'Scheduled';
            dto.ownerName = eventRecord.Owner != null ? eventRecord.Owner.Name : null;
            dto.description = eventRecord.Description;
            dto.relatedRecordId = eventRecord.WhatId != null ? eventRecord.WhatId : eventRecord.WhoId;
            summaries.add(dto);
        }

        summaries.sort(new ActivityDateComparator());
        if (summaries.size() > MAX_ACTIVITIES) {
            summaries = summaries.subList(0, MAX_ACTIVITIES);
        }
        return summaries;
    }

    private class ActivityDateComparator implements System.Comparator<ActivitySummary> {
        public Integer compare(ActivitySummary a, ActivitySummary b) {
            Long aTime = a.activityDate != null ? a.activityDate.getTime() : 0;
            Long bTime = b.activityDate != null ? b.activityDate.getTime() : 0;
            return aTime == bTime ? 0 : (aTime < bTime ? 1 : -1);
        }
    }

    private static List<CaseSummary> loadCases(HouseholdContext context) {
        Set<Id> memberIds = new Set<Id>(context.memberContactIds);
        List<Case> cases;
        if (!memberIds.isEmpty()) {
            cases = [
                SELECT Id, CaseNumber, Subject, Status, Priority, LastModifiedDate, Owner.Name, ContactId
                FROM Case
                WHERE AccountId = :context.household.Id OR ContactId IN :memberIds
                ORDER BY LastModifiedDate DESC
                LIMIT :MAX_CASES
            ];
        } else {
            cases = [
                SELECT Id, CaseNumber, Subject, Status, Priority, LastModifiedDate, Owner.Name
                FROM Case
                WHERE AccountId = :context.household.Id
                ORDER BY LastModifiedDate DESC
                LIMIT :MAX_CASES
            ];
        }
        List<CaseSummary> summaries = new List<CaseSummary>();
        for (Case c : cases) {
            CaseSummary summary = new CaseSummary();
            summary.id = c.Id;
            summary.caseNumber = c.CaseNumber;
            summary.subject = c.Subject;
            summary.status = c.Status;
            summary.priority = c.Priority;
            summary.lastModifiedDate = c.LastModifiedDate;
            summary.ownerName = c.Owner != null ? c.Owner.Name : null;
            summaries.add(summary);
        }
        return summaries;
    }

    private static List<OpportunitySummary> loadOpportunities(HouseholdContext context) {
        List<Opportunity> opportunities = [
            SELECT Id, Name, StageName, Amount, CloseDate, Type, Owner.Name
            FROM Opportunity
            WHERE AccountId = :context.household.Id
            ORDER BY CloseDate DESC NULLS LAST
            LIMIT :MAX_OPPORTUNITIES
        ];
        List<OpportunitySummary> summaries = new List<OpportunitySummary>();
        for (Opportunity opp : opportunities) {
            OpportunitySummary summary = new OpportunitySummary();
            summary.id = opp.Id;
            summary.name = opp.Name;
            summary.stage = opp.StageName;
            summary.amount = opp.Amount;
            summary.closeDate = opp.CloseDate;
            summary.type = opp.Type;
            summary.ownerName = opp.Owner != null ? opp.Owner.Name : null;
            summaries.add(summary);
        }
        return summaries;
    }

    private static List<ServiceRequestSummary> loadServiceRequests(HouseholdContext context) {
        if (!context.hasServiceRequestObject || String.isBlank(context.serviceRequestHouseholdField)) {
            return new List<ServiceRequestSummary>();
        }
        String hhId = String.escapeSingleQuotes((String) context.household.Id);
        List<String> selectFields = SchemaInspector.filterExistingFields('FinServ__ServiceRequest__c', new List<String>{
            'Id', 'Name', 'FinServ__Status__c', 'FinServ__RequestType__c', 'FinServ__RequestSubType__c',
            'FinServ__DueDate__c', 'FinServ__Priority__c', 'LastModifiedDate'
        });
        if (!selectFields.contains(context.serviceRequestHouseholdField)) {
            selectFields.add(context.serviceRequestHouseholdField);
        }
        if (!selectFields.contains('Owner.Name')) {
            selectFields.add('Owner.Name');
        }
        String soql = 'SELECT ' + String.join(selectFields, ', ') +
            ' FROM FinServ__ServiceRequest__c WHERE ' + context.serviceRequestHouseholdField + ' = \'' + hhId + '\' ' +
            'ORDER BY LastModifiedDate DESC LIMIT ' + MAX_SERVICE_REQUESTS;
        List<SObject> rows = Database.query(soql);
        List<ServiceRequestSummary> summaries = new List<ServiceRequestSummary>();
        for (SObject row : rows) {
            ServiceRequestSummary summary = new ServiceRequestSummary();
            summary.id = (Id) row.get('Id');
            summary.name = (String) row.get('Name');
            summary.status = (String) row.get('FinServ__Status__c');
            summary.type = (String) row.get('FinServ__RequestType__c');
            summary.subType = (String) row.get('FinServ__RequestSubType__c');
            summary.dueDate = (Date) row.get('FinServ__DueDate__c');
            summary.priority = (String) row.get('FinServ__Priority__c');
            summary.lastUpdated = (Datetime) row.get('LastModifiedDate');
            SObject owner = row.getSObject('Owner');
            summary.ownerName = owner != null ? (String) owner.get('Name') : null;
            summaries.add(summary);
        }
        return summaries;
    }

    private static List<ActionPlanSummary> loadActionPlans(HouseholdContext context) {
        if (!context.hasActionPlanObject || String.isBlank(context.actionPlanHouseholdField)) {
            return new List<ActionPlanSummary>();
        }
        String hhId = String.escapeSingleQuotes((String) context.household.Id);
        List<String> selectFields = SchemaInspector.filterExistingFields('FinServ__ActionPlan__c', new List<String>{
            'Id', 'Name', 'FinServ__Status__c', 'FinServ__Type__c', 'FinServ__TargetCompletionDate__c',
            'FinServ__CompletionPercentage__c', 'LastModifiedDate'
        });
        if (!selectFields.contains(context.actionPlanHouseholdField)) {
            selectFields.add(context.actionPlanHouseholdField);
        }
        if (!selectFields.contains('FinServ__ActionPlanTemplate__r.Name')) {
            selectFields.add('FinServ__ActionPlanTemplate__r.Name');
        }
        if (!selectFields.contains('Owner.Name')) {
            selectFields.add('Owner.Name');
        }
        String soql = 'SELECT ' + String.join(selectFields, ', ') +
            ' FROM FinServ__ActionPlan__c WHERE ' + context.actionPlanHouseholdField + ' = \'' + hhId + '\' ' +
            'ORDER BY LastModifiedDate DESC LIMIT ' + MAX_ACTION_PLANS;
        List<SObject> rows = Database.query(soql);
        List<ActionPlanSummary> summaries = new List<ActionPlanSummary>();
        for (SObject row : rows) {
            ActionPlanSummary summary = new ActionPlanSummary();
            summary.id = (Id) row.get('Id');
            summary.name = (String) row.get('Name');
            summary.status = (String) row.get('FinServ__Status__c');
            summary.type = (String) row.get('FinServ__Type__c');
            summary.targetCompletionDate = (Date) row.get('FinServ__TargetCompletionDate__c');
            summary.completionPercent = (Decimal) row.get('FinServ__CompletionPercentage__c');
            SObject template = row.getSObject('FinServ__ActionPlanTemplate__r');
            summary.templateName = template != null ? (String) template.get('Name') : null;
            SObject owner = row.getSObject('Owner');
            summary.ownerName = owner != null ? (String) owner.get('Name') : null;
            summaries.add(summary);
        }
        return summaries;
    }

    private static List<CommunicationSummary> loadEmails(HouseholdContext context) {
        List<CommunicationSummary> communications = new List<CommunicationSummary>();
        if (!SchemaInspector.objectExists('EmailMessage')) {
            return communications;
        }
        String hhId = String.escapeSingleQuotes((String) context.household.Id);
        List<String> filters = new List<String>();
        filters.add('ParentId = \'' + hhId + '\'');
        if (!context.memberContactIds.isEmpty()) {
            filters.add('RelatedToId IN (' + SchemaInspector.joinIds(context.memberContactIds) + ')');
        }
        if (!context.memberEmails.isEmpty()) {
            String emailSet = SchemaInspector.joinEmails(context.memberEmails);
            filters.add('(FromAddress IN (' + emailSet + ') OR ToAddress IN (' + emailSet + '))');
        }
        String whereClause = '(' + String.join(filters, ' OR ') + ')';
        String soql = 'SELECT Id, Subject, Status, MessageDate, FromAddress, ToAddress, Incoming, ParentId ' +
            'FROM EmailMessage WHERE ' + whereClause +
            ' ORDER BY MessageDate DESC NULLS LAST LIMIT ' + MAX_EMAILS;
        List<EmailMessage> emails = Database.query(soql);
        for (EmailMessage email : emails) {
            CommunicationSummary summary = new CommunicationSummary();
            summary.id = email.Id;
            summary.subject = email.Subject;
            summary.status = email.Status;
            summary.direction = email.Incoming ? 'Inbound' : 'Outbound';
            summary.messageDate = email.MessageDate;
            summary.fromAddress = email.FromAddress;
            summary.toAddress = email.ToAddress;
            summary.parentId = email.ParentId;
            communications.add(summary);
        }
        return communications;
    }

    private static List<InteractionSummary> loadInteractionSummaries(HouseholdContext context) {
        if (!context.hasInteractionSummaryObject || String.isBlank(context.interactionHouseholdField)) {
            return new List<InteractionSummary>();
        }
        String hhId = String.escapeSingleQuotes((String) context.household.Id);
        List<String> selectFields = SchemaInspector.filterExistingFields('FinServ__InteractionSummary__c', new List<String>{
            'Id', 'Name', 'FinServ__Summary__c', 'FinServ__InteractionDate__c', 'FinServ__InteractionChannel__c',
            'FinServ__InteractionType__c', 'FinServ__Outcome__c', 'FinServ__PrimaryContact__c', 'LastModifiedDate'
        });
        if (!selectFields.contains(context.interactionHouseholdField)) {
            selectFields.add(context.interactionHouseholdField);
        }
        if (!selectFields.contains('Owner.Name')) {
            selectFields.add('Owner.Name');
        }
        if (!selectFields.contains('FinServ__PrimaryContact__r.Name')) {
            selectFields.add('FinServ__PrimaryContact__r.Name');
        }
        String soql = 'SELECT ' + String.join(selectFields, ', ') +
            ' FROM FinServ__InteractionSummary__c WHERE ' + context.interactionHouseholdField + ' = \'' + hhId + '\' ' +
            'ORDER BY ' + (selectFields.contains('FinServ__InteractionDate__c') ? 'FinServ__InteractionDate__c' : 'LastModifiedDate') + ' DESC ' +
            'LIMIT ' + MAX_INTERACTIONS;
        List<SObject> rows = Database.query(soql);
        List<InteractionSummary> summaries = new List<InteractionSummary>();
        for (SObject row : rows) {
            InteractionSummary summary = new InteractionSummary();
            summary.id = (Id) row.get('Id');
            summary.subject = (String) row.get('Name');
            summary.summary = (String) row.get('FinServ__Summary__c');
            summary.interactionDate = (Datetime) row.get('FinServ__InteractionDate__c');
            summary.channel = (String) row.get('FinServ__InteractionChannel__c');
            summary.interactionType = (String) row.get('FinServ__InteractionType__c');
            summary.outcome = (String) row.get('FinServ__Outcome__c');
            SObject owner = row.getSObject('Owner');
            summary.ownerName = owner != null ? (String) owner.get('Name') : null;
            summary.primaryContactId = (Id) row.get('FinServ__PrimaryContact__c');
            SObject primary = row.getSObject('FinServ__PrimaryContact__r');
            summary.primaryContactName = primary != null ? (String) primary.get('Name') : null;
            summaries.add(summary);
        }
        return summaries;
    }

    // ----- Context & schema helpers -----

    private class HouseholdContext {
        Id householdId;
        Account household;
        Set<Id> memberContactIds = new Set<Id>();
        Set<String> memberEmails = new Set<String>();
        Boolean hasHouseholdMemberObject;
        Boolean hasFinancialAccountObject;
        Boolean hasFinancialGoalObject;
        Boolean hasServiceRequestObject;
        Boolean hasActionPlanObject;
        Boolean hasInteractionSummaryObject;
        String financialAccountOwnerField;
        String goalHouseholdField;
        String serviceRequestHouseholdField;
        String actionPlanHouseholdField;
        String interactionHouseholdField;

        static HouseholdContext build(Id householdId) {
            if (householdId == null) {
                throw new HouseholdDataException('A household Id is required.');
            }
            HouseholdContext context = new HouseholdContext();
            context.householdId = householdId;
            if (householdId.getSObjectType() != Account.SObjectType) {
                throw new HouseholdDataException('Household Id must reference an Account.');
            }
            context.household = queryHouseholdAccount(householdId);
            context.hasHouseholdMemberObject = SchemaInspector.objectExists('FinServ__HouseholdMember__c');
            context.hasFinancialAccountObject = SchemaInspector.objectExists('FinServ__FinancialAccount__c');
            context.hasFinancialGoalObject = SchemaInspector.objectExists('FinServ__FinancialGoal__c');
            context.hasServiceRequestObject = SchemaInspector.objectExists('FinServ__ServiceRequest__c');
            context.hasActionPlanObject = SchemaInspector.objectExists('FinServ__ActionPlan__c');
            context.hasInteractionSummaryObject = SchemaInspector.objectExists('FinServ__InteractionSummary__c');
            context.financialAccountOwnerField = SchemaInspector.firstExistingField('FinServ__FinancialAccount__c', new List<String>{
                'FinServ__PrimaryOwner__c', 'FinServ__Household__c', 'FinServ__FinancialAccountOwner__c'
            });
            context.goalHouseholdField = SchemaInspector.firstExistingField('FinServ__FinancialGoal__c', new List<String>{
                'FinServ__Household__c', 'FinServ__Account__c', 'FinServ__PrimaryGroup__c'
            });
            context.serviceRequestHouseholdField = SchemaInspector.firstExistingField('FinServ__ServiceRequest__c', new List<String>{
                'FinServ__Household__c', 'FinServ__Account__c', 'FinServ__PrimaryGroup__c'
            });
            context.actionPlanHouseholdField = SchemaInspector.firstExistingField('FinServ__ActionPlan__c', new List<String>{
                'FinServ__Household__c', 'FinServ__Account__c', 'FinServ__PrimaryGroup__c'
            });
            context.interactionHouseholdField = SchemaInspector.firstExistingField('FinServ__InteractionSummary__c', new List<String>{
                'FinServ__Household__c', 'FinServ__Account__c', 'FinServ__PrimaryGroup__c'
            });
            return context;
        }
    }

    private static Account queryHouseholdAccount(Id householdId) {
        List<String> requestedFields = new List<String>{
            'Id','Name','Type','Phone','BillingStreet','BillingCity','BillingState','BillingPostalCode','BillingCountry','LastActivityDate'
        };
        if (SchemaInspector.fieldExists('Account', 'FinServ__LifecycleStage__c')) {
            requestedFields.add('FinServ__LifecycleStage__c');
        }
        if (SchemaInspector.fieldExists('Account', 'FinServ__PreferredChannel__c')) {
            requestedFields.add('FinServ__PreferredChannel__c');
        }
        if (SchemaInspector.fieldExists('Account', 'FinServ__TotalAssets__c')) {
            requestedFields.add('FinServ__TotalAssets__c');
        }
        if (SchemaInspector.fieldExists('Account', 'FinServ__ClientTier__c')) {
            requestedFields.add('FinServ__ClientTier__c');
        }
        String selectFields = String.join(requestedFields, ', ');
        String soql = 'SELECT ' + selectFields + ', Owner.Id, Owner.Name, RecordType.Id, RecordType.DeveloperName FROM Account WHERE Id = :householdId LIMIT 1';
        List<Account> households = Database.query(soql);
        if (households.isEmpty()) {
            throw new HouseholdDataException('Unable to find household Account ' + householdId);
        }
        return households[0];
    }

    private static class SchemaInspector {
        static Boolean objectExists(String apiName) {
            return Schema.getGlobalDescribe().containsKey(apiName);
        }

        static Boolean fieldExists(String objectApiName, String fieldApiName) {
            if (!objectExists(objectApiName)) {
                return false;
            }
            Map<String, Schema.SObjectField> fields = Schema.getGlobalDescribe().get(objectApiName).getDescribe().fields.getMap();
            return fields.containsKey(fieldApiName);
        }

        static List<String> filterExistingFields(String objectApiName, List<String> fieldApiNames) {
            List<String> filtered = new List<String>();
            if (!objectExists(objectApiName)) {
                return filtered;
            }
            Map<String, Schema.SObjectField> fields = Schema.getGlobalDescribe().get(objectApiName).getDescribe().fields.getMap();
            for (String fieldApiName : fieldApiNames) {
                if (fields.containsKey(fieldApiName)) {
                    filtered.add(fieldApiName);
                }
            }
            return filtered;
        }

        static String joinIds(Set<Id> ids) {
            List<String> values = new List<String>();
            for (Id value : ids) {
                values.add('\'' + String.escapeSingleQuotes((String) value) + '\'');
            }
            return String.join(values, ',');
        }

        static String joinEmails(Set<String> emails) {
            List<String> values = new List<String>();
            for (String email : emails) {
                values.add('\'' + String.escapeSingleQuotes(email) + '\'');
            }
            return String.join(values, ',');
        }

        static String firstExistingField(String objectApiName, List<String> candidateFields) {
            for (String fieldApiName : candidateFields) {
                if (fieldExists(objectApiName, fieldApiName)) {
                    return fieldApiName;
                }
            }
            return null;
        }
    }
}
