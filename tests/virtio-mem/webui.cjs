// Execute the patched upstream editor, not a second implementation of it.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const source = fs.readFileSync(process.argv[2], 'utf8');
const classes = {};
const Ext = {
    define: (name, definition) => { classes[name] = definition; },
    isDefined: value => value !== undefined,
    apply: Object.assign,
    each: (values, fn) => values.forEach(fn),
};
const Proxmox = { Utils: { defaultText: 'Default', format_size: bytes => `${bytes / 1048576} MiB` } };
const context = { Ext, Proxmox, gettext: value => value };
for (const name of ['PVE.qemu.MemoryInputPanel', 'PVE.qemu.MemoryEdit']) {
    const start = source.indexOf(`Ext.define('${name}',`);
    assert(start >= 0, `upstream class ${name} exists`);
    const end = source.indexOf('Ext.define(', start + 12);
    vm.runInNewContext(source.slice(start, end < 0 ? undefined : end), context);
}

function panel(insideWizard = false) {
    const fields = {};
    const result = Object.assign({}, classes['PVE.qemu.MemoryInputPanel'], {
        insideWizard,
        callParent() {},
        down(selector) { return fields[selector.match(/name=([^\]]+)/)[1]]; },
    });
    result.initComponent();
    const items = [...(result.items || result.column1), ...(result.advancedItems || result.advancedColumn1)];
    for (const config of items.filter(item => item.name)) {
        fields[config.name] = {
            ...config,
            current: config.name === 'ballooning' ? true : config.value,
            validations: 0,
            getValue() { return this.current; },
            setValue(value) {
                const old = this.current;
                this.current = value;
                this.listeners?.change?.(this, value, old);
            },
            setMaxValue(value) { this.maxValue = value; },
            setDisabled(value) { this.disabled = value; },
            validate() { this.validations++; return this.validator?.() ?? true; },
        };
    }
    result.fields = fields;
    result.setValues = values => {
        for (const [name, value] of Object.entries(values)) {
            if (fields[name]) fields[name].setValue(name === 'ballooning'
                ? ![false, 0, '0'].includes(value) : value);
        }
    };
    return result;
}

const values = { memory: 16384, balloon: 4096, 'virtio-mem': 12288, shares: 1000, ballooning: true };
const edit = panel();
edit.setValues(values);
assert.equal(edit.fields['virtio-mem'].getValue(), 12288, 'pool is a visible primary field');
assert.equal(edit.validateVirtioMem(), true);
assert.equal(edit.onGetValues(values)['virtio-mem'], 12288, 'save passes pool to native API');
const disabled = edit.onGetValues({ ...values, 'virtio-mem': 0 });
assert(disabled.delete.split(',').includes('virtio-mem'), 'zero deletes pool');
assert(!('virtio-mem' in disabled));
const fixed = edit.onGetValues({ ...values, balloon: 16384 });
assert.equal(fixed['virtio-mem'], 12288, 'fixed allocation preserves pool');
assert(fixed.delete.split(',').includes('balloon'));
assert(fixed.delete.split(',').includes('shares'));
const ksm = edit.onGetValues({ ...values, delete: 'allow-ksm' });
assert(ksm.delete.split(',').includes('allow-ksm'), 'native KSM deletion is preserved');
assert.equal(edit.onGetValues({ ...values, shares: 0 }).shares, 0, 'manual scheduling is preserved');

for (const invalid of [
    { 'virtio-mem': 16384 }, { 'virtio-mem': 15872 }, { 'virtio-mem': -2 },
    { 'virtio-mem': 12287 }, { memory: 16385 }, { balloon: 4097 },
    { balloon: 2048 }, { balloon: 16386 }, { ballooning: false },
]) {
    edit.setValues({ ...values, ...invalid });
    assert.notEqual(edit.validateVirtioMem(), true, JSON.stringify(invalid));
}
edit.setValues({ ...values, 'virtio-mem': 0, ballooning: false });
assert.equal(edit.validateVirtioMem(), true, 'ordinary balloon-disabled VM remains valid');
edit.setValues(values);
const before = edit.fields['virtio-mem'].validations;
edit.fields.memory.setValue(8192);
assert(edit.fields['virtio-mem'].validations > before, 'maximum changes revalidate pool');
assert.notEqual(edit.fields['virtio-mem'].validate(), true);
edit.setValues(values);
edit.fields.ballooning.setValue(false);
assert.notEqual(edit.fields['virtio-mem'].validate(), true, 'balloon toggle revalidates pool');

const wizard = panel(true);
assert(!wizard.fields['virtio-mem'], 'create wizard is unchanged');
assert(!('virtio-mem' in wizard.onGetValues(values)));
assert(!wizard.onGetValues(values).delete?.split(',').includes('virtio-mem'));

function load(data) {
    let loaded;
    Ext.create = () => ({ setValues: values => { loaded = values; } });
    classes['PVE.qemu.MemoryEdit'].initComponent.call({
        callParent() {}, load: options => options.success({ result: { data } }),
    });
    return loaded;
}
assert.equal(load({ memory: 16384, 'virtio-mem': 12288 })['virtio-mem'], 12288);
assert.equal(load({ memory: 4096 })['virtio-mem'], 0, 'missing option loads as disabled');

// Evaluate the actual HardwareView row with the same current/pending lookup
// interface supplied by Proxmox.grid.PendingObjectGrid.
const hwStart = source.indexOf("Ext.define('PVE.qemu.HardwareView',");
const rowStart = source.indexOf('            memory: {', hwStart);
let rowEnd = source.indexOf('            sockets: {', rowStart);
if (rowEnd < 0) rowEnd = source.indexOf("            'allow-ksm': {", rowStart);
let pendingSeen;
const rowContext = {
    ...context,
    caps: { vms: { 'VM.Config.Memory': true } },
    me: { getObjectValue: (name, fallback, pending) => {
        pendingSeen = pending;
        return ({ memory: 16384, balloon: 4096, 'virtio-mem': pending ? 8192 : 12288 })[name] ?? fallback;
    } },
};
const row = vm.runInNewContext(`({${source.slice(rowStart, rowEnd)}})`, rowContext).memory;
assert(row.multiKey.includes('virtio-mem'), 'native pending display/revert includes pool');
assert.equal(row.editor, 'PVE.qemu.MemoryEdit');
assert.match(row.renderer(null, null, null, null, null, null, false), /virtio-mem=12288 MiB/);
assert.equal(pendingSeen, false);
assert.match(row.renderer(null, null, null, null, null, null, true), /virtio-mem=8192 MiB/);
assert.equal(pendingSeen, true);
rowContext.caps.vms['VM.Config.Memory'] = false;
assert.equal(vm.runInNewContext(`({${source.slice(rowStart, rowEnd)}})`, rowContext).memory.editor, undefined);
assert.match(source.slice(hwStart), /'virtio-mem': \{\s+visible: false,/);
console.log('Web UI: load, save, disable, validation, wizard, permissions and pending display passed');
