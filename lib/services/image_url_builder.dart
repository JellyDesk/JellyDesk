class ImageUrlBuilder {
  ImageUrlBuilder(this.baseUrl, this.apiKey);
  final String baseUrl;
  final String apiKey;

  String? primary(Map item, {int width = 600}) {
    final tag = _tag(item, 'Primary');
    if (tag == null) return null;
    final id = item['Id'];
    return '$baseUrl/Items/$id/Images/Primary?fillWidth=$width&quality=90&tag=$tag&api_key=$apiKey';
  }

  String? logo(Map item, {int width = 600}) {
    final tag = _tag(item, 'Logo');
    if (tag == null) return null;
    final id = item['Id'];
    return '$baseUrl/Items/$id/Images/Logo?fillWidth=$width&quality=90&tag=$tag&api_key=$apiKey';
  }

  String? backdrop(Map item, {int index = 0, int width = 1280}) {
    final tags = (item['BackdropImageTags'] as List?)?.cast<String>();
    if (tags == null || tags.isEmpty || index >= tags.length) return null;
    final id = item['Id'];
    final tag = tags[index];
    return '$baseUrl/Items/$id/Images/Backdrop/$index?fillWidth=$width&quality=90&tag=$tag&api_key=$apiKey';
  }

  String? banner(Map item, {int width = 1000}) {
    final tag = _tag(item, 'Banner');
    if (tag == null) return null;
    final id = item['Id'];
    return '$baseUrl/Items/$id/Images/Banner?fillWidth=$width&quality=90&tag=$tag&api_key=$apiKey';
  }

  /// Netflix-artige Logik: nimm bevorzugt Banner → sonst Backdrop → sonst Primary.
  String posterOrFallback(Map item, {int width = 600}) {
    return banner(item, width: width)
        ?? primary(item, width: width)
        ?? backdrop(item, width: width)
        ?? '$baseUrl/Branding/Images/logo?api_key=$apiKey';
  }

  String? _tag(Map item, String type) {
    final tags = (item['ImageTags'] as Map?)?.cast<String, dynamic>();
    final tag = tags?[type];
    if (tag is String) return tag;
    return null;
  }
}
