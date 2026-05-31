enum AttachmentKind {
  image,
  video,
  file,
  voice,
}

class AttachmentEnvelope {
  final AttachmentKind kind;
  final String mediaId;
  final String encryptedKey;
  final String hash; // SHA256 of plaintext
  final String? name;
  final Map<String, dynamic>? meta;

  AttachmentEnvelope({
    required this.kind,
    required this.mediaId,
    required this.encryptedKey,
    required this.hash,
    this.name,
    this.meta,
  });

  Map<String, dynamic> toJson() => {
    'kind': kind.name,
    'media_id': mediaId,
    'key': encryptedKey,
    'hash': hash,
    if (name != null) 'name': name,
    if (meta != null) 'meta': meta,
  };

  factory AttachmentEnvelope.fromJson(Map<String, dynamic> json) => AttachmentEnvelope(
    kind: AttachmentKind.values.firstWhere((e) => e.name == json['kind']),
    mediaId: json['media_id'],
    encryptedKey: json['key'],
    hash: json['hash'],
    name: json['name'],
    meta: json['meta'] != null ? Map<String, dynamic>.from(json['meta']) : null,
  );
}
