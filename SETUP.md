# Google Payroll setup

1. Open the Excel payroll workbook in Google Sheets and choose File → Save as Google Sheets. Keep the new sheet Restricted and grant viewer access to authorized payroll users.
2. In your organization's Google Cloud project, enable Google Sheets API and configure Google Auth Platform for approved users. Create a Web application OAuth client. Add your dashboard origin, such as https://sandunpersonal-a11y.github.io, to Authorized JavaScript origins.
3. Put the OAuth client ID and the new Google Sheets ID in payroll-config.js. Do not add client secrets or tokens. Keep the GTL tab name or update the tab setting.
4. Upload the package assets beside the existing index.html. Open Job Costing → Labour Payroll → Connect Google Payroll. After consent, matching EPFs populate. Reopening Labour Payroll refreshes Google data during the authorized browser session. Refresh Payroll can also reload it.
5. Set Paid Monthly Hours for regular hourly costing. Imported payroll figures for matched EPFs are saved using the existing browser-local job settings. Use a dedicated browser profile for payroll.

Google access is required per browser session. This integration reads the source sheet. Dashboard edits use the existing local settings and do not edit the Google Sheet.
