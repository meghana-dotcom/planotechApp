import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:planotech/admin/excel_download.dart';

class AttendancePage1 extends StatefulWidget {
  @override
  _AttendancePage1State createState() => _AttendancePage1State();
}

class _AttendancePage1State extends State<AttendancePage1> {
  List<dynamic> attendanceData = [];
  List<dynamic> filteredData = [];
  bool isLoading = false;
  DateTime? startDate;
  DateTime? endDate;
  String? errorMessage;
  TextEditingController searchController = TextEditingController();
  String? selectedDepartment;
  bool _isDownloading = false;

  List<String> departments = [
    'IT',
    'Administration',
    'HR',
    'Sales and Marketing',
    'Design',
    'Finance and Accounts',
    'Production',
    'Operations-Support',
  ];

  @override
  void initState() {
    super.initState();
    final DateTime today = DateTime.now();
    startDate = today;
    endDate = today;
    fetchAttendance();
    searchController.addListener(_filterData);
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  Future<void> fetchAttendance() async {
    if (startDate == null || endDate == null) {
      setState(() {
        errorMessage = 'Please select both start and end dates.';
      });
      return;
    }

    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    final startingdate =
        "${startDate!.day.toString().padLeft(2, '0')}-${startDate!.month.toString().padLeft(2, '0')}-${startDate!.year}";
    final enddate =
        "${endDate!.day.toString().padLeft(2, '0')}-${endDate!.month.toString().padLeft(2, '0')}-${endDate!.year}";

    final url =
        'http://13.201.213.5:4040/admin/fetchallattendancebystartandenddate?startingdate=$startingdate&enddate=$enddate';

    try {
      final response = await http.post(Uri.parse(url));
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        setState(() {
          attendanceData = data['body'];
          filteredData = data['body'];
          isLoading = false;
        });
        if (data['body'].isEmpty) {
          setState(() {
            errorMessage =
                'No attendance records found for the given date range.';
          });
        }
      } else {
        json.decode(response.body);
        setState(() {
          errorMessage = 'No Data Found';
        });
      }
    } catch (e) {
      setState(() {
        errorMessage = 'Error: $e';
        isLoading = false;
      });
    }
  }

  void _filterData() {
    String query = searchController.text.toLowerCase();
    String? departmentQuery =
        selectedDepartment != null && selectedDepartment != 'All Departments'
            ? selectedDepartment!.toLowerCase()
            : null;

    setState(() {
      filteredData = attendanceData.where((employee) {
        String name = employee['name_of_the_Employee']?.toLowerCase() ?? '';
        String department = employee['department']?.toLowerCase() ?? '';

        bool matchesName = name.contains(query);
        bool matchesDepartment =
            departmentQuery == null || department.contains(departmentQuery);

        return matchesName && matchesDepartment;
      }).toList();
    });
  }

  Future<void> _selectDate(BuildContext context, bool isStart) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2201),
    );
    if (picked != null && picked != (isStart ? startDate : endDate)) {
      setState(() {
        if (isStart) {
          startDate = picked;
        } else {
          endDate = picked;
        }
      });
      if (startDate != null && endDate != null) {
        fetchAttendance();
      }
    }
  }

  void _showSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Attendance Data'),
        centerTitle: true,
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        titleTextStyle: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 23,
        ),
        actions: [
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                icon: Icon(Icons.download),
                onPressed: _isDownloading
                    ? null
                    : () async {
                        setState(() {
                          _isDownloading = true;
                        });
                        try {
                          String result = await downloadExcel(startDate!, endDate!);
                          setState(() {
                          });
                          _showSnackbar(result);
                        } catch (e) {
                          setState(() {
                          });
                          _showSnackbar("Download failed!");
                        } finally {
                          setState(() {
                            _isDownloading = false;
                          });
                        }
                      },
              ),
              if (_isDownloading)
                Positioned(
                  right: 12,
                  child: SizedBox(
                    height: 24,
                    width: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: TextField(
              controller: searchController,
              decoration: InputDecoration(
                labelText: 'Search by Name',
                hintText: 'Enter Name',
                border: OutlineInputBorder(),
                suffixIcon: Icon(Icons.search),
              ),
            ),
          ),
          SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: DropdownButtonFormField<String>(
              value: selectedDepartment,
              hint: Text('Select Department'),
              onChanged: (String? newValue) {
                setState(() {
                  selectedDepartment = newValue;
                  _filterData(); // Call filter method when department changes
                });
              },
              items: departments.map<DropdownMenuItem<String>>((String value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(value),
                );
              }).toList(),
              decoration: InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Filter by Department',
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _selectDate(context, true),
                    child: Text(startDate == null
                        ? 'Select Start Date'
                        : 'Start Date: ${startDate!.toLocal()}'.split(' ')[0]),
                  ),
                ),
                SizedBox(width: 8.0),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _selectDate(context, false),
                    child: Text(endDate == null
                        ? 'Select End Date'
                        : 'End Date: ${endDate!.toLocal()}'.split(' ')[0]),
                  ),
                ),
              ],
            ),
          ),
          startDate != null && endDate != null
              ? Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Text(
                    'Selected Date Range: ${startDate!.day}-${startDate!.month}-${startDate!.year} to ${endDate!.day}-${endDate!.month}-${endDate!.year}',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                )
              : SizedBox(),
          Expanded(
            child: errorMessage != null
                ? Center(
                    child: Text(
                      errorMessage!,
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  )
                : isLoading
                    ? Center(child: CircularProgressIndicator())
                    : ListView.builder(
                        itemCount: filteredData.length,
                        itemBuilder: (context, index) {
                          final employee = filteredData[index];
                          return Card(
                            margin: const EdgeInsets.all(8.0),
                            child: ExpansionTile(
                              title: ListTile(
                                title: Text(
                                  '${employee['name_of_the_Employee'] ?? 'N/A'}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 20.0,
                                    color: Colors.brown,
                                  ),
                                ),
                                subtitle: Text(
                                  'Department: ${employee['department'] ?? 'N/A'}',
                             style: TextStyle(
                                    fontStyle: FontStyle.normal,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 17,
                                    color: Color.fromARGB(255, 19, 18, 18),
                                  ),
                                ),
                              ),
                              children: [
                                ListTile(
                                  title: Text(
                                    'Employee Code: ${employee['emp_Code'] ?? 'N/A'}',
                                    style: TextStyle(
                                      fontSize: 20.0,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.green,
                                    ),
                                  ),
                                ),
                                ListTile(
                                  title: Text(
                                    'Attendance Details:',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 20,
                                      color: Colors.red,
                                    ),
                                  ),
                                ),
                                ...(employee['dayAndDate'] ?? [])
                                    .map<Widget>((day) {
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 16.0),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '➤    Date: ${day['date']}, \nDay: ${day['day'] ?? 'N/A'}, \nAttendance: ${day['attendance'] ?? 'N/A'}',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 18,
                                            color: Colors.black,
                                          ),
                                        ),
                                        ...day['attendance_Details']
                                            .map<Widget>((details) {
                                          return ListTile(
                                            title: Text.rich(
                                              TextSpan(
                                                children: [
                                                  TextSpan(
                                                    text: 'Time: ',
                                                    style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                  ),
                                                  TextSpan(
                                                    text: '${details['time']}',
                                                  ),
                                                ],
                                              ),
                                              style: TextStyle(
                                                color: Colors.black87,
                                              ),
                                            ),
                                            subtitle: Text.rich(
                                              TextSpan(
                                                children: [
                                                  TextSpan(
                                                    text: 'Address: ',
                                                    style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                  ),
                                                  TextSpan(
                                                    text:
                                                        '${details['address']}',
                                                  ),
                                                  TextSpan(
                                                    text: ',\nStatus: ',
                                                    style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                  ),
                                                  TextSpan(
                                                    text:
                                                        '${details['attendance_status']}',
                                                  ),
                                                ],
                                              ),
                                              style: TextStyle(
                                                fontSize: 16,
                                                color: Colors.black87,
                                              ),
                                            ),
                                          );
                                        }).toList(),
                                      ],
                                    ),
                                  );
                                }).toList(),
                              ],
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

