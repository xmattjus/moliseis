import 'package:objectbox/objectbox.dart';

@Entity()
class SearchQuery {
  SearchQuery(this.name);

  @Id()
  int id = 0;

  final String name;
}
