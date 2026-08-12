ObjC.import('Foundation');

// AppleSymbolicHotKeys 전체를 새 값으로 덮어쓰지 않고 필요한 entry만
// mutable copy로 수정한 뒤 CFPreferences를 통해 다시 저장한다.

const applicationId = $('com.apple.symbolichotkeys');
const preferenceKey = $('AppleSymbolicHotKeys');
const currentUser = $.kCFPreferencesCurrentUser;
const anyHost = $.kCFPreferencesAnyHost;

function mutableRoot() {
  const original = $.CFPreferencesCopyValue(
    preferenceKey,
    applicationId,
    currentUser,
    anyHost
  );
  if (original === undefined || original === null) {
    return $.NSMutableDictionary.dictionary;
  }
  return $.NSMutableDictionary.dictionaryWithDictionary(original);
}

function entryFor(root, identifier) {
  return root.objectForKey($(String(identifier)));
}

function mutableEntry(root, identifier) {
  const original = entryFor(root, identifier);
  if (original === undefined || original === null) {
    return $.NSMutableDictionary.dictionary;
  }
  return $.NSMutableDictionary.dictionaryWithDictionary(original);
}

function booleanValue(value) {
  if (value === undefined || value === null) {
    return null;
  }
  return Boolean(ObjC.unwrap(value));
}

function enabledState(root, identifier) {
  const entry = entryFor(root, identifier);
  if (entry === undefined || entry === null) {
    return 'missing';
  }
  const value = booleanValue(entry.objectForKey($('enabled')));
  return value === null ? 'missing' : String(value);
}

function parametersState(root, identifier) {
  const entry = entryFor(root, identifier);
  if (entry === undefined || entry === null) {
    return 'missing';
  }
  const value = entry.objectForKey($('value'));
  if (value === undefined || value === null) {
    return 'missing';
  }
  const parameters = value.objectForKey($('parameters'));
  if (parameters === undefined || parameters === null || Number(parameters.count) < 3) {
    return 'missing';
  }
  const result = [];
  for (let index = 0; index < 3; index += 1) {
    result.push(String(ObjC.unwrap(parameters.objectAtIndex(index))));
  }
  return result.join(',');
}

function inspect() {
  const root = mutableRoot();
  return [
    'INPUT_SWITCH_ENABLED=' + enabledState(root, 60),
    'INPUT_SWITCH_PARAMETERS=' + parametersState(root, 60),
    'SPOTLIGHT_64_ENABLED=' + enabledState(root, 64),
    'SPOTLIGHT_65_ENABLED=' + enabledState(root, 65)
  ].join('\n');
}

function save(root) {
  $.CFPreferencesSetValue(
    preferenceKey,
    root,
    applicationId,
    currentUser,
    anyHost
  );
  const synchronized = Boolean($.CFPreferencesSynchronize(
    applicationId,
    currentUser,
    anyHost
  ));
  if (!synchronized) {
    throw new Error('CFPreferencesSynchronize가 실패했습니다.');
  }
}

function configureControlSpace() {
  const root = mutableRoot();
  const entry = mutableEntry(root, 60);
  const valueOriginal = entry.objectForKey($('value'));
  const value = valueOriginal === undefined || valueOriginal === null
    ? $.NSMutableDictionary.dictionary
    : $.NSMutableDictionary.dictionaryWithDictionary(valueOriginal);

  const parameters = $.NSMutableArray.array;
  parameters.addObject($.NSNumber.numberWithInt(32));
  parameters.addObject($.NSNumber.numberWithInt(49));
  parameters.addObject($.NSNumber.numberWithInt(262144));

  value.setObjectForKey(parameters, $('parameters'));
  value.setObjectForKey($('standard'), $('type'));
  entry.setObjectForKey(value, $('value'));
  entry.setObjectForKey($.NSNumber.numberWithBool(true), $('enabled'));
  root.setObjectForKey(entry, $('60'));
  save(root);
  return inspect();
}

function disableSpotlight() {
  const root = mutableRoot();
  [64, 65].forEach(function (identifier) {
    const original = entryFor(root, identifier);
    if (original !== undefined && original !== null) {
      const entry = $.NSMutableDictionary.dictionaryWithDictionary(original);
      entry.setObjectForKey($.NSNumber.numberWithBool(false), $('enabled'));
      root.setObjectForKey(entry, $(String(identifier)));
    }
  });
  save(root);
  return inspect();
}

function run(arguments) {
  const action = arguments.length > 0 ? String(arguments[0]) : 'inspect';
  if (action === 'inspect') {
    return inspect();
  }
  if (action === 'configure-control-space') {
    return configureControlSpace();
  }
  if (action === 'disable-spotlight') {
    return disableSpotlight();
  }
  throw new Error('지원하지 않는 action: ' + action);
}

