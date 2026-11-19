javasphere-evidence-workbench/
├── MODULE_INDEX.md
├── README.md
├── LICENSE
├── package.json
├── schemas/
│   ├── source-manifest.schema.json
│   ├── evidence-record.schema.json
│   ├── claim-record.schema.json
│   ├── corridor-graph.schema.json
│   ├── requirement-record.schema.json
│   ├── uncertainty-input.schema.json
│   ├── scenario-vector.schema.json
│   └── implementation-readiness.schema.json
├── src/
│   ├── ai-chat/
│   │   ├── evidence-workbench.js
│   │   ├── claim-scope-firewall.js
│   │   ├── contradiction-detector.js
│   │   ├── boundary-completeness-linter.js
│   │   ├── uncertainty-catalog.js
│   │   ├── accessible-summary-builder.js
│   │   └── research-backlog-ranker.js
│   ├── policy/
│   │   ├── data-minimization.rego
│   │   ├── non-actuation.rego
│   │   ├── claim-evidence.rego
│   │   └── evidence-freshness.rego
│   ├── browser/
│   │   ├── duties/
│   │   │   ├── evidence-ingestion-duty.js
│   │   │   ├── prompt-safety-duty.js
│   │   │   ├── tab-provenance-duty.js
│   │   │   └── review-package-duty.js
│   │   └── ui/
│   │       ├── evidence-register-view.js
│   │       ├── gap-register-view.js
│   │       └── accessible-status-view.js
│   ├── storage/
│   │   ├── local-bundle-store.js
│   │   └── export-bundle.js
│   └── validation/
│       ├── ajv-validator.js
│       ├── policy-runner.js
│       └── readiness-validator.js
├── test/
│   ├── fixtures/
│   │   ├── valid/
│   │   ├── invalid/
│   │   └── scenario-vectors/
│   ├── ai-chat/
│   ├── policy/
│   ├── browser/
│   └── integration/
├── docs/
│   ├── ai-chat/
│   │   ├── function-catalog.md
│   │   ├── prompt-contracts.md
│   │   ├── output-labeling-standard.md
│   │   └── review-package-format.md
│   ├── governance/
│   │   ├── data-classification-matrix.md
│   │   ├── retention-schedule.md
│   │   ├── review-authority-map.md
│   │   └── misuse-register.md
│   ├── research/
│   │   ├── dqo-crosswalk.md
│   │   ├── ai-rmf-crosswalk.md
│   │   └── uncertainty-method.md
│   └── requirements/
│       └── cross-module-requirements-traceability.md
└── .github/
    └── workflows/
        ├── validate-artifacts.yml
        ├── test-policies.yml
        ├── test-javascript.yml
        └── build-review-packet.yml
