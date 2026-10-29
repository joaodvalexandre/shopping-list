import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../data/repository.dart';

extension PeopleOnContext on BuildContext {
  /// A person's name as shown: the name they chose and the family's ("João Alexandre").
  String who(String name) => read<Repository>().displayName(name);
}
