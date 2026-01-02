import 'package:intl/intl.dart';

class FunctionsHelper {
  static NumberFormat num_format = NumberFormat.decimalPattern("en_IN");
  static String format_double(String num) {
    return num_format.format(double.parse(num));
  }

  static String format_int(int num) {
    return num_format.format(num);
  }
}
