function AK_HumanizeAhkHotkey(hk) {
  if (!hk) return '';
  let input = `${hk}`;
  const labels = [];

  if (input.indexOf('*') !== -1) {
    labels.push('Wildcard');
    input = input.replace(/\*/g, '');
  }
  if (input.indexOf('~') !== -1) {
    labels.push('Passthrough');
    input = input.replace(/~/g, '');
  }
  if (input.indexOf('^') !== -1) {
    labels.push('Ctrl');
    input = input.replace(/\^/g, '');
  }
  if (input.indexOf('!') !== -1) {
    labels.push('Alt');
    input = input.replace(/!/g, '');
  }
  if (input.indexOf('+') !== -1) {
    labels.push('Shift');
    input = input.replace(/\+/g, '');
  }
  if (input.indexOf('#') !== -1) {
    labels.push('Win');
    input = input.replace(/#/g, '');
  }

  const key = input.trim();
  if (key) labels.push(key);
  return labels.join(' + ');
}