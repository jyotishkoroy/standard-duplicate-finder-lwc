/**
 * Standard Duplicate Finder (Contacts & Leads)
 * Controller for LWC: scans Contact/Lead records and groups likely duplicates using simple heuristics.
 *
 * Design goals:
 *  - No custom objects / no writes
 *  - Predictable governor usage via scope + record limit
 *  - Strong error messages for missing perms / FLS
 *
 * Copyright 2026 Jyotishko Roy (https://orcid.org/0009-0000-2837-4731)
 * Licensed under the Apache License, Version 2.0.
 */
public with sharing class StandardDuplicateFinderController {

    public class ScanRequest {
        @AuraEnabled public String objectApiName; // 'Contact' or 'Lead'
        @AuraEnabled public Boolean matchEmail;
        @AuraEnabled public Boolean matchPhone;
        @AuraEnabled public Boolean matchName;

        @AuraEnabled public String scope; // 'LAST_30_DAYS' | 'LAST_90_DAYS' | 'LAST_365_DAYS'
        @AuraEnabled public Integer recordLimit; // max records to scan
        @AuraEnabled public Integer phoneLastDigits; // last N digits for phone key
        @AuraEnabled public Integer maxGroups; // cap groups returned per match type

        public void applyDefaults() {
            if (matchEmail == null) matchEmail = true;
            if (matchPhone == null) matchPhone = true;
            if (matchName == null) matchName = false;

            if (String.isBlank(scope)) scope = 'LAST_90_DAYS';

            if (recordLimit == null || recordLimit <= 0) recordLimit = 5000;
            if (recordLimit > 10000) recordLimit = 10000; // guardrail

            if (phoneLastDigits == null || phoneLastDigits <= 0) phoneLastDigits = 7;

            if (maxGroups == null || maxGroups <= 0) maxGroups = 200;
            if (maxGroups > 500) maxGroups = 500;
        }
    }

    public class RecordRow {
        @AuraEnabled public Id id;
        @AuraEnabled public String name;
        @AuraEnabled public String email;
        @AuraEnabled public String phone;
        @AuraEnabled public Datetime createdDate;
        @AuraEnabled public String ownerName;
    }

    public class DupGroup {
        @AuraEnabled public String matchType; // EMAIL | PHONE | NAME
        @AuraEnabled public String key;
        @AuraEnabled public Integer count;
        @AuraEnabled public List<RecordRow> records;
    }

    public class ScanResponse {
        @AuraEnabled public Integer scannedCount;
        @AuraEnabled public Integer groupCount;
        @AuraEnabled public Integer recordCountInGroups;
        @AuraEnabled public List<DupGroup> groups;
    }

    @AuraEnabled(cacheable=true)
    public static Map<String, String> getVersionInfo() {
        Map<String, String> info = new Map<String, String>();
        info.put('name', 'Standard Duplicate Finder (Contacts & Leads)');
        info.put('version', '1.0.0');
        info.put('author', 'Jyotishko Roy');
        info.put('orcid', 'https://orcid.org/0009-0000-2837-4731');
        return info;
    }

    @AuraEnabled
    public static ScanResponse scan(ScanRequest req) {
        if (req == null) req = new ScanRequest();
        req.applyDefaults();

        if (req.objectApiName != 'Contact' && req.objectApiName != 'Lead') {
            throw new AuraHandledException('Unsupported object. Choose Contact or Lead.');
        }
        if (!(req.matchEmail || req.matchPhone || req.matchName)) {
            throw new AuraHandledException('Select at least one match signal (Email, Phone, or Name).');
        }

        List<SObject> rows = queryRecords(req);
        ScanResponse resp = new ScanResponse();
        resp.scannedCount = rows.size();

        List<DupGroup> outGroups = new List<DupGroup>();
        Integer recordCountInGroups = 0;

        if (req.matchEmail) outGroups.addAll(buildGroups(rows, 'EMAIL', req.maxGroups, req.phoneLastDigits));
        if (req.matchPhone) outGroups.addAll(buildGroups(rows, 'PHONE', req.maxGroups, req.phoneLastDigits));
        if (req.matchName) outGroups.addAll(buildGroups(rows, 'NAME', req.maxGroups, req.phoneLastDigits));

        outGroups.sort(new DupGroupSorter());

        for (DupGroup g : outGroups) {
            recordCountInGroups += g.records.size();
        }

        resp.groups = outGroups;
        resp.groupCount = outGroups.size();
        resp.recordCountInGroups = recordCountInGroups;
        return resp;
    }

    private static List<SObject> queryRecords(ScanRequest req) {
        Integer lim = req.recordLimit;

        try {
            if (req.objectApiName == 'Contact') {
                if (req.scope == 'LAST_30_DAYS') {
                    return [
                        SELECT Id, Name, Email, Phone, CreatedDate, Owner.Name
                        FROM Contact
                        WHERE CreatedDate = LAST_N_DAYS:30
                        ORDER BY CreatedDate DESC
                        LIMIT :lim
                    ];
                } else if (req.scope == 'LAST_365_DAYS') {
                    return [
                        SELECT Id, Name, Email, Phone, CreatedDate, Owner.Name
                        FROM Contact
                        WHERE CreatedDate = LAST_N_DAYS:365
                        ORDER BY CreatedDate DESC
                        LIMIT :lim
                    ];
                }
                // default LAST_90_DAYS
                return [
                    SELECT Id, Name, Email, Phone, CreatedDate, Owner.Name
                    FROM Contact
                    WHERE CreatedDate = LAST_N_DAYS:90
                    ORDER BY CreatedDate DESC
                    LIMIT :lim
                ];
            } else {
                if (req.scope == 'LAST_30_DAYS') {
                    return [
                        SELECT Id, Name, Email, Phone, CreatedDate, Owner.Name
                        FROM Lead
                        WHERE CreatedDate = LAST_N_DAYS:30
                        ORDER BY CreatedDate DESC
                        LIMIT :lim
                    ];
                } else if (req.scope == 'LAST_365_DAYS') {
                    return [
                        SELECT Id, Name, Email, Phone, CreatedDate, Owner.Name
                        FROM Lead
                        WHERE CreatedDate = LAST_N_DAYS:365
                        ORDER BY CreatedDate DESC
                        LIMIT :lim
                    ];
                }
                return [
                    SELECT Id, Name, Email, Phone, CreatedDate, Owner.Name
                    FROM Lead
                    WHERE CreatedDate = LAST_N_DAYS:90
                    ORDER BY CreatedDate DESC
                    LIMIT :lim
                ];
            }
        } catch (Exception e) {
            throw new AuraHandledException(
                'Unable to query records. Check object/field permissions for ' + req.objectApiName +
                ' and ensure you have access to Email/Phone/Name fields. Details: ' + e.getMessage()
            );
        }
    }

    private static List<DupGroup> buildGroups(
        List<SObject> rows,
        String matchType,
        Integer maxGroups,
        Integer phoneLastDigits
    ) {
        Map<String, List<RecordRow>> byKey = new Map<String, List<RecordRow>>();

        for (SObject s : rows) {
            RecordRow r = toRow(s);

            String k;
            if (matchType == 'EMAIL') {
                k = DupFinderNormalize.normalizeEmail(r.email);
            } else if (matchType == 'PHONE') {
                k = DupFinderNormalize.phoneKey(r.phone, phoneLastDigits);
            } else if (matchType == 'NAME') {
                k = DupFinderNormalize.normalizeName(r.name);
            } else {
                continue;
            }

            if (String.isBlank(k)) continue;
            if (!byKey.containsKey(k)) byKey.put(k, new List<RecordRow>());
            byKey.get(k).add(r);
        }

        List<DupGroup> groups = new List<DupGroup>();
        for (String k : byKey.keySet()) {
            List<RecordRow> listRows = byKey.get(k);
            if (listRows == null || listRows.size() < 2) continue;

            listRows.sort(new RowSorter());

            DupGroup g = new DupGroup();
            g.matchType = matchType;
            g.key = k;
            g.count = listRows.size();
            g.records = listRows;
            groups.add(g);
        }

        groups.sort(new GroupSorter());

        if (groups.size() > maxGroups) groups = groups.subList(0, maxGroups);
        return groups;
    }

    private static RecordRow toRow(SObject s) {
        RecordRow r = new RecordRow();
        r.id = (Id)s.get('Id');
        r.createdDate = (Datetime)s.get('CreatedDate');

        SObject owner = (SObject)s.getSObject('Owner');
        r.ownerName = owner != null ? (String)owner.get('Name') : null;

        r.name = (String)s.get('Name');
        r.email = (String)s.get('Email');
        r.phone = (String)s.get('Phone');
        return r;
    }

    // ---- Sorters ----

    private class GroupSorter implements Comparator<DupGroup> {
        public Integer compare(DupGroup a, DupGroup b) {
            Integer ac = a != null && a.count != null ? a.count : 0;
            Integer bc = b != null && b.count != null ? b.count : 0;
            if (ac == bc) return (a != null ? a.matchType : '').compareTo(b != null ? b.matchType : '');
            return bc - ac; // desc
        }
    }

    private class DupGroupSorter implements Comparator<DupGroup> {
        public Integer compare(DupGroup a, DupGroup b) {
            Integer ac = a != null && a.count != null ? a.count : 0;
            Integer bc = b != null && b.count != null ? b.count : 0;
            if (ac != bc) return bc - ac;
            Integer t = (a != null ? a.matchType : '').compareTo(b != null ? b.matchType : '');
            if (t != 0) return t;
            return (a != null ? a.key : '').compareTo(b != null ? b.key : '');
        }
    }

    private class RowSorter implements Comparator<RecordRow> {
        public Integer compare(RecordRow a, RecordRow b) {
            Datetime ad = a != null ? a.createdDate : null;
            Datetime bd = b != null ? b.createdDate : null;
            if (ad != null && bd != null && ad != bd) return ad.getTime() < bd.getTime() ? -1 : 1;
            return (a != null ? a.name : '').compareTo(b != null ? b.name : '');
        }
    }
}
