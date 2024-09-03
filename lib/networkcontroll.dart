import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'dart:io';

class NetworkController extends GetxController {
  final Connectivity _connectivity = Connectivity();

  var connectivityStatus = ConnectivityResult.none.obs;
  var isConnectionPoor = false.obs;

  @override
  void onInit() {
    super.onInit();
    _connectivity.onConnectivityChanged.listen(_updateConnectionStatus);
  }

  @override
  void onClose() {
    super.onClose();
  }

  void _updateConnectionStatus(ConnectivityResult connectivityResult) async {
    connectivityStatus.value = connectivityResult;
    if (connectivityResult == ConnectivityResult.none) {
      _showSnackbar(
        message: 'PLEASE CONNECT TO THE INTERNET',
        backgroundColor: Colors.red[400]!,
        icon: Icons.wifi_off,
      );
    } else {
      isConnectionPoor.value = await _isConnectionPoor();
      if (isConnectionPoor.value) {
        _showSnackbar(
          message: 'POOR INTERNET CONNECTION',
          backgroundColor: Colors.orange[400]!,
          icon: Icons.signal_cellular_connected_no_internet_4_bar,
        );
      } else {
        if (Get.isSnackbarOpen) {
          Get.closeCurrentSnackbar();
        }
      }
    }
  }

  Future<bool> _isConnectionPoor() async {
    const int thresholdSpeedKbps = 6; // 6 KBps
    const int testSize = 1024; // 1 KB test size
    const int timeout = 5; // 5 seconds timeout
    try {
      final stopwatch = Stopwatch()..start();
      final socket = await Socket.connect('google.com', 80, timeout: Duration(seconds: timeout));
      stopwatch.stop();

      socket.destroy();

      // Calculate speed in KBps
      final speedKbps = (testSize / stopwatch.elapsedMilliseconds) * 1000;

      // Check if speed is less than threshold
      return speedKbps < thresholdSpeedKbps;
    } catch (_) {
      return true;
    }
  }

  void _showSnackbar({required String message, required Color backgroundColor, required IconData icon}) {
    if (Get.isSnackbarOpen) {
      Get.closeCurrentSnackbar();
    }

    Get.rawSnackbar(
      messageText: Text(
        message,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 14,
        ),
      ),
      isDismissible: false,
      duration: const Duration(days: 1),
      backgroundColor: backgroundColor,
      icon: Icon(icon, color: Colors.white, size: 35,),
      margin: EdgeInsets.zero,
      snackStyle: SnackStyle.GROUNDED,
    );
  }
}
