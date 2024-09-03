
import 'package:http/http.dart' as http;
import 'package:syncfusion_flutter_xlsio/xlsio.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import 'dart:convert';

Future<String> downloadExcel(DateTime startDate, DateTime endDate) async {
  final startingdate =
      "${startDate.day.toString().padLeft(2, '0')}-${startDate.month.toString().padLeft(2, '0')}-${startDate.year}";
  final enddate =
      "${endDate.day.toString().padLeft(2, '0')}-${endDate.month.toString().padLeft(2, '0')}-${endDate.year}";

  print("");
  print(startingdate);
  print(enddate);
  print("");

  try {
    final response = await http.post(Uri.parse(
        'http://13.201.213.5:4040/admin/fetchallattendancebystartandenddate?startingdate=$startingdate&enddate=$enddate'));

    if (response.statusCode == 200) {
      final Map<String, dynamic> data = json.decode(response.body);
      final Workbook workbook = Workbook();
      final Worksheet sheet = workbook.worksheets[0];

      // Set headers
      const headers = [
        'Employee Name',
        'Employee Department',
        'Employee Code',
        'Date',
        'Day',
        'Attendance Status',
        'Punch In Time',
        'Punch In Address',
        'Punch In Status',
        'Punch Out Time',
        'Punch Out Address',
        'Punch Out Status',
        'Working Hours' // New column for working hours
      ];

      for (int i = 0; i < headers.length; i++) {
        sheet.getRangeByIndex(1, i + 1).setText(headers[i]);
      }

      int rowIndex = 2;
      final body = data['body'];

      if (body != null && body is List) {
        List<Map<String, dynamic>> sortedData = List.from(body);
        sortedData.sort((a, b) => a['dayAndDate'][0]['date'].compareTo(b['dayAndDate'][0]['date']));
        
        for (var employee in sortedData) {
          final empCode = employee['emp_Code']?.toString() ?? '';
          final empName = employee['name_of_the_Employee'] ?? '';
          final empDepartment = employee['department'] ?? '';
          final dayAndDate = employee['dayAndDate'];

          if (dayAndDate != null && dayAndDate is List) {
            for (var dayEntry in dayAndDate) {
              final date = dayEntry['date'] ?? '';
              final day = dayEntry['day'] ?? '';
              final attendance = dayEntry['attendance'] ?? '';

              List<Map<String, String>> inTimes = [];
              List<Map<String, String>> outTimes = [];
              String workingHours = '';

              final attendanceDetails = dayEntry['attendance_Details'];

              if (attendanceDetails != null && attendanceDetails is List) {
                DateTime? firstInTime;
                DateTime? lastOutTime;

                for (var detail in attendanceDetails) {
                  if (detail != null && detail['time'] != null) {
                    final time = detail['time'];
                    print('Parsing date: $date, time: $time'); // Debug print
                    final dateTime = parseTime(date, time);

                    final attendanceStatus = detail['attendance_status'];
                    if (attendanceStatus != null &&
                        attendanceStatus.contains('Punch In')) {
                      inTimes.add({
                        'time': time,
                        'address': detail['address'] ?? '',
                        'status': getInStatus(dateTime),
                      });
                      firstInTime ??= dateTime;
                    } else if (attendanceStatus != null &&
                        attendanceStatus.contains('Punch Out')) {
                      outTimes.add({
                        'time': time,
                        'address': detail['address'] ?? '',
                        'status': getOutStatus(dateTime),
                      });
                      lastOutTime = dateTime;
                    }
                  }
                }

                if (firstInTime != null && lastOutTime != null) {
                  final duration = lastOutTime.difference(firstInTime);
                  workingHours =
                      '${duration.inHours}h ${duration.inMinutes.remainder(60)}m';
                }

                int maxLength = inTimes.length > outTimes.length
                    ? inTimes.length
                    : outTimes.length;
                for (int i = 0; i < maxLength; i++) {
                  sheet.getRangeByIndex(rowIndex, 1).setText(empName);
                  sheet.getRangeByIndex(rowIndex, 2).setText(empDepartment);
                  sheet.getRangeByIndex(rowIndex, 3).setText(empCode);
                  sheet.getRangeByIndex(rowIndex, 4).setText(date);
                  sheet.getRangeByIndex(rowIndex, 5).setText(day);
                  sheet.getRangeByIndex(rowIndex, 6).setText(attendance);

                  if (i < inTimes.length) {
                    var inEntry = inTimes[i];
                    sheet.getRangeByIndex(rowIndex, 7).setText(inEntry['time']);
                    sheet
                        .getRangeByIndex(rowIndex, 8)
                        .setText(inEntry['address']);
                    sheet
                        .getRangeByIndex(rowIndex, 9)
                        .setText(inEntry['status']);
                  }

                  if (i < outTimes.length) {
                    var outEntry = outTimes[i];
                    sheet
                        .getRangeByIndex(rowIndex, 10)
                        .setText(outEntry['time']);
                    sheet
                        .getRangeByIndex(rowIndex, 11)
                        .setText(outEntry['address']);
                    sheet
                        .getRangeByIndex(rowIndex, 12)
                        .setText(outEntry['status']);
                  }

                  if (i == 0 && workingHours.isNotEmpty) {
                    sheet.getRangeByIndex(rowIndex, 13).setText(workingHours);
                  } else {
                    sheet.getRangeByIndex(rowIndex, 13).setText('');
                  }

                  rowIndex++;
                }
              }
            }
          }
        }
      }

      final List<int> bytes = workbook.saveAsStream();
      final String path = (await getApplicationSupportDirectory()).path;
      final String fileName =
          Platform.isWindows ? '$path\\Output.xlsx' : '$path/Output.xlsx';
      final File file = File(fileName);
      await file.writeAsBytes(bytes, flush: true);
      OpenFile.open(fileName);

      workbook.dispose();
      print('Excel file created and opened successfully.');
      return 'Excel file created and opened successfully.';
    } else {
      print(
          'Failed to load attendance data: ${response.statusCode} - ${response.reasonPhrase}');
      return 'Failed to load attendance data';
    }
  } catch (e) {
    print("Error creating Excel file: $e");
    return 'Failed to create Excel file';
  }
}

DateTime parseTime(String date, String time) {
  try {
    final timeParts = time.split(' ');
    if (timeParts.length != 2) {
      throw FormatException('Invalid time format');
    }
    
    final hourMinute = timeParts[0].split(':');
    if (hourMinute.length != 2) {
      throw FormatException('Invalid hour-minute format');
    }
    
    final hour = int.parse(hourMinute[0]);
    final minute = int.parse(hourMinute[1]);
    final timeOfDay = timeParts[1].toUpperCase();
    
    if (timeOfDay != 'AM' && timeOfDay != 'PM') {
      throw FormatException('Invalid AM/PM format');
    }
    
    final isAM = timeOfDay == 'AM';
    
    return DateTime(
      int.parse(date.split('-')[2]), // Year
      int.parse(date.split('-')[1]), // Month
      int.parse(date.split('-')[0]), // Day
      hour == 12 ? (isAM ? 0 : 12) : (isAM ? hour : hour + 12),
      minute,
    );
  } catch (e) {
    print('Error parsing time: $e');
    return DateTime.now(); // or handle the error appropriately
  }
}

String getInStatus(DateTime dateTime) {
  final hour = dateTime.hour;
  final minute = dateTime.minute;

  // if (hour < 9) {
  //   return 'Early';
  // } else if (hour == 9 && minute <= 30) {
  //   return 'Ontime';
  // } else

  if (hour < 9 && minute < 46) {
    return 'Present';
  } else {
    return 'Late';
  }
}

String getOutStatus(DateTime dateTime) {
  final hour = dateTime.hour;
  final minute = dateTime.minute;

  if ((hour > 18 || (hour == 18 && minute >= 30)) || (hour < 3 && minute == 0)) {
    return 'Punch Out';
  } else {
    return 'Early';
  }
}
