'use strict';
'require form';
'require view';
'require uci';
'require fs';
'require ui';
'require tools.momo as momo';

return view.extend({
    load: function () {
        return Promise.all([
            uci.load('momo'),
            momo.getPaths().then(async paths => ({
                paths,
                profiles: await momo.listProfiles(paths)
            }))
        ]);
    },
    render: function (data) {
        const subscriptions = uci.sections('momo', 'subscription');
        const { paths, profiles } = data[1];

        let m, s, o;
        let openedFile = null;
        let loadRevision = 0;
        let saveInProgress = null;

        m = new form.Map('momo');

        s = m.section(form.NamedSection, 'placeholder', 'placeholder', _('Editor'));

        o = s.option(form.ListValue, '_file', _('Choose File'));
        o.optional = true;

        for (const profile of profiles) {
            o.value(paths.profiles_dir + '/' + profile.name, _('File:') + profile.name);
        };

        for (const subscription of subscriptions) {
            o.value(paths.subscriptions_dir + '/' + subscription['.name'] + '.json', _('Subscription:') + subscription.name);
        };

        o.value(paths.run_profile_path, _('Profile for Startup'));

        o.write = function (section_id, formvalue) {
            return true;
        };
        o.onchange = async function (event, section_id, value) {
            const revision = ++loadRevision;
            const isCurrent = () => revision === loadRevision &&
                m.lookupOption('_file', section_id)[0].formvalue(section_id) === value;
            openedFile = null;
            m.lookupOption('_file_content', section_id)[0].getUIElement(section_id)?.setValue('');
            if (!value)
                return;

            try {
                if (saveInProgress)
                    await L.resolveDefault(saveInProgress);
                if (!isCurrent())
                    return;
                const content = await fs.read_direct(value);
                if (!isCurrent())
                    return;
                // Textareas normalize line endings. Compare the displayed text to avoid rewriting an unchanged file.
                const text = content.replace(/\r\n?/g, '\n');
                openedFile = { path: value, text };
                m.lookupOption('_file_content', section_id)[0].getUIElement(section_id)?.setValue(text);
            } catch (error) {
                if (isCurrent())
                    ui.addNotification(null, E('p', {}, [error.message]));
            }
        };

        o = s.option(form.TextValue, '_file_content');
        o.rows = 25;
        o.wrap = false;
        o.write = async function (section_id, formvalue) {
            const path = m.lookupOption('_file', section_id)[0].formvalue(section_id);
            if (!path)
                return;
            const file = openedFile;
            if (file?.path !== path)
                throw new Error(_('Open the selected file before saving.'));
            if (saveInProgress)
                throw new Error(_('A save is already in progress.'));
            if (file.text === formvalue)
                return;

            // A failed chunked write can leave the file changed. Require an explicit retry.
            file.text = null;
            saveInProgress = momo.writefile(path, formvalue);
            try {
                await saveInProgress;
                file.text = formvalue;
            } finally {
                saveInProgress = null;
            }
        };
        o.remove = function (section_id) {
            return this.write(section_id, '');
        };

        return m.render();
    },
    handleSaveApply: function (ev, mode) {
        return this.handleSave(ev).then(function () {
            return mode === '0' ? momo.reload() : momo.restart();
        });
    },
    handleReset: null
});
