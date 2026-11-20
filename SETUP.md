# Shared Payroll Dashboard

1. Create a dedicated Restricted Google Sheet for the shared payroll master. Give payroll uploaders Editor access and authorized dashboard users Viewer access. Sheet viewers can view the master directly. Use a dedicated sheet with no unrelated data.
2. Create an Apps Script project. Add the code in Code.gs and create an HTML file named Index with the contents of Index.html. In Project Settings → Script Properties add PAYROLL_SPREADSHEET_ID with the dedicated spreadsheet ID.
3. Deploy → New deployment → Web app. Set Execute as to User accessing the web app. Limit access to your organization where available. Share the deployment URL with authorized users. Do not deploy as the owner, as that would use the owner's sheet permissions for others.
4. Sign in as an Editor. In Job Costing → Labour Payroll set paid monthly hours, then upload the GTL CSV and confirm replacement. The shared master and its paid hours replace the prior upload. Users on another device get the new figures when opening the Apps Script dashboard or selecting Refresh shared payroll.
5. This is an Apps Script dashboard URL. The old GitHub Pages URL remains separate. Browser-local job settings such as area and equipment costs are separate at the new URL. The ZIP contains no payroll data.

The existing job-costing PIN remains a UI control. Google Sheet permissions determine who can read or replace the shared master.
