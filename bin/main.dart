import 'package:puppeteer/puppeteer.dart';
import 'dart:io';
import 'dart:convert';

void main() async {
  // Launch a browser.
  var browser = await puppeteer.launch(
      headless: false,
      executablePath: '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome');
  var page = await browser.newPage();

  // Navigate to the target website
  await page.goto('https://cynergybank.my.salesforce-sites.com/timesheet/TimesheetPage',
      wait: Until.networkIdle);

  print('Page loaded. Starting automation.');

  // --- Start of Automation Logic ---

  // Initial login
  print('Performing initial login...');
  await page.type('input[id="j_id0:CynergyTemplate:tmsheet:cbemail"]', 'kbuyuk@cynergybank.co.uk');
  await page.click('input[id="j_id0:CynergyTemplate:tmsheet:helpDeskSubmit"]');
  print('Login submitted. Waiting for main page to load...');
  await page.waitForSelector('input[id="j_id0:CynergyTemplate:tmsheet:addTimesheet"]', visible: true, timeout: Duration(seconds: 60));
  print('Main page is ready. Starting timesheet entries.');

  var timesheetFile = File('timesheet_data.json');
  var timesheetData = jsonDecode(await timesheetFile.readAsString()) as List;

  // Loop with an index to allow for retries
  for (var i = 0; i < timesheetData.length; i++) {
    var entry = timesheetData[i];
    try {
      // 1. Wait for the main page to be ready
      print('Waiting for "Add Timesheet" button...');
      await page.waitForSelector('input[id="j_id0:CynergyTemplate:tmsheet:addTimesheet"]', visible: true, timeout: Duration(seconds: 15));
      
      // 2. Click "Add Timesheet" using a reliable JavaScript click
      print('Clicking "Add Timesheet" button for date: ${entry["date"]}');
      await page.evaluate('document.querySelector(\'input[id="j_id0:CynergyTemplate:tmsheet:addTimesheet"]\').click()');

      // 3. Wait for the form to appear
      print('Waiting for the timesheet form to load...');
      await page.waitForSelector('input[id="j_id0:CynergyTemplate:tmsheet:Project"]', visible: true);
      print('Form is ready.');

      // 4. Fill the form fields sequentially with human-like typing.
      print('Filling form for date: ${entry["date"]}');

      var project = entry['project'] as String;
      var dateWithSlashes = entry['date'] as String;
      var dateWithoutSlashes = dateWithSlashes.replaceAll('/', '');
      var duration = entry['duration'] as String;
      var overtime = entry['overtime'] as String;
      var comment = entry['comment'] as String;

      // --- Start Sequential Typing ---

      // 1. Type Project Code
      await page.type('input[id="j_id0:CynergyTemplate:tmsheet:Project"]', project);
      await Future.delayed(Duration(milliseconds: 500)); // Wait after project code

      // 2. Type Date
      var dateSelector = 'input[id="j_id0:CynergyTemplate:tmsheet:Date"]';
      await page.type(dateSelector, dateWithoutSlashes.substring(0, 2)); // Day
      await Future.delayed(Duration(milliseconds: 250));
      await page.type(dateSelector, dateWithoutSlashes.substring(2, 4)); // Month
      await Future.delayed(Duration(milliseconds: 250));
      await page.type(dateSelector, dateWithoutSlashes.substring(4, 8)); // Year

      // 3. Type Duration
      await page.type('input[id="j_id0:CynergyTemplate:tmsheet:Duration"]', duration);

      // 4. Type Overtime
      await page.type('input[id="j_id0:CynergyTemplate:tmsheet:overtime"]', overtime);

      // 5. Type Comment
      await page.type('textarea[id="j_id0:CynergyTemplate:tmsheet:Comment"]', comment);

      // --- End Sequential Typing ---

      // 5. Save the form
      print('Finding and clicking the save button.');
      var saveButton = await page.$('input[id="j_id0:CynergyTemplate:tmsheet:save"]');
      await saveButton.click();

      // 6. Wait for save to complete
      print('Waiting for save to complete...');
      await Future.delayed(Duration(milliseconds: 1500)); // Increased delay for stability
      print('Save complete for date: ${entry["date"]}');

    } catch (e) {
      print('An error occurred for date ${entry["date"]}: $e');
      print('Attempting to recover session...');

      if (!page.isClosed) {
        try { await page.close(); } catch (_) {}
      }

      page = await browser.newPage();
      await page.goto('https://cynergybank.my.salesforce-sites.com/timesheet/TimesheetPage', wait: Until.networkIdle);
      
      await page.type('input[id="j_id0:CynergyTemplate:tmsheet:cbemail"]', 'your-email@cynergybank.co.uk');
      await page.click('input[id="j_id0:CynergyTemplate:tmsheet:helpDeskSubmit"]');
      await page.waitForSelector('input[id="j_id0:CynergyTemplate:tmsheet:addTimesheet"]', visible: true, timeout: Duration(seconds: 60));
      
      print('Recovery successful. Retrying last entry.');
      i--; // Decrement to retry the current entry in the next iteration.
    }
  }

  // --- End of Automation Logic ---

  // Keep the browser open for a few seconds to see the result
  print('Automation finished. The browser will close in 10 seconds.');
  await Future.delayed(Duration(seconds: 10));

  // Clean up and close the browser
  await browser.close();
}
