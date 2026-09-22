ObjC.import('IOKit');
ObjC.import('Foundation');

ObjC.bindFunction('IOHIDEventSystemClientCreateWithType', [
  'void *',
  ['void *', 'int', 'void *']
]);
ObjC.bindFunction('IOHIDEventSystemClientSetMatching', [
  'void',
  ['void *', 'id']
]);
ObjC.bindFunction('IOHIDEventSystemClientCopyServices', [
  'id',
  ['void *']
]);
ObjC.bindFunction('IOHIDServiceClientSetProperty', [
  'bool',
  ['void *', 'id', 'id']
]);

function applyMapping(sourceUsage, destinationUsage) {
  const pairs = $([{
    HIDKeyboardModifierMappingSrc: sourceUsage,
    HIDKeyboardModifierMappingDst: destinationUsage
  }]);
  const client = $.IOHIDEventSystemClientCreateWithType($(), 1, $());
  $.IOHIDEventSystemClientSetMatching(client, $({
    PrimaryUsagePage: 1,
    PrimaryUsage: 6
  }));

  const services = $.IOHIDEventSystemClientCopyServices(client);
  if (!services || services.isNil()) {
    return 0;
  }

  let applied = 0;
  for (let index = 0; index < Number(services.count); index += 1) {
    const service = ObjC.castObjectToRef(services.objectAtIndex(index));
    const changed = $.IOHIDServiceClientSetProperty(
      service,
      $('HIDKeyboardModifierMappingPairs'),
      pairs
    );
    if (changed) {
      applied += 1;
    }
  }
  return applied;
}

function run(arguments) {
  if (arguments.length !== 2) {
    throw new Error('사용법: caps-lock-fn.js <source usage> <destination usage>');
  }
  const sourceUsage = Number(arguments[0]);
  const destinationUsage = Number(arguments[1]);
  if (!Number.isFinite(sourceUsage) || !Number.isFinite(destinationUsage)) {
    throw new Error('HID usage 값은 숫자여야 합니다.');
  }
  return String(applyMapping(sourceUsage, destinationUsage));
}
