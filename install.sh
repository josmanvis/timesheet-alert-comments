#!/bin/bash
echo "🚀 Installing Timesheet Alert Comments..."
curl -sL -o /tmp/TimesheetAlertComments.dmg "https://github.com/josmanvis/timesheet-alert-comments/releases/latest/download/TimesheetAlertComments.dmg"
hdiutil attach /tmp/TimesheetAlertComments.dmg -mountpoint /Volumes/TimesheetAlertComments -nobrowse -quiet
rm -rf /Applications/TimesheetAlertComments.app
cp -r /Volumes/TimesheetAlertComments/TimesheetAlertComments.app /Applications/
hdiutil detach /Volumes/TimesheetAlertComments -quiet
rm /tmp/TimesheetAlertComments.dmg
echo "✅ Installation complete! Timesheet Alert Comments is now in your Applications folder."
