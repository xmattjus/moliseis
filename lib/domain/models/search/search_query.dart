import 'package:objectbox/objectbox.dart';

@Entity()
class SearchQuery {
  @Id()
  int id = 0;

  final String name;

  SearchQuery(this.name);
}
