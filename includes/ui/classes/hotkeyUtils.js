function AK_HumanizeAhkHotkey(hk) {
  if (!hk) return '';

  const labels = [];
  const input = `${hk}`.trim();
  let i = 0;

  while (i < input.length) {
    const two = input.slice(i, i + 2);
    const one = input[i];

    if (two === '<^') {
      labels.push('LCtrl');
      i += 2;
      continue;
    }
    if (two === '>^') {
      labels.push('RCtrl');
      i += 2;
      continue;
    }
    if (two === '<!') {
      labels.push('LAlt');
      i += 2;
      continue;
    }
    if (two === '>!') {
      labels.push('RAlt');
      i += 2;
      continue;
    }
    if (two === '<+') {
      labels.push('LShift');
      i += 2;
      continue;
    }
    if (two === '>+') {
      labels.push('RShift');
      i += 2;
      continue;
    }
    if (two === '<#') {
      labels.push('LWin');
      i += 2;
      continue;
    }
    if (two === '>#') {
      labels.push('RWin');
      i += 2;
      continue;
    }

    if (one === '*') {
      labels.push('Wildcard');
      i += 1;
      continue;
    }
    if (one === '~') {
      labels.push('Passthrough');
      i += 1;
      continue;
    }
    if (one === '^') {
      labels.push('Ctrl');
      i += 1;
      continue;
    }
    if (one === '!') {
      labels.push('Alt');
      i += 1;
      continue;
    }
    if (one === '+') {
      labels.push('Shift');
      i += 1;
      continue;
    }
    if (one === '#') {
      labels.push('Win');
      i += 1;
      continue;
    }

    break;
  }

  const key = input.slice(i).trim();
  if (key) labels.push(AK_HumanizeAhkKeyName(key));
  return labels.join(' + ');
}

function AK_HumanizeAhkKeyName(key) {
  const text = `${key}`.trim();
  if (!text) return '';

  const keyMap = {
    LButton: 'Mouse Left',
    RButton: 'Mouse Right',
    MButton: 'Mouse Middle',
    WheelUp: 'Mouse Wheel Up',
    WheelDown: 'Mouse Wheel Down',
    WheelLeft: 'Mouse Wheel Left',
    WheelRight: 'Mouse Wheel Right',
    XButton1: 'Mouse Button 4',
    XButton2: 'Mouse Button 5'
  };

  if (Object.prototype.hasOwnProperty.call(keyMap, text)) return keyMap[text];

  let match = text.match(/^(\d+)Joy(\d+)$/i);
  if (match) return `Gamepad ${match[1]} Button ${match[2]}`;

  match = text.match(/^(\d+)JoyPOV$/i);
  if (match) return `Gamepad ${match[1]} D-Pad`;

  match = text.match(/^(\d+)Joy([XYZRUV])$/i);
  if (match) return `Gamepad ${match[1]} Axis ${match[2].toUpperCase()}`;

  match = text.match(/^Joy(\d+)$/i);
  if (match) return `Gamepad Button ${match[1]}`;

  return text;
}