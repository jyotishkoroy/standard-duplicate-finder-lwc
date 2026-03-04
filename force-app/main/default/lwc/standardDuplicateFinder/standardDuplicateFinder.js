import { LightningElement, track } from 'lwc';
import scan from '@salesforce/apex/StandardDuplicateFinderController.scan';
import getVersionInfo from '@salesforce/apex/StandardDuplicateFinderController.getVersionInfo';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { NavigationMixin } from 'lightning/navigation';

const DEFAULTS = Object.freeze({
    objectApiName: 'Contact',
    scope: 'LAST_90_DAYS',
    recordLimit: 5000,
    phoneLastDigits: 7,
    matchEmail: true,
    matchPhone: true,
    matchName: false,
    maxGroups: 200
});

export default class StandardDuplicateFinder extends NavigationMixin(LightningElement) {
    objectApiName = DEFAULTS.objectApiName;
    scope = DEFAULTS.scope;
    recordLimit = DEFAULTS.recordLimit;
    phoneLastDigits = DEFAULTS.phoneLastDigits;

    matchEmail = DEFAULTS.matchEmail;
    matchPhone = DEFAULTS.matchPhone;
    matchName = DEFAULTS.matchName;

    isBusy = false;
    errorMessage = '';

    @track results = null;
    @track metrics = { scanned: 0, groups: 0, recordsInGroups: 0 };
    @track versionInfo = { version: '1.0.0' };

    recordColumns = [
        { label: 'Name', fieldName: 'name', type: 'text', wrapText: true },
        { label: 'Email', fieldName: 'email', type: 'email' },
        { label: 'Phone', fieldName: 'phone', type: 'phone' },
        { label: 'Created', fieldName: 'createdDate', type: 'date', typeAttributes: { year: 'numeric', month: 'short', day: '2-digit' } },
        { label: 'Owner', fieldName: 'ownerName', type: 'text' },
        { type: 'action', typeAttributes: { rowActions: this.getRowActions } }
    ];

    connectedCallback() {
        getVersionInfo()
            .then((info) => { this.versionInfo = info; })
            .catch(() => { /* non-blocking */ });
    }

    get objectOptions() {
        return [{ label: 'Contact', value: 'Contact' }, { label: 'Lead', value: 'Lead' }];
    }

    get scopeOptions() {
        return [
            { label: 'Last 30 days', value: 'LAST_30_DAYS' },
            { label: 'Last 90 days', value: 'LAST_90_DAYS' },
            { label: 'Last 365 days', value: 'LAST_365_DAYS' }
        ];
    }

    get hasResults() {
        return this.results && Array.isArray(this.results.groups) && this.results.groups.length > 0;
    }

    get scanDisabled() {
        return this.isBusy || !(this.matchEmail || this.matchPhone || this.matchName);
    }

    handleObjectChange(e) { this.objectApiName = e.detail.value; }
    handleScopeChange(e) { this.scope = e.detail.value; }

    handleLimitChange(e) {
        const v = parseInt(e.detail.value, 10);
        this.recordLimit = Number.isFinite(v) ? v : DEFAULTS.recordLimit;
    }

    handlePhoneDigitsChange(e) {
        const v = parseInt(e.detail.value, 10);
        this.phoneLastDigits = Number.isFinite(v) ? v : DEFAULTS.phoneLastDigits;
    }

    toggleEmail(e) { this.matchEmail = e.target.checked; }
    togglePhone(e) { this.matchPhone = e.target.checked; }
    toggleName(e) { this.matchName = e.target.checked; }

    handleReset() {
        if (this.isBusy) return;
        Object.assign(this, { ...DEFAULTS });
        this.errorMessage = '';
        this.results = null;
        this.metrics = { scanned: 0, groups: 0, recordsInGroups: 0 };
    }

    async handleScan() {
        if (this.scanDisabled) return;

        this.isBusy = true;
        this.errorMessage = '';

        try {
            const req = {
                objectApiName: this.objectApiName,
                scope: this.scope,
                recordLimit: this.recordLimit,
                phoneLastDigits: this.phoneLastDigits,
                matchEmail: this.matchEmail,
                matchPhone: this.matchPhone,
                matchName: this.matchName,
                maxGroups: DEFAULTS.maxGroups
            };

            const resp = await scan({ req });
            this.results = this.decorate(resp);
            this.metrics = {
                scanned: resp.scannedCount || 0,
                groups: resp.groupCount || 0,
                recordsInGroups: resp.recordCountInGroups || 0
            };

            this.toast('Scan complete', this.hasResults ? `Found ${this.metrics.groups} duplicate groups.` : 'No duplicate groups found.', this.hasResults ? 'success' : 'info');
        } catch (err) {
            const msg = this.extractError(err);
            this.errorMessage = msg;
            this.toast('Scan failed', msg, 'error');
        } finally {
            this.isBusy = false;
        }
    }

    decorate(resp) {
        const groups = (resp.groups || []).map((g, idx) => ({
            ...g,
            uid: `${g.matchType}-${idx}-${Math.random().toString(16).slice(2)}`,
            pillClass: this.pillClass(g.matchType),
            records: (g.records || []).map((r) => ({ ...r }))
        }));
        return { ...resp, groups };
    }

    pillClass(type) {
        switch (type) {
            case 'EMAIL': return 'sdf-pill sdf-pill--email';
            case 'PHONE': return 'sdf-pill sdf-pill--phone';
            case 'NAME': return 'sdf-pill sdf-pill--name';
            default: return 'sdf-pill';
        }
    }

    get groupedByType() {
        if (!this.hasResults) return [];
        const by = { EMAIL: [], PHONE: [], NAME: [] };
        for (const g of this.results.groups) if (by[g.matchType]) by[g.matchType].push(g);

        const out = [];
        if (by.EMAIL.length) out.push({ type: 'EMAIL', label: `Email matches (${by.EMAIL.length})`, groups: by.EMAIL });
        if (by.PHONE.length) out.push({ type: 'PHONE', label: `Phone matches (${by.PHONE.length})`, groups: by.PHONE });
        if (by.NAME.length) out.push({ type: 'NAME', label: `Name matches (${by.NAME.length})`, groups: by.NAME });
        return out;
    }

    getRowActions(row, done) { done([{ label: 'Open record', name: 'open' }]); }

    handleRowAction(e) {
        const { action, row } = e.detail;
        if (action.name === 'open') {
            this[NavigationMixin.Navigate]({ type: 'standard__recordPage', attributes: { recordId: row.id, actionName: 'view' } });
        }
    }

    exportCsv() {
        if (!this.hasResults) return;

        const lines = [];
        lines.push(['MatchType', 'Key', 'RecordId', 'Name', 'Email', 'Phone', 'CreatedDate', 'Owner'].join(','));

        for (const g of this.results.groups) {
            for (const r of g.records || []) {
                lines.push([
                    this.csv(g.matchType),
                    this.csv(g.key),
                    this.csv(r.id),
                    this.csv(r.name),
                    this.csv(r.email),
                    this.csv(r.phone),
                    this.csv(r.createdDate),
                    this.csv(r.ownerName)
                ].join(','));
            }
        }

        const blob = new Blob([lines.join('\n')], { type: 'text/csv;charset=utf-8;' });
        const url = URL.createObjectURL(blob);

        const a = document.createElement('a');
        a.href = url;
        a.download = `duplicate-finder-${this.objectApiName.toLowerCase()}-${new Date().toISOString().slice(0, 10)}.csv`;
        a.click();

        URL.revokeObjectURL(url);
        this.toast('Exported', 'CSV downloaded.', 'success');
    }

    csv(v) {
        const s = v === null || v === undefined ? '' : String(v);
        return `"${s.replace(/"/g, '""')}"`;
    }

    extractError(e) {
        if (e?.body?.message) return e.body.message;
        if (e?.message) return e.message;
        return 'Unexpected error. Check your permissions and try again.';
    }

    toast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}
