const fs = require('fs');
const path = require('path');

const objectsDir = path.join(__dirname, '..', 'force-app', 'main', 'default', 'objects');
const permSetPath = path.join(__dirname, '..', 'force-app', 'main', 'default', 'permissionsets', 'WanderRoster_Admin.permissionset-meta.xml');

const objects = [
  'Expense_Item__c',
  'Expense_Report__c',
  'Travel_Budget__c',
  'Travel_Location_Update__c',
  'Travel_Outcome__c',
  'Travel_Request__c'
];

const formulaFields = new Set([
  'Travel_Budget__c.Forecast_Variance__c',
  'Travel_Budget__c.Remaining_Budget__c',
  'Travel_Request__c.Total_Estimated_Cost__c'
]);

const fieldPermissions = [];

for (const obj of objects) {
  const fieldsDir = path.join(objectsDir, obj, 'fields');
  if (!fs.existsSync(fieldsDir)) continue;

  const files = fs.readdirSync(fieldsDir);
  for (const file of files) {
    if (!file.endsWith('.field-meta.xml')) continue;
    const filePath = path.join(fieldsDir, file);
    const content = fs.readFileSync(filePath, 'utf8');

    // Universally required fields cannot have fieldPermissions in Salesforce
    if (content.includes('<required>true</required>')) {
      continue;
    }

    const fieldName = file.replace('.field-meta.xml', '');
    const fullName = `${obj}.${fieldName}`;
    const isFormula = formulaFields.has(fullName);

    fieldPermissions.push({
      field: fullName,
      editable: !isFormula,
      readable: true
    });
  }
}

fieldPermissions.sort((a, b) => a.field.localeCompare(b.field));

let fieldPermsXml = fieldPermissions.map(fp => `    <fieldPermissions>
        <editable>${fp.editable}</editable>
        <field>${fp.field}</field>
        <readable>${fp.readable}</readable>
    </fieldPermissions>`).join('\n');

let currentContent = fs.readFileSync(permSetPath, 'utf8');
currentContent = currentContent.replace(/\s*<fieldPermissions>[\s\S]*?<\/fieldPermissions>/g, '');

const updatedContent = currentContent.replace(
  '    <objectPermissions>',
  `${fieldPermsXml}\n    <objectPermissions>`
);

fs.writeFileSync(permSetPath, updatedContent, 'utf8');
console.log(`Generated ${fieldPermissions.length} field permissions.`);
