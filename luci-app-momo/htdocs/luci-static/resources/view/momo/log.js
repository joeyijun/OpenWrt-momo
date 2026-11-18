'use strict';
'require form';
'require view';
'require uci';
'require fs';
'require poll';
'require tools.momo as momo';

async function downloadLog(path, name) {
    const url = window.URL.createObjectURL(await fs.read_direct(path, 'blob'));
    const link = document.createElement('a');
    link.href = url;
    link.download = name;
    document.body.appendChild(link);
    link.click();
    link.remove();
    window.setTimeout(() => window.URL.revokeObjectURL(url), 0);
}

return view.extend({
    load: function () {
        return Promise.all([
            uci.load('momo'),
            momo.getPaths()
        ]);
    },
    render: function (data) {
        const paths = data[1];

        let m, s, o, root;

        m = new form.Map('momo');

        s = m.section(form.NamedSection, 'log', 'log', _('Log'));

        s.tab('log_config', _('Log Config'));
        
        o = s.taboption('log_config', form.Flag, 'clear_at_stop', _('Clear At Stop'));
        o.rmempty = false;
        
        o = s.taboption('log_config', form.Flag, 'scheduled_clear', _('Scheduled Clear'));
        o.rmempty = false;
        
        o = s.taboption('log_config', form.Value, 'scheduled_clear_cron', _('Scheduled Clear Cron'));
        o.retain = true;
        o.rmempty = false;
        o.depends('scheduled_clear', '1');

        o = s.taboption('log_config', form.Value, 'scheduled_clear_size_limit', _('Scheduled Clear Size Limit'));
        o.retain = true;
        o.rmempty = false;
        o.datatype = 'uinteger';
        o.depends('scheduled_clear', '1');

        o = s.taboption('log_config', form.ListValue, 'scheduled_clear_size_limit_unit', _('Scheduled Clear Size Limit Unit'));
        o.retain = true;
        o.rmempty = false;
        o.depends('scheduled_clear', '1');
        o.value('KB', 'KB');
        o.value('MB', 'MB');
        o.value('GB', 'GB');

        const logs = [
            { kind: 'app', title: _('App Log'), path: paths.app_log_path },
            { kind: 'core', title: _('Core Log'), path: paths.core_log_path }
        ];

        for (const log of logs) {
            const tab = log.kind + '_log';
            log.tab = tab;
            let clearing = false;
            let loading = false;
            let revision = 0;
            s.tab(tab, log.title);

            o = s.taboption(tab, form.Button, 'clear_' + tab);
            o.inputstyle = 'negative';
            o.inputtitle = _('Clear Log');
            o.onclick = async function (_, section_id) {
                if (clearing)
                    return;
                clearing = true;
                revision++;
                try {
                    await momo.writefile(log.path);
                    log.option.getUIElement(section_id)?.setValue('');
                } finally {
                    clearing = false;
                }
            };

            o = s.taboption(tab, form.TextValue, '_' + tab);
            o.description = _('Shows up to the latest 16 KiB of the log.');
            o.rows = 25;
            o.wrap = false;
            o.readonly = true;
            o.load = () => '';
            o.write = () => true;
            log.option = o;

            log.refresh = async function () {
                const visible = () => !document.hidden &&
                    root?.querySelector('[data-tab-title][data-tab="' + tab + '"]')
                        ?.getAttribute('data-tab-active') === 'true';
                if (!visible() || clearing || loading)
                    return;

                const requestedRevision = revision;
                loading = true;
                try {
                    const text = await L.resolveDefault(momo.getLogTail(log.kind), null);
                    if (text == null || revision !== requestedRevision || !visible())
                        return;
                    const element = log.option.getUIElement('log');
                    if (element && element.getValue() !== text)
                        element.setValue(text);
                } finally {
                    loading = false;
                }
            };

            o = s.taboption(tab, form.Button, 'scroll_' + tab + '_to_bottom');
            o.inputtitle = _('Scroll To Bottom');
            o.onclick = function (_, section_id) {
                const element = log.option.getUIElement(section_id).node.firstChild;
                element.scrollTop = element.scrollHeight;
            };

            o = s.taboption(tab, form.Button, 'download_' + tab);
            o.inputtitle = _('Download Full Log');
            o.onclick = () => downloadLog(log.path, log.kind + '.log');
        }

        s.tab('debug_log', _('Debug Log'));

        o = s.taboption('debug_log', form.Button, '_generate_download_debug_log');
        o.inputstyle = 'negative';
        o.inputtitle = _('Generate & Download');
        o.onclick = () => momo.debug().then(() => downloadLog(paths.debug_log_path, 'debug.log'));

        return m.render().then(function (node) {
            root = node;
            // Map.save() replaces the panes, so listen on the persistent map root.
            root.addEventListener('cbi-tab-active', function (event) {
                const log = logs.find(log => log.tab === event.detail?.tab);
                log?.refresh();
            }, true);
            poll.add(() => Promise.all(logs.map(log => log.refresh())));
            return node;
        });
    }
});
