const fs = require('fs');
const path = require('path');
const Ajv = require('ajv');
const addFormats = require('ajv-formats');

// Load all schemas
const schemaDir = path.join(__dirname, '../schemas/envelopes');
const schemas = {
  evidence: JSON.parse(fs.readFileSync(path.join(schemaDir, 'evidence-envelope.schema.json'), 'utf8')),
  decision: JSON.parse(fs.readFileSync(path.join(schemaDir, 'decision-envelope.schema.json'), 'utf8')),
  consent: JSON.parse(fs.readFileSync(path.join(schemaDir, 'consent-envelope.schema.json'), 'utf8')),
  explanation: JSON.parse(fs.readFileSync(path.join(schemaDir, 'accessible-explanation.schema.json'), 'utf8')),
  review: JSON.parse(fs.readFileSync(path.join(schemaDir, 'review-case.schema.json'), 'utf8'))
};

const ajv = new Ajv({ allErrors: true });
addFormats(ajv);

// Compile schemas
const validators = {
  evidence: ajv.compile(schemas.evidence),
  decision: ajv.compile(schemas.decision),
  consent: ajv.compile(schemas.consent),
  explanation: ajv.compile(schemas.explanation),
  review: ajv.compile(schemas.review)
};

function validateFixture(filePath) {
  const data = JSON.parse(fs.readFileSync(filePath, 'utf8'));
  // Determine which schema by the presence of required fields
  let schemaType = null;
  if (data.envelope_key && data.domain) schemaType = 'evidence';
  else if (data.decision_key && data.decision_state) schemaType = 'decision';
  else if (data.consent_key && data.purpose) schemaType = 'consent';
  else if (data.explanation_code && data.plain_language_text) schemaType = 'explanation';
  else if (data.review_key && data.priority) schemaType = 'review';
  else throw new Error(`Cannot determine schema type for ${filePath}`);

  const validator = validators[schemaType];
  const valid = validator(data);
  if (!valid) {
    console.error(`❌ ${filePath}: ${ajv.errorsText(validator.errors)}`);
    return false;
  }
  console.log(`✅ ${filePath}`);
  return true;
}

function main() {
  const fixturesDir = path.join(__dirname, '../fixtures');
  const positiveDir = path.join(fixturesDir, 'positive');
  const negativeDir = path.join(fixturesDir, 'negative');

  let pass = true;
  // Positive fixtures must pass
  fs.readdirSync(positiveDir).forEach(file => {
    const filePath = path.join(positiveDir, file);
    if (!validateFixture(filePath)) pass = false;
  });
  // Negative fixtures must fail
  fs.readdirSync(negativeDir).forEach(file => {
    const filePath = path.join(negativeDir, file);
    // We expect validation to fail, so we'll try and catch the error
    try {
      const valid = validateFixture(filePath);
      if (valid) {
        console.error(`❌ Expected failure but passed: ${filePath}`);
        pass = false;
      } else {
        console.log(`✅ (expected failure) ${filePath}`);
      }
    } catch (e) {
      console.log(`✅ (expected error) ${filePath}: ${e.message}`);
    }
  });

  if (!pass) process.exit(1);
  console.log('All fixtures passed.');
}

if (require.main === module) main();
