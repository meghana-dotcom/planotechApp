import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:open_file/open_file.dart';
import 'package:planotech/Employee/empdashboard.dart';

var Id;
var userName;
var userDepartment;

class ReportSubmissionScreen extends StatefulWidget {
  ReportSubmissionScreen(var empId,var empName,var empDepartment) {
    Id = empId;
    print(empId);
    print(Id);
    print("@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@");
    userName=empName;
    print(empName);
     print("@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@");
    userDepartment=empDepartment;
    print(empDepartment);
  }
  

  @override
  _ReportSubmissionScreenState createState() => _ReportSubmissionScreenState();
}

class _ReportSubmissionScreenState extends State<ReportSubmissionScreen> {
  final TextEditingController _reportController = TextEditingController();
  bool _isSubmitting = false;
  File? _selectedImageFile;
  File? _selectedDocumentFile;
  final int maxSizeInBytes = 25 * 1024 * 1024;

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

  Widget _buildUploadedFile(File file) {
    final extension = file.path.split('.').last.toLowerCase();
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey, width: 1.0),
        borderRadius: BorderRadius.circular(8.0),
      ),
      margin: EdgeInsets.symmetric(vertical: 4.0),
      child: ListTile(
        title: Text(file.path.split('/').last),
        leading: _getFileIcon(extension),
        trailing: IconButton(
          icon: Icon(Icons.cancel),
          onPressed: () {
            setState(() {
              if (file == _selectedImageFile) {
                _selectedImageFile = null;
              } else if (file == _selectedDocumentFile) {
                _selectedDocumentFile = null;
              }
            });
          },
        ),
        onTap: () {
          OpenFile.open(file.path);
        },
      ),
    );
  }

  void _showFileSizeLimitExceededSnackBar() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Upload less than 25MB image or files')),
    );
  }

  void _pickFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      allowMultiple: false,
      type: FileType.custom,
      allowedExtensions: [
        'pdf', 'doc', 'docx', 'xls', 'xlsx', 'txt', 'jpeg', 'jpg', 'png'
      ],
    );

    if (result != null) {
      File file = File(result.files.single.path!);
      if (file.lengthSync() > maxSizeInBytes) {
        _showFileSizeLimitExceededSnackBar();
      } else {
        setState(() {
          _selectedDocumentFile = file;
        });
      }
    }
  }

  void _pickImageFromCamera() async {
    final pickedFile = await ImagePicker().pickImage(source: ImageSource.camera);

    if (pickedFile != null) {
      File file = File(pickedFile.path);
      if (file.lengthSync() > maxSizeInBytes) {
        _showFileSizeLimitExceededSnackBar();
      } else {
        setState(() {
          _selectedImageFile = file;
        });
      }
    }
  }

  void _pickImageFromGallery() async {
    final pickedFile = await ImagePicker().pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      File file = File(pickedFile.path);
      if (file.lengthSync() > maxSizeInBytes) {
        _showFileSizeLimitExceededSnackBar();
      } else {
        setState(() {
          _selectedImageFile = file;
        });
      }
    }
  }

  bool _isFormValid() {
    return _reportController.text.trim().isNotEmpty ||
        _selectedImageFile != null ||
        _selectedDocumentFile != null;
  }

  Future<void> _submit() async {
    if (_isFormValid()) {
      setState(() {
        _isSubmitting = true;
      });

      String report = _reportController.text;
      DateTime now = DateTime.now();
      String date = '${now.day}-${now.month}-${now.year}';
      String time = DateFormat('hh:mm a').format(now);

      try {
        await _uploadReport(report, date, time, _selectedImageFile, _selectedDocumentFile);
        _reportController.clear();
        setState(() {
          _selectedImageFile = null;
          _selectedDocumentFile = null;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Report submitted successfully'),
            duration: Duration(seconds: 3),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => EmployeeDashboard()),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error submitting report: $e'),
            duration: Duration(seconds: 3),
            backgroundColor: Colors.red,
          ),
        );
      } finally {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }


  Future<void> _uploadReport(
    String report, String date, String time, File? image, File? file) async {
  try {
    final url = Uri.parse('http://13.201.213.5:4040/emp/dailyemployeereport');

    final Map<String, dynamic>? employeeReport = {
      "employeeId": Id,
      "date": date,
      "time": time,
      "employeeName": userName,
      "employeeDepartment": userDepartment,
    };

    String employeeReportString = jsonEncode(employeeReport);
    print('Employee Report JSON: $employeeReportString');

    final request = http.MultipartRequest('POST', url);

    request.fields['employeeReport'] = employeeReportString;

    request.fields['report'] = report;
    print(request);

    if (image != null && await image.exists()) {
      print('Adding image file: ${image.path}');
      request.files.add(await http.MultipartFile.fromPath(
        'image',
        image.path,
        filename: image.path.split('/').last,
      ));
      print('Image file added to request.');
    } else {
      print('No image file to add.');
    }

    if (file != null && await file.exists()) {
      print('Adding report file: ${file.path}');
      request.files.add(await http.MultipartFile.fromPath(
        'file',
        file.path,
        filename: file.path.split('/').last,
      ));
      print('Report file added to request.');
    } else {
      print('No report file to add.');
    }

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);
    print('Response Status Code: ${response.statusCode}');
    print('Response Body: ${response.body}');

    if (response.statusCode == 200) {
      final jsonResponse = jsonDecode(response.body);
      print('JSON Response: $jsonResponse');

      if (jsonResponse != null && jsonResponse['status'] != null) {
        if (jsonResponse['status'] == true) {
          print('Report submitted successfully: ${jsonResponse['message']}');
        } else {
          throw Exception('Failed to submit report: ${jsonResponse['statusMessage']}');
        }
      } else {
        throw Exception('Invalid response format');
      }
    } else {
      throw Exception('Failed to upload report. Status code: ${response.statusCode}');
    }
  } catch (e) {
    print('Error uploading report: $e');
    throw Exception('Error uploading report: $e');
  }
}


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Report Submission',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: const Color.fromARGB(255, 64, 144, 209),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 16.0),
              TextFormField(
                controller: _reportController,
                onChanged: (_) {
                  setState(() {});
                },
                maxLines: 8,
                maxLength: 3000,
                decoration: const InputDecoration(
                  hintText: 'Enter your report here...',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value!.isEmpty) {
                    return 'Please enter your report';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16.0),
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  const Text(
                    'Upload Image',
                    style: TextStyle(fontSize: 16.0, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(width: 8.0),
                  Tooltip(
                    message: 'Take a Photo',
                    child: IconButton(
                      icon: Icon(Icons.camera_alt),
                      onPressed: _pickImageFromCamera,
                    ),
                  ),
                  const SizedBox(width: 8.0),
                  Tooltip(
                    message: 'Pick from Gallery',
                    child: IconButton(
                      icon: Icon(Icons.photo_library),
                      onPressed: _pickImageFromGallery,
                    ),
                  ),
                ],
              ),
              if (_selectedImageFile != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: _buildUploadedFile(_selectedImageFile!),
                ),
              const SizedBox(height: 20.0),
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  const Text(
                    'Upload Document',
                    style: TextStyle(fontSize: 16.0, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(width: 8.0),
                  Tooltip(
                    message: 'Upload Documents',
                    child: IconButton(
                      icon: Icon(Icons.attach_file),
                      onPressed: _pickFile,
                    ),
                  ),
                ],
              ),
              if (_selectedDocumentFile != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: _buildUploadedFile(_selectedDocumentFile!),
                ),
              const SizedBox(height: 30.0),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color.fromARGB(255, 64, 144, 209),
                ),
                onPressed: _isFormValid() ? _submit : null,
                child: _isSubmitting
                    ? CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        'Submit',
                        style: TextStyle(
                          color: Colors.white,
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
