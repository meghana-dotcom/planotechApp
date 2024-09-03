import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';

class Reportpage extends StatefulWidget {
  final int empId;
  Reportpage(this.empId);

  @override
  _ReportpageState createState() => _ReportpageState();
}

class _ReportpageState extends State<Reportpage> {
  List<dynamic> _userList = [];
  List<dynamic> _filteredUserList = [];
  bool _isLoading = false;
  DateTime? _selectedDate;

  @override
  void initState() {
    super.initState();
    fetchData();
  }

  Future<void> fetchData() async {
    setState(() {
      _isLoading = true;
    });

    final response = await http.post(
      Uri.parse('http://13.201.213.5:4040/admin/fetchdailyemployeereportbyid?empId=${widget.empId}'),
      headers: {
        'Content-Type': 'application/json',
      },
      body: jsonEncode(<String, dynamic>{'empId': widget.empId}),
    );

    if (response.statusCode == 200) {
      final Map<String, dynamic> data = json.decode(response.body);
      setState(() {
        _userList = data['userList'] ?? [];
        _filteredUserList = _userList;
        _isLoading = false;
      });
    } else {
      setState(() {
        _isLoading = false;
      });
      throw Exception('Failed to load data');
    }
  }

  void filterByDate(DateTime? selectedDate) {
    setState(() {
      _selectedDate = selectedDate;
      if (_selectedDate == null) {
        _filteredUserList = List.from(_userList);
      } else {
        _filteredUserList = _userList.where((user) {
          try {
            final dateParts = (user['date'] ?? '').split('-');
            if (dateParts.length == 3) {
              final day = int.tryParse(dateParts[0]);
              final month = int.tryParse(dateParts[1]);
              final year = int.tryParse(dateParts[2]);
              if (day != null && month != null && year != null) {
                final userDate = DateTime(year, month, day);
                return userDate.toLocal().isAtSameMomentAs(_selectedDate!.toLocal());
              }
            }
            return false;
          } catch (e) {
            print('Error parsing date: $e');
            return false;
          }
        }).toList();
      }
    });
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(2015, 8),
      lastDate: DateTime(2101),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
      filterByDate(picked);
    }
  }

  void _openImageDialog(String imageUrl) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        child: InteractiveViewer(
          boundaryMargin: EdgeInsets.all(20.0),
          minScale: 0.1,
          maxScale: 5.0,
          child: Image.network(imageUrl),
        ),
      ),
    );
  }

  Future<void> _openFile(String fileUrl) async {
    try {
      final response = await http.get(Uri.parse(fileUrl));
      if (response.statusCode == 200) {
        final fileName = fileUrl.substring(fileUrl.lastIndexOf('/') + 1);
        final directory = await getApplicationDocumentsDirectory();
        final filePath = '${directory.path}/$fileName';

        final file = File(filePath);
        await file.writeAsBytes(response.bodyBytes);

        // Open the file
        final result = await OpenFile.open(filePath);
        if (result.type != ResultType.done) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not open the file')),
          );
        }
      } else {
        throw Exception('Failed to download file');
      }
    } catch (e) {
      print('Error opening file: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('An error occurred while opening the file')),
      );
    }
  }

  Icon _getFileIcon(String extension) {
    switch (extension) {
      case 'pdf':
        return Icon(Icons.picture_as_pdf, color: Colors.red);
      case 'doc':
      case 'docx':
        return Icon(Icons.description, color: Colors.blue);
      case 'xls':
      case 'xlsx':
        return Icon(Icons.table_chart, color: Colors.green);
      case 'jpg':
      case 'jpeg':
      case 'png':
        return Icon(Icons.image, color: Colors.orange);
      default:
        return Icon(Icons.insert_drive_file, color: Colors.grey);
    }
  }

  Widget _buildReportItem(dynamic user) {
    final date = user['date'] ?? 'No date';
    final report = user['report'] ?? '';
    final imageUrl = user['imageLink'];
    final fileUrl = user['documentLink'];
    final fileExtension = fileUrl != null ? fileUrl.split('.').last : '';

    return Card(
      color: Colors.grey.shade200,
      margin: EdgeInsets.all(8.0),
      elevation: 3.0,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            title: Text('Date: $date'),
            subtitle: Text('Report: $report'),
          ),
          SizedBox(height: 8.0),
          if (imageUrl != null && imageUrl.isNotEmpty)
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => _openImageDialog(imageUrl),
                    child: Row(
                      children: [
                        Icon(Icons.image),
                        SizedBox(width: 8.0),
                        Expanded(
                          child: Text(
                            'Image: $imageUrl',
                            style: TextStyle(
                              fontSize: 14.0,
                              fontWeight: FontWeight.bold,
                              color: Colors.brown,
                            ),
                            overflow: TextOverflow.visible,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          SizedBox(height: 8.0),
          if (fileUrl != null && fileUrl.isNotEmpty)
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => _openFile(fileUrl), 
                    child: Row(
                      children: [
                        _getFileIcon(fileExtension),
                        SizedBox(width: 8.0),
                        Expanded(
                          child: Text(
                            'File: $fileUrl',
                            style: TextStyle(
                              fontSize: 14.0,
                              fontWeight: FontWeight.bold,
                              color: Colors.blueGrey,
                            ),
                            overflow: TextOverflow.visible,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          SizedBox(height: 16.0),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(),
            )
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: TextFormField(
                    readOnly: true,
                    onTap: () async {
                      final selectedDate = await showDatePicker(
                        context: context,
                        initialDate: _selectedDate ?? DateTime.now(),
                        firstDate: DateTime(2000),
                        lastDate: DateTime.now(),
                      );
                      if (selectedDate != null) {
                        _selectDate(context);
                      }
                    },
                    controller: TextEditingController(
                      text: _selectedDate != null
                          ? '${_selectedDate!.day}-${_selectedDate!.month}-${_selectedDate!.year}'
                          : '',
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Filter by Date',
                      border: OutlineInputBorder(),
                      suffixIcon: Icon(Icons.calendar_today),
                    ),
                  ),
                ),
                Expanded(
                  child: _filteredUserList.isEmpty
                      ? Center(
                          child: Text(
                            'No data found for selected date.',
                            style: TextStyle(fontSize: 18.0),
                          ),
                        )
                      : ListView.builder(
                          itemCount: _filteredUserList.length,
                          itemBuilder: (context, index) {
                            return _buildReportItem(_filteredUserList[index]);
                          },
                        ),
                ),
              ],
            ),
    );
  }
}
