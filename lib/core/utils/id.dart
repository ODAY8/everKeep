/// A locally unique id for an item created on this device, e.g. `doc-…`.
///
/// TODO: Once a backend exists it should assign ids; this only keeps
/// client-created items distinct until then.
String newId(String prefix) =>
    '$prefix-${DateTime.now().microsecondsSinceEpoch}';
