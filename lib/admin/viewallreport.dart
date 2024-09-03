import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:url_launcher/url_launcher.dart';

class Viewallreport extends StatefulWidget {
  @override
  _ViewallreportState createState() => _ViewallreportState();
}

class _ViewallreportState extends State<Viewallreport> {
  List<dynamic> reportData = [];
  List<dynamic> filteredData = [];
  bool isLoading = false;
  DateTime? startDate;
  DateTime? endDate;
  String? errorMessage;
  TextEditingController searchController = TextEditingController();
  String? selectedDepartment;

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
    fetchReports();
    searchController.addListener(_filterData);
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  Future<void> fetchReports() async {
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
        'http://13.201.213.5:4040/admin/fetchallreportbystartandenddate?startingdate=$startingdate&enddate=$enddate';

    try {
      final response = await http.post(Uri.parse(url));
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        setState(() {
          reportData = data['body'];
          filteredData = data['body'];
          isLoading = false;
        });
        if (data['body'].isEmpty) {
          setState(() {
            errorMessage =
                'No report records found for the given date range.';
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
      filteredData = reportData.where((employee) {
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
        fetchReports();
      }
    }
  }

  void _showSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _launchURL(String url) async {
    if (await canLaunch(url)) {
      await launch(url);
    } else {
      _showSnackbar('Could not launch $url');
    }
  }

  void _openImageViewer(String imageUrl) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ImageViewerScreen(imageUrl: imageUrl),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Report Data'),
        centerTitle: true,
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        titleTextStyle: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 23,
        ),
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
                  _filterData();
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
                                  'Name : ${employee['name_of_the_Employee'] ?? 'null'}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 20.0,
                                    color: Colors.brown,
                                  ),
                                ),
                                subtitle: Text(
                                  'Department: ${employee['department'] ?? 'null'}',
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
                                    'Report Details:',
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
                                          '➤    Date: ${day['date']}, \nDay: ${day['day'] ?? 'null'}, \nReports:',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 18,
                                            color: Colors.black,
                                          ),
                                        ),
                                        ...day['report_Details']
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
                                                    text: 'Report: ',
                                                    style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                  ),
                                                  TextSpan(
                                                    text: '${details['report']}',
                                                  ),
                                                  TextSpan(
                                                    text: '\nImage Link: ',
                                                    style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                  ),
                                                  TextSpan(
                                                    text: details['imageLink'] != null
                                                        ? '${details['imageLink']}'
                                                        : 'null',
                                                    style: TextStyle(
                                                      color: Colors.blue,
                                                      decoration: TextDecoration.underline,
                                                    ),
                                                    recognizer: TapGestureRecognizer()
                                                      ..onTap = () {
                                                        if (details['imageLink'] != null) {
                                                          _openImageViewer(details['imageLink']);
                                                        }
                                                      },
                                                  ),
                                                  TextSpan(
                                                    text: '\nDocument Link: ',
                                                    style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                  ),
                                                  TextSpan(
                                                    text: details['documentLink'] != null
                                                        ? '${details['documentLink']}'
                                                        : 'null',
                                                    style: TextStyle(
                                                      color: Colors.blue,
                                                      decoration: TextDecoration.underline,
                                                    ),
                                                    recognizer: TapGestureRecognizer()
                                                      ..onTap = () {
                                                        _launchURL(details['documentLink']);
                                                      },
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

class ImageViewerScreen extends StatelessWidget {
  final String imageUrl;

  const ImageViewerScreen({Key? key, required this.imageUrl}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
       appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
      ),
      body: Center(
        child: InteractiveViewer(
          child: Image.network(imageUrl),
        ),
      ),
    );
  }
}
