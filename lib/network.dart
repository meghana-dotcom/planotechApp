import 'package:get/get.dart';
import 'package:planotech/networkcontroll.dart';

class DependencyInjection {
  static void init() {
    Get.put<NetworkController>(NetworkController(),permanent:true);
  }
}
