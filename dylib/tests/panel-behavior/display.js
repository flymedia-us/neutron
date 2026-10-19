'use strict';
const assert = require('node:assert/strict');
const { panel, walk, details, FORMS } = require('./harness');
const emit = process.argv[2];
for (const form of Object.keys(FORMS)) {
  const p = panel(emit, form);
  const nodes = opts => walk(p.render({ details: details(opts) }));
  const control = (opts, label) => nodes(opts).find(n => n.type === 'Section' && n.props.label === label).props.children;
  const last = () => p.written.at(-1).opts;
  const base = 'WINEDEBUG=-all NOTPROTON_DPI=192 NOTPROTON_RETINA=1 %command% --title "keep this"';
  assert(!nodes('').find(n => n.type === 'details').props.open, 'power controls start collapsed');
  assert.equal(control('', 'Display pixels').props.selectedOption, '');
  assert.equal(control('NOTPROTON_RETINA=0 NOTPROTON_DPI=192 %command%', 'Display pixels').props.selectedOption, '1');
  control(base, 'Display pixels').props.onChange({ data: '0' });
  assert(last().includes('NOTPROTON_RETINA=0'));
  assert(!last().includes('NOTPROTON_DPI='));
  assert(last().endsWith('%command% --title "keep this"'));
  assert(last().includes('WINEDEBUG=-all'));
  control('NOTPROTON_RETINA=0 %command%', 'Windows UI scale').props.onChange({ data: '192' });
  assert(last().includes('NOTPROTON_RETINA=1'));
  assert(last().includes('NOTPROTON_DPI=192'));
  assert.equal(control(last(), 'Windows UI scale').props.selectedOption, '192');
  control(last(), 'Display pixels').props.onChange({ data: '' });
  assert(!last().includes('NOTPROTON_RETINA='));
  assert(last().includes('NOTPROTON_DPI=192'));
  for (const backend of ['dxmt', 'dxvk']) {
    const opts = `CX_GRAPHICS_BACKEND=${backend} %command% --arg`;
    control(opts, 'Frame rate limit').props.onChange({ data: '60' });
    assert.equal(control(last(), 'Frame rate limit').props.selectedOption, '60');
    assert(last().includes('NOTPROTON_FPS_LIMIT=60'));
    assert(last().endsWith('%command% --arg'));
    control(last(), 'Frame rate limit').props.onChange({ data: '' });
    assert(!last().includes('NOTPROTON_FPS_LIMIT='));
    assert.equal(control(`CX_GRAPHICS_BACKEND=${backend} NOTPROTON_FPS_LIMIT=143 %command%`, 'Frame rate limit').props.selectedOption, '143');
  }
  for (const backend of ['', 'd3dmetal', 'wined3d']) {
    assert(!nodes(`CX_GRAPHICS_BACKEND=${backend} %command%`).some(n => n.props.label === 'Frame rate limit'),
      'avoid offering a frame cap when the current engine/renderer does not support it');
  }
}
console.log('PASS: display choices, DPI, supported frame caps, custom values, resets and game arguments');
