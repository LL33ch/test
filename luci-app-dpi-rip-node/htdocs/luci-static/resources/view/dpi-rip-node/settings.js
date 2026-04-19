'use strict';
'require view';
'require form';
'require uci';
'require rpc';
'require ui';

var callCheck = rpc.declare({
	object: 'dpi-rip-node',
	method: 'check',
	expect: { result: '' }
});

var callRegister = rpc.declare({
	object: 'dpi-rip-node',
	method: 'register',
	expect: { result: '' }
});

var callStatus = rpc.declare({
	object: 'dpi-rip-node',
	method: 'status',
	expect: { running: false }
});

return view.extend({
	load: function() {
		return Promise.all([
			uci.load('dpi-rip-node'),
			callStatus()
		]);
	},

	render: function(data) {
		var isRunning = data[1] === true;
		var m, s, o;

		m = new form.Map('dpi-rip-node',
			_('DPI-RIP Node'),
			_('Monitoring agent that tests internet accessibility and reports results to the dpi-rip-panel.'));

		// ── Status ────────────────────────────────────────────────────────────

		s = m.section(form.NamedSection, 'settings', 'settings', _('Status'));
		s.anonymous = true;
		s.addremove = false;

		o = s.option(form.DummyValue, '_svc', _('Service'));
		o.renderWidget = function() {
			return E('span', {
				'style': isRunning
					? 'color:#28a745;font-weight:bold'
					: 'color:#dc3545;font-weight:bold'
			}, isRunning ? '● Running' : '● Stopped');
		};

		o = s.option(form.DummyValue, 'node_id', _('Node ID'));
		o.cfgvalue = function(sid) {
			var v = uci.get('dpi-rip-node', sid, 'node_id');
			return (v && v.length) ? v : _('(not registered yet)');
		};

		o = s.option(form.DummyValue, '_actions', _('Actions'));
		o.renderWidget = function() {
			return E('div', {}, [
				E('button', {
					'class': 'btn cbi-button cbi-button-action',
					'style': 'margin-right:6px',
					'click': function(ev) {
						var btn = ev.currentTarget;
						btn.disabled = true;
						callCheck().then(function() {
							ui.addNotification(null,
								E('p', _('Check cycle started in background')), 'info');
							btn.disabled = false;
						}, function(err) {
							ui.addNotification(null, E('p', String(err)), 'danger');
							btn.disabled = false;
						});
					}
				}, _('Run check now')),
				E('button', {
					'class': 'btn cbi-button cbi-button-neutral',
					'click': function(ev) {
						var btn = ev.currentTarget;
						btn.disabled = true;
						callRegister().then(function() {
							ui.addNotification(null,
								E('p', _('Re-registration complete — reload to see Node ID')), 'info');
							btn.disabled = false;
						}, function(err) {
							ui.addNotification(null, E('p', String(err)), 'danger');
							btn.disabled = false;
						});
					}
				}, _('Re-register'))
			]);
		};

		// ── Connection ────────────────────────────────────────────────────────

		s = m.section(form.NamedSection, 'settings', 'settings', _('Connection'));
		s.anonymous = true;
		s.addremove = false;

		o = s.option(form.Flag, 'enabled', _('Enabled'));
		o.rmempty = false;
		o.default = '1';

		o = s.option(form.Value, 'panel_url', _('Panel URL'),
			_('URL of the panel instance, without trailing slash'));
		o.placeholder = 'https://panel.example.com';
		o.rmempty = false;

		o = s.option(form.Value, 'api_key', _('API Key'),
			_('Issued by the panel when adding this node'));
		o.password = true;
		o.rmempty = false;

		// ── Parameters ────────────────────────────────────────────────────────

		s = m.section(form.NamedSection, 'settings', 'settings', _('Parameters'));
		s.anonymous = true;
		s.addremove = false;

		o = s.option(form.Value, 'interval', _('Check Interval'),
			_('Seconds between check cycles'));
		o.datatype = 'uinteger';
		o.placeholder = '300';

		o = s.option(form.Value, 'timeout', _('Request Timeout'),
			_('Seconds per HTTP request'));
		o.datatype = 'uinteger';
		o.placeholder = '10';

		return m.render();
	}
});
