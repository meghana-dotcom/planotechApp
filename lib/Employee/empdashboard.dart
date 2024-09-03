import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:planotech/Employee/addleads.dart';
import 'package:planotech/Employee/addreport.dart';
import 'package:planotech/admin/allattendance.dart';
import 'package:planotech/admin/viewattendance.dart';
import 'package:planotech/admin/viewleads.dart';
import 'package:planotech/dashboard.dart';
import 'package:planotech/logout.dart';
import 'package:planotech/profile.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

var attendanceStatus = '';

class EmployeeDashboard extends StatefulWidget {
  @override
  _EmployeeDashboardState createState() => _EmployeeDashboardState();
}

class _EmployeeDashboardState extends State<EmployeeDashboard> {
  int _selectedIndex = 0;
  SharedPreferences? _prefs;
  late String _punchinTime;
  Map<String, dynamic> response = {};
  bool _isButtonDisabled = false;

String get empId => response['body']?['userId'] ?? '';
  String get name => response['body']?['userName'] ?? '';
  String get department => response['body']?['userDepartment'] ?? '';

  @override
  void initState() {
    super.initState();
    fetchStoredResponse();
    _initPrefs();
  }

  Future<void> fetchStoredResponse() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? storedResponse = prefs.getString('response');
    if (storedResponse != null) {
      try {
        setState(() {
          response = json.decode(storedResponse);
        });
      } catch (e) {
        print("Error decoding stored response: $e");
      }
    } else {
      print("No stored response found.");
    }
    print(response);
  }

  void _initPrefs() async {
    _prefs = await SharedPreferences.getInstance();
    _punchinTime = _prefs!.getString('punchinTime') ?? '';

    // Check if punch-in is already done today
    if (_punchinTime.isNotEmpty) {
      DateFormat('hh:mm a').parse(_punchinTime);

      if (true) {
        setState(() {});
      }
    }
  }

  Future<Position> _getGeoLocationPosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      await Geolocator.openLocationSettings();
      return Future.error('Location services are disabled.');
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return Future.error('Location permissions are denied');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return Future.error(
          'Location permissions are permanently denied, we cannot request permissions.');
    }

    return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high);
  }

  void _punchin() async {
    if (_prefs == null) {
      _initPrefs();
    }

    setState(() {
      _isButtonDisabled = true; // Disable buttons
    });

    DateTime now = DateTime.now();
    String loginTime = DateFormat('hh:mm a').format(now);
    String dayOfWeek = DateFormat('EEEE').format(now);

    _prefs!.setString('punchinTime', loginTime);
    _prefs!.setString('punchinDay', dayOfWeek);

    setState(() {
      _punchinTime = loginTime;
      // Disable punch-in button
    });

    // Get current location
    Position position = await _getGeoLocationPosition();
    String location = 'Lat: ${position.latitude}, Long: ${position.longitude}';

    // Get address from coordinates
    List<Placemark> placemarks =
        await placemarkFromCoordinates(position.latitude, position.longitude);
    Placemark place = placemarks[0];
    String address =
        '${place.street}, ${place.subLocality}, ${place.locality}, ${place.postalCode}, ${place.country}';
 
    // Calculate attendance status
    String attendanceStatus = '';
    TimeOfDay currentTime = TimeOfDay.fromDateTime(now);
    print(currentTime);

    TimeOfDay specifiedTime = TimeOfDay(hour: 9, minute: 45);
    print(specifiedTime);
    if (currentTime.hour < specifiedTime.hour ||
        (currentTime.hour == specifiedTime.hour &&
            currentTime.minute <= specifiedTime.minute)) {
      attendanceStatus = 'Punch In On Time ';
    } else {
      attendanceStatus = 'Punch In Late';
    }

    await _sendDataToBackend(
        loginTime, location, address, attendanceStatus, dayOfWeek);

    setState(() {
      _isButtonDisabled = false; 
    });
  }

  void _punchout() async {
    if (_prefs == null) {
      _initPrefs();
    }

    setState(() {
      _isButtonDisabled = true; 
    });

    setState(() {});

    DateTime now = DateTime.now();
    String punchoutTime = DateFormat('hh:mm a').format(now);
    String dayOfWeek = DateFormat('EEEE').format(now);

    _prefs!.setString('punchoutTime', punchoutTime);
    _prefs!.setString('punchoutDay', dayOfWeek);

    setState(() {
    });

    Position position = await _getGeoLocationPosition();
    String location = 'Lat: ${position.latitude}, Long: ${position.longitude}';

    List<Placemark> placemarks =
        await placemarkFromCoordinates(position.latitude, position.longitude);
    Placemark place = placemarks[0];
    String address =
        '${place.street}, ${place.subLocality}, ${place.locality}, ${place.postalCode}, ${place.country}';

    String attendanceStatus = '';
    TimeOfDay currentTime = TimeOfDay.fromDateTime(now);
    print(currentTime);

    TimeOfDay specifiedTime = TimeOfDay(hour: 18, minute: 30); 
    print(specifiedTime);
    if (currentTime.hour < specifiedTime.hour ||
        (currentTime.hour == specifiedTime.hour &&
            currentTime.minute <= specifiedTime.minute)) {
      attendanceStatus = 'Punch Out Early';
    } else {
      attendanceStatus = 'Punch Out On Time';
    }

    await _sendDataToBackend(
        punchoutTime, location, address, attendanceStatus, dayOfWeek);

    setState(() {
      _isButtonDisabled = false; 
    });
  }

  Future<void> _sendDataToBackend(String time, String location, String address,
      String attendanceStatus, String dayOfWeek) async {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return Center(
          child: CircularProgressIndicator(
            color: Colors.blueAccent,
            backgroundColor: Colors.blueGrey,
          ),
        );
      },
    );

    var url = Uri.parse('http://13.201.213.5:4040/emp/addemployeeattendence');

    // Encode data in JSON format
    var body = jsonEncode({
      "employeeId": empId,
      "date": DateFormat('dd-MM-yyyy').format(DateTime.now()),
      "time": time,
      "latitude": location.split(',')[0].trim(),
      "longitude": location.split(',')[1].trim(),
      "address": address,
      "attendanceStatus": attendanceStatus,
      "department": department,
      "name": name,
      "attendance": 'Present',
      "day": dayOfWeek,
    });
    print(body);
    var headers = {"Content-Type": "application/json"};

    // Send POST request
    var response = await http.post(url, body: body, headers: headers);
    print(response.body);
    if (response.statusCode == 200) {
      print('Data sent successfully!');
      var responseData = json.decode(response.body);
      Navigator.of(context).pop();
      if (responseData['status'] == true) {
        // Show dialog with attendance status
        showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: Text(
                'Attendance Status',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              content: Text(
                attendanceStatus,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              actions: [
                TextButton(
                  child: Text(
                    'OK',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                ),
              ],
            );
          },
        );
      }
    } else {
      print('Failed to send data. Error: ${response.reasonPhrase}');
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              'assets/plano_logo.png',
              height: 80,
              width: 320,
              fit: BoxFit.contain,
            ),
          ],
        ),
        toolbarHeight: 85,
        backgroundColor: const Color.fromARGB(255, 243, 198, 215),
      ),
      body: Stack(fit: StackFit.expand, children: [
        Image.asset(
          'assets/mobilebackground.jpg',
          fit: BoxFit.cover,
        ),
        SingleChildScrollView(
          child: Container(
            // padding: const EdgeInsets.all(62),
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/mobilebackground.jpg'),
                fit: BoxFit.cover,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                const Text(
                  'Welcome to the Employee Dashboard!',
                  style: TextStyle(
                    fontSize: 24.0,
                    color: Colors.black,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20.0),
                const CircleAvatar(
                  radius: 60,
                  backgroundImage: AssetImage('assets/avatar.png'),
                ),
                const SizedBox(height: 20.0),
                SizedBox(
                  width: 240,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => EmployeeRegistrationForm(empId),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      foregroundColor: Colors.black,
                      backgroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add),
                        SizedBox(width: 8),
                        Text('Add Leads'),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10.0),
                SizedBox(
                  width: 240,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const ViewLeadsPage(),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      foregroundColor: Colors.black,
                      backgroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.leaderboard_sharp),
                        SizedBox(width: 8),
                        Text('View Leads'),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10.0),
                SizedBox(
                  width: 240,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ReportSubmissionScreen(
                              response['body']?['userId'],
                              response['body']?['userName'],
                              response['body']?['userDepartment']
                          ),    
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      foregroundColor: Colors.black,
                      backgroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.feedback_outlined),
                        SizedBox(width: 8),
                        Text('Add Report'),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10.0),
                SizedBox(
                  width: 240,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => ViewAttendanceById(empId)),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      foregroundColor: Colors.black,
                      backgroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.table_view_rounded),
                        SizedBox(width: 8),
                        Text('View Attendance'),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                if(department=="HR")
              SizedBox(
                width: 240,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => AttendancePage1(),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color.fromARGB(255, 255, 255, 255),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.view_comfortable, color: Colors.black),
                      SizedBox(width: 8),
                      Text('View All Attendance',
                          style: TextStyle(color: Colors.black)),
                    ],
                  ),
                ),
              ),
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.topRight,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 100,
                          child: ElevatedButton(
                            onPressed: _isButtonDisabled ? null : _punchin,
                            style: ElevatedButton.styleFrom(
                              foregroundColor: Colors.black,
                              backgroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 5),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                            child: const Text('Punch In',
                                style: TextStyle(fontSize: 12.0)),
                          ),
                        ),
                        const SizedBox(width: 10),
                        SizedBox(
                          width: 100,
                          child: ElevatedButton(
                            onPressed: _isButtonDisabled ? null : _punchout,
                            style: ElevatedButton.styleFrom(
                              foregroundColor: Colors.black,
                              backgroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 5),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                            child: const Text('Punch Out',
                                style: TextStyle(fontSize: 12.0)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ]),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: Colors.lightBlue[300],
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profile',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.logout),
            label: 'Logout',
          ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.white,
        unselectedItemColor: Colors.white,
        onTap: _onItemTapped,
      ),
    );
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
      if (_selectedIndex == 0) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const Dashboard(),
          ),
        );
      } else if (_selectedIndex == 1) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const ProfilePage(),
          ),
        );
      } else if (_selectedIndex == 2) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const Logout(),
          ),
        );
      }
    });
  }
}