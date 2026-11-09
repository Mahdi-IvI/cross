import '../../../../core/errors/app_failure.dart';

class ItemDetails {
  factory ItemDetails(String name, String description) {
    name = name.trim();
    description = description.trim();
    if (name.isEmpty || description.isEmpty) {
      throw const AppFailure('Name and description are required.');
    }
    if (name.length > 200 || description.length > 4000) {
      throw const AppFailure(
        'Use at most 200 characters for the name and 4000 for the description.',
      );
    }
    return ItemDetails._(name, description);
  }
  const ItemDetails._(this.name, this.description);
  final String name;
  final String description;
}
