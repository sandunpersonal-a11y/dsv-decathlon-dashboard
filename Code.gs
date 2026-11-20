const MASTER_TAB = 'Shared Payroll Master';
const payrollEpf=value=>String(value??'').trim().replace(/^0+(?=\d)/,'');
function doGet() {
  return HtmlService.createHtmlOutputFromFile('Index')
    .setTitle('GTL Warehouse Dashboard')
    .addMetaTag('viewport','width=device-width, initial-scale=1');
}
function payrollBook_(){
  const id=PropertiesService.getScriptProperties().getProperty('PAYROLL_SPREADSHEET_ID');
  if(!id)throw new Error('Configure PAYROLL_SPREADSHEET_ID in Script Properties.');
  return SpreadsheetApp.openById(id);
}
function readPayroll(epfs){
  if(!Array.isArray(epfs)||epfs.length>5000)throw new Error('Invalid EPF list.');
  const sheet=payrollBook_().getSheetByName(MASTER_TAB);
  if(!sheet||sheet.getLastRow()<2)return {records:[],hours:null,updated:null};
  const wanted=new Set(epfs.map(payrollEpf));
  const rows=sheet.getRange(1,1,sheet.getLastRow(),1).getValues().flat();
  const metadata=JSON.parse(rows[0]);
  const records=rows.slice(1).filter(Boolean).map(value=>JSON.parse(value)).filter(([epf])=>wanted.has(epf));
  return {records,hours:metadata.hours,updated:metadata.updated};
}
function uploadPayroll(csv,hours){
  if(typeof csv!=='string'||csv.length>3000000||!Number.isFinite(hours)||hours<=0)throw new Error('Select a valid CSV and paid monthly hours.');
  const entries=parsePayrollRows_(Utilities.parseCsv(csv.replace(/^\uFEFF/,'')));
  const rows=[[JSON.stringify({hours,updated:new Date().toISOString()})],
    ...Array.from(entries,entry=>[JSON.stringify(entry)])];
  const lock=LockService.getScriptLock();
  lock.waitLock(15000);
  try{
    const book=payrollBook_();
    const sheet=book.getSheetByName(MASTER_TAB)||book.insertSheet(MASTER_TAB);
    const oldLength=sheet.getLastRow();
    if(rows.length>sheet.getMaxRows())sheet.insertRowsAfter(sheet.getMaxRows(),rows.length-sheet.getMaxRows());
    while(rows.length<oldLength)rows.push(['']);
    sheet.getRange(1,1,rows.length,1).setValues(rows);
    SpreadsheetApp.flush();
  }finally{lock.releaseLock();}
  return entries.size;
}
function parsePayrollRows_(records){
  const normalize=label=>label.toLowerCase().replace(/[^a-z0-9]/g,'');
  const allowances=['Ser.tra Allowance','Travelling Allowance','Incentive','Laptop Payment','Other Addition 1','Other Addition 2','Variable Incentives'];
  const required=['EPF','Name','Category','Basic Salary',...allowances,'OT [1.50] Amount','Gross Total'];
  const header=records.findIndex(cells=>required.every(label=>cells.map(normalize).includes(normalize(label))));
  if(header<0)throw new Error('Payroll CSV is missing one or more required column headings.');
  const columns=records[header].map(normalize);
  const master=new Map();
  for(let i=header+1;i<records.length;i++){
    const row=records[i];
    const get=label=>String(row[columns.indexOf(normalize(label))]??'').trim();
    const epf=payrollEpf(get('EPF'));
    if(!/^\d+$/.test(epf))continue;
    if(master.has(epf))throw new Error('Duplicate EPF in payroll CSV at row '+(i+1)+'.');
    const number=(label,optional=false)=>{
      const raw=get(label).replace(/,/g,'');
      const value=raw===''?(optional?0:NaN):Number(raw);
      if(!Number.isFinite(value))throw new Error('Invalid '+label+' at row '+(i+1)+'.');
      return value;
    };
    const basic=number('Basic Salary'),gross=number('Gross Total'),otPaid=number('OT [1.50] Amount',true);
    const allowance=allowances.reduce((sum,label)=>sum+number(label,true),0);
    if(basic<0||otPaid<0||gross<otPaid)throw new Error('Invalid salary or OT at row '+(i+1)+'.');
    master.set(epf,{name:get('Name'),category:get('Category'),basic,allowance,otPaid,gross,regularPay:Math.round((gross-otPaid)*100)/100});
  }
  if(!master.size)throw new Error('No payroll rows found.');
  return master;
}
