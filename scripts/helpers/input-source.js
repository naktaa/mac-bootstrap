ObjC.import('Carbon');

// macOS에 설치된 입력 소스 중 기본 두벌식 입력 모드를 찾는다.
// plist 배열을 직접 편집하지 않고 Apple의 Text Input Source API를 사용한다.

const koreanSourceIds = [
  'com.apple.inputmethod.Korean.2SetKorean',
  'com.apple.inputmethod.Korean'
];

function unwrap(value) {
  if (value === undefined || value === null) {
    return null;
  }
  try {
    return ObjC.unwrap(value);
  } catch (error) {
    return value;
  }
}

function property(source, key) {
  return unwrap($.TISGetInputSourceProperty(source, key));
}

function isKoreanTwoSet(source) {
  const sourceId = String(property(source, $.kTISPropertyInputSourceID) || '');
  const inputModeId = String(property(source, $.kTISPropertyInputModeID) || '');
  const localizedName = String(property(source, $.kTISPropertyLocalizedName) || '');

  if (koreanSourceIds.indexOf(sourceId) !== -1 &&
      (sourceId.indexOf('2SetKorean') !== -1 || inputModeId.indexOf('2SetKorean') !== -1)) {
    return true;
  }

  return inputModeId === 'com.apple.inputmethod.Korean.2SetKorean' ||
    localizedName === '2-Set Korean' ||
    localizedName === '두벌식';
}

function findKoreanTwoSet() {
  const sources = $.TISCreateInputSourceList(null, true);
  const count = Number(sources.count);

  for (let index = 0; index < count; index += 1) {
    const source = sources.objectAtIndex(index);
    if (isKoreanTwoSet(source)) {
      return source;
    }
  }
  return null;
}

function findAsciiSource(onlyEnabled) {
  const sources = $.TISCreateInputSourceList(null, true);
  const count = Number(sources.count);
  let fallback = null;

  for (let index = 0; index < count; index += 1) {
    const source = sources.objectAtIndex(index);
    const asciiCapable = Boolean(property(source, $.kTISPropertyInputSourceIsASCIICapable));
    const enabled = Boolean(property(source, $.kTISPropertyInputSourceIsEnabled));
    if (!asciiCapable || (onlyEnabled && !enabled)) {
      continue;
    }

    const sourceId = String(property(source, $.kTISPropertyInputSourceID) || '');
    if (sourceId === 'com.apple.keylayout.ABC' || sourceId === 'com.apple.keylayout.US') {
      return source;
    }
    if (fallback === null) {
      fallback = source;
    }
  }
  return fallback;
}

function inspect() {
  const source = findKoreanTwoSet();
  const latinEnabled = findAsciiSource(true) !== null;
  if (!source) {
    return 'KOREAN_AVAILABLE=false\nKOREAN_ENABLED=false\nLATIN_ENABLED=' + String(latinEnabled);
  }

  const enabled = Boolean(property(source, $.kTISPropertyInputSourceIsEnabled));
  return 'KOREAN_AVAILABLE=true\nKOREAN_ENABLED=' + String(enabled) +
    '\nLATIN_ENABLED=' + String(latinEnabled);
}

function enable() {
  const source = findKoreanTwoSet();
  if (!source) {
    throw new Error('macOS 기본 두벌식 입력 소스를 찾지 못했습니다.');
  }

  const status = Number($.TISEnableInputSource(source));
  if (status !== 0) {
    throw new Error('TISEnableInputSource 실패: OSStatus=' + String(status));
  }

  if (findAsciiSource(true) === null) {
    const asciiSource = findAsciiSource(false);
    if (asciiSource === null) {
      throw new Error('기본 영문 입력 소스를 찾지 못했습니다.');
    }
    const asciiStatus = Number($.TISEnableInputSource(asciiSource));
    if (asciiStatus !== 0) {
      throw new Error('영문 TISEnableInputSource 실패: OSStatus=' + String(asciiStatus));
    }
  }
  return inspect();
}

function run(arguments) {
  const action = arguments.length > 0 ? String(arguments[0]) : 'inspect';
  if (action === 'inspect') {
    return inspect();
  }
  if (action === 'enable') {
    return enable();
  }
  throw new Error('지원하지 않는 action: ' + action);
}
