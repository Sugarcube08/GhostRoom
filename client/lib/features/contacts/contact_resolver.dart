import 'contact.dart';
import 'contact_service.dart';

class ContactResolver {
  final ContactService _contactService;

  ContactResolver(this._contactService);

  String resolveAlias(String publicId) {
    final contact = _contactService.getContact(publicId);
    return contact?.alias ?? _formatTruncatedId(publicId);
  }

  Contact? resolveContact(String publicId) {
    return _contactService.getContact(publicId);
  }

  String _formatTruncatedId(String id) {
    if (id.length <= 8) return id;
    return '${id.substring(0, 4)}...${id.substring(id.length - 4)}';
  }
}
